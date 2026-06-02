import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';

class CameraViewfinder extends StatefulWidget {
  final Color themeColor;
  final Color textColor;
  final Color secondaryColor;
  final String themeMode;
  final Function(String rawPath, double zoom, List<CameraDescription> cameras, int selectedCameraIndex) onImageCaptured;
  final VoidCallback onGalleryPicked;

  const CameraViewfinder({
    super.key,
    required this.themeColor,
    required this.textColor,
    required this.secondaryColor,
    required this.themeMode,
    required this.onImageCaptured,
    required this.onGalleryPicked,
  });

  @override
  State<CameraViewfinder> createState() => _CameraViewfinderState();
}

class _CameraViewfinderState extends State<CameraViewfinder> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  bool _isInitializing = false;
  bool _isCapturing = false;
  String? _initError;

  // Zoom variables
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _displayZoom = 1.0;
  double _baseZoom = 1.0;

  // Flash variables
  final List<FlashMode> _flashModes = [FlashMode.off, FlashMode.auto, FlashMode.always];
  int _flashModeIndex = 0;
  bool _isFlashSupported = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final oldController = _controller;
    _controller = null;
    oldController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller = null;
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _initError = "Không tìm thấy camera nào trên thiết bị.";
            _isInitializing = false;
          });
        }
        return;
      }

      // Default to rear camera if available
      int defaultIndex = 0;
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          defaultIndex = i;
          break;
        }
      }

      _selectedCameraIndex = defaultIndex;
      await _initializeCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = "Lỗi khởi tạo camera: $e";
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _initializeCameraController(CameraDescription cameraDescription) async {
    if (_controller != null) {
      final oldController = _controller;
      _controller = null;
      await oldController!.dispose();
    }

    // Medium resolution is stable, bandwidth-friendly (~720x480)
    final controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      
       try {
        _minZoom = await controller.getMinZoomLevel();
        _maxZoom = await controller.getMaxZoomLevel();
        _displayZoom = 1.0;
      } catch (e) {
        _minZoom = 1.0;
        _maxZoom = 1.0;
        _displayZoom = 1.0;
      }

      // Check flash support (wrap in try-catch)
      try {
        await controller.setFlashMode(_flashModes[_flashModeIndex]);
        _isFlashSupported = true;
      } catch (e) {
        _isFlashSupported = false;
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = "Lỗi kết nối camera: $e";
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2 || _controller == null) return;

    setState(() {
      _isInitializing = true;
    });

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCameraController(_cameras[_selectedCameraIndex]);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_isFlashSupported) return;

    setState(() {
      _flashModeIndex = (_flashModeIndex + 1) % _flashModes.length;
    });

    try {
      await _controller!.setFlashMode(_flashModes[_flashModeIndex]);
    } catch (e) {
      debugPrint("Flash mode not supported: $e");
    }
  }

   Future<void> _updateZoom(double zoom) async {
    final targetDisplayZoom = zoom.clamp(0.5, 2.5);

    // Check if we have multiple physical rear cameras to switch lenses
    final rearCameras = _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
    if (rearCameras.length > 1 && _controller != null) {
      final currentCamera = _cameras[_selectedCameraIndex];
      if (currentCamera.lensDirection == CameraLensDirection.back) {
        final targetCamera = targetDisplayZoom < 1.0 ? rearCameras[1] : rearCameras[0];
        if (currentCamera.name != targetCamera.name) {
          final targetIndex = _cameras.indexWhere((c) => c.name == targetCamera.name);
          if (targetIndex != -1) {
            setState(() {
              _selectedCameraIndex = targetIndex;
              _displayZoom = targetDisplayZoom;
              _isInitializing = true;
            });
            await _initializeCameraController(targetCamera);
            if (targetDisplayZoom >= 1.0 && _maxZoom > _minZoom) {
              final double ratio = (targetDisplayZoom - 1.0) / 1.5;
              final double targetHardwareZoom = _minZoom + ratio * (_maxZoom - _minZoom);
              try {
                await _controller!.setZoomLevel(targetHardwareZoom.clamp(_minZoom, _maxZoom));
              } catch (_) {}
            }
            return;
          }
        }
      }
    }

    setState(() {
      _displayZoom = targetDisplayZoom;
    });

    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_maxZoom > _minZoom) {
      // Hardware zoom is supported
      if (targetDisplayZoom >= 1.0) {
        // Map [1.0, 2.5] to [_minZoom, _maxZoom]
        final double ratio = (targetDisplayZoom - 1.0) / 1.5;
        final double targetHardwareZoom = _minZoom + ratio * (_maxZoom - _minZoom);
        try {
          await _controller!.setZoomLevel(targetHardwareZoom.clamp(_minZoom, _maxZoom));
        } catch (e) {
          debugPrint("Hardware zoom error: $e");
        }
      } else {
        // Z < 1.0: Hardware zoom remains at minZoom, preview is shrunk visually
        try {
          await _controller!.setZoomLevel(_minZoom);
        } catch (e) {
          debugPrint("Hardware zoom error: $e");
        }
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile file = await _controller!.takePicture();
      widget.onImageCaptured(file.path, _displayZoom, _cameras, _selectedCameraIndex);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi chụp ảnh: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  IconData _getFlashIcon() {
    switch (_flashModes[_flashModeIndex]) {
      case FlashMode.off:
        return Icons.flash_off_rounded;
      case FlashMode.auto:
        return Icons.flash_auto_rounded;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isNam = widget.themeMode == 'NAM';

    // Viewfinder size responsive: hiển thị hết chiều ngang (trừ padding nhẹ 16px mỗi bên)
    final screenW = MediaQuery.of(context).size.width;
    final viewfinderSize = (screenW - 32).clamp(220.0, 420.0);

    final rearCameras = _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
    final bool isUsingPhysicalWideAngle = rearCameras.length > 1 && 
        _selectedCameraIndex < _cameras.length &&
        _cameras[_selectedCameraIndex].name == rearCameras[1].name;

    final double visualScale = isUsingPhysicalWideAngle
        ? 1.0
        : ((_maxZoom > _minZoom && _displayZoom >= 1.0) ? 1.0 : _displayZoom);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Technical Metadata Top (Only for NAM style)
        if (isNam) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Row(
                  children: [
                    Text("ISO 400", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8E9192), letterSpacing: 1.0)),
                    SizedBox(width: 12),
                    Text("1/125S", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8E9192), letterSpacing: 1.0)),
                    SizedBox(width: 12),
                    Text("F/2.8", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF8E9192), letterSpacing: 1.0)),
                  ],
                ),
                Row(
                  children: [
                    const Text("AF-S", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFFFB300), fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(width: 6),
                    Container(width: 4, height: 12, color: const Color(0xFFFFB300)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],

        // Camera Viewfinder Box (Square crop)
        Center(
          child: Container(
            width: viewfinderSize,
            height: viewfinderSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isNam ? 0 : 24),
              border: isNam
                  ? Border.all(color: const Color(0xFF353434), width: 12)
                  : Border.all(color: widget.themeColor.withValues(alpha: 0.4), width: 4),
              boxShadow: [
                BoxShadow(
                  color: isNam ? Colors.black.withValues(alpha: 0.5) : widget.themeColor.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isNam ? 0 : 20),
              child: _isInitializing
                  ? Container(
                      color: widget.secondaryColor.withValues(alpha: 0.8),
                      child: Center(
                        child: CircularProgressIndicator(color: isNam ? const Color(0xFFFFB300) : widget.themeColor),
                      ),
                    )
                  : _initError != null
                      ? Container(
                          color: widget.secondaryColor.withValues(alpha: 0.8),
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              _initError!,
                              style: TextStyle(color: widget.textColor, fontSize: 12, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : (controller != null && controller.value.isInitialized)
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: viewfinderSize,
                                        height: viewfinderSize / controller.value.aspectRatio,
                                        child: GestureDetector(
                                          onScaleStart: (details) {
                                            _baseZoom = _displayZoom;
                                          },
                                          onScaleUpdate: (details) {
                                            _updateZoom(_baseZoom * details.scale);
                                          },
                                          child: Transform.scale(
                                            scale: visualScale,
                                            child: isNam
                                                ? ColorFiltered(
                                                    colorFilter: const ColorFilter.matrix(<double>[
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0.2126, 0.7152, 0.0722, 0, 0,
                                                      0,      0,      0,      1, 0,
                                                    ]),
                                                    child: CameraPreview(controller),
                                                  )
                                                : CameraPreview(controller),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                
                                // Zoom Level Badge (Tappable to toggle zoom in Nữ mode)
                                 if (!isNam)
                                   Positioned(
                                     bottom: 12,
                                     right: 12,
                                     child: GestureDetector(
                                       onTap: () {
                                         final target = _displayZoom < 1.75 ? 2.5 : 1.0;
                                         _updateZoom(target);
                                       },
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                         decoration: BoxDecoration(
                                           color: Colors.black.withValues(alpha: 0.5),
                                           borderRadius: BorderRadius.circular(12),
                                         ),
                                         child: Text(
                                           "${_displayZoom.toStringAsFixed(1)}x",
                                           style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                         ),
                                       ),
                                     ),
                                   ),

                                 // Glowing Technical Zoom Stamp (Tappable to toggle zoom in Nam mode)
                                 if (isNam)
                                   Positioned(
                                     bottom: 12,
                                     right: 12,
                                     child: GestureDetector(
                                       onTap: () {
                                         final target = _displayZoom < 1.75 ? 2.5 : 1.0;
                                         _updateZoom(target);
                                       },
                                       child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                         decoration: BoxDecoration(
                                           color: Colors.black.withValues(alpha: 0.6),
                                           borderRadius: BorderRadius.circular(4),
                                           border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3), width: 0.8),
                                         ),
                                         child: Text(
                                           "${_displayZoom.toStringAsFixed(1)}x",
                                           style: const TextStyle(
                                             color: Color(0xFFFFB300),
                                             fontSize: 9,
                                             fontWeight: FontWeight.bold,
                                             fontFamily: 'monospace',
                                             letterSpacing: 0.5,
                                           ),
                                         ),
                                       ),
                                     ),
                                   ),
                                  
                                // Overlay Flash button on Top-Right corner
                                if (_isFlashSupported && !isNam)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: _toggleFlash,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _getFlashIcon(),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Technical Overlays for NAM mode
                                if (isNam) ...[
                                  // 1. Focus Brackets
                                  Positioned(
                                    top: 12, left: 12,
                                    child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white38, width: 2), left: BorderSide(color: Colors.white38, width: 2)))),
                                  ),
                                  Positioned(
                                    top: 12, right: 12,
                                    child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white38, width: 2), right: BorderSide(color: Colors.white38, width: 2)))),
                                  ),
                                  Positioned(
                                    bottom: 12, left: 12,
                                    child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white38, width: 2), left: BorderSide(color: Colors.white38, width: 2)))),
                                  ),
                                  Positioned(
                                    bottom: 12, right: 12,
                                    child: Container(width: 16, height: 16, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white38, width: 2), right: BorderSide(color: Colors.white38, width: 2)))),
                                  ),

                                  // 2. Center Crosshair
                                  Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(width: 24, height: 1, color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                                        Container(width: 1, height: 24, color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.4), width: 1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 3. Zoom list labels on Left (Tappable to set specific zoom level directly)
                                   Positioned(
                                     left: 12,
                                     top: 0,
                                     bottom: 0,
                                     child: Column(
                                       mainAxisAlignment: MainAxisAlignment.center,
                                       children: [2.5, 1.0].map((z) {
                                         final bool isActive = (_displayZoom - z).abs() < 0.15;
                                         return Padding(
                                           padding: const EdgeInsets.symmetric(vertical: 10.0),
                                           child: GestureDetector(
                                             onTap: () => _updateZoom(z),
                                             behavior: HitTestBehavior.opaque,
                                             child: Text(
                                               "${z.toStringAsFixed(1)}x",
                                               style: TextStyle(
                                                 fontFamily: 'monospace',
                                                 fontSize: 10,
                                                 fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                                 color: isActive ? const Color(0xFFFFB300) : Colors.white38,
                                                 shadows: isActive ? [
                                                   const Shadow(
                                                     color: Color(0xFFFFB300),
                                                     blurRadius: 8,
                                                   ),
                                                 ] : null,
                                               ),
                                             ),
                                           ),
                                         );
                                       }).toList(),
                                     ),
                                   ),

                                  // 4. Zoom slider side indicators (Flash in metal, camera flip removed)
                                   if (_isFlashSupported)
                                     Positioned(
                                       right: 12,
                                       top: 0,
                                       bottom: 0,
                                       child: Center(
                                         child: GestureDetector(
                                           onTap: _toggleFlash,
                                           child: Container(
                                             width: 34,
                                             height: 34,
                                             decoration: BoxDecoration(
                                               shape: BoxShape.circle,
                                               gradient: const LinearGradient(
                                                 colors: [Color(0xFF474646), Color(0xFF1C1B1B)],
                                                 begin: Alignment.topCenter,
                                                 end: Alignment.bottomCenter,
                                               ),
                                               border: Border.all(color: Colors.white10),
                                               boxShadow: [
                                                 BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                                               ],
                                             ),
                                             child: Icon(
                                               _getFlashIcon(),
                                               color: Colors.white70,
                                               size: 16,
                                             ),
                                           ),
                                         ),
                                       ),
                                     ),
                                ],
                              ],
                            )
                          : Container(
                              color: widget.secondaryColor.withValues(alpha: 0.8),
                              child: const Center(child: Text("Không có tín hiệu camera")),
                            ),
            ),
          ),
        ),

        // Technical Metadata Bottom (Only for NAM style)
        if (isNam) ...[
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("PAN-KT 35MM SYSTEM", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF444748), letterSpacing: 0.5)),
                Text("NO. 000492-B", style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF444748), letterSpacing: 0.5)),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Zoom sliders removed to simplify Mobile camera control and keep the interface exceptionally clean.

        const SizedBox(height: 12),

        // Camera control buttons (Gallery, Capture, Flip)
        // Camera control buttons (Gallery, Capture, Flip) - DRY unified layout
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Gallery Button
            GestureDetector(
              onTap: widget.onGalleryPicked,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNam ? null : Colors.white.withValues(alpha: 0.8),
                  gradient: isNam
                      ? const LinearGradient(
                          colors: [Color(0xFF474646), Color(0xFF1C1B1B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  border: isNam ? Border.all(color: Colors.white10) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isNam ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.photo_on_rectangle,
                  color: isNam ? Colors.white70 : widget.textColor,
                  size: 20,
                ),
              ),
            ),
            
            const SizedBox(width: 36),

            // 2. Shutter (Capture) Button
            GestureDetector(
              onTap: _isCapturing ? null : _takePicture,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer breathing/glowing ring
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isNam ? const Color(0xFFFFB300) : widget.themeColor).withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Inner Technical or Cute Shutter
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isNam
                          ? const LinearGradient(
                              colors: [Color(0xFF474646), Color(0xFF1C1B1B)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            )
                          : null,
                      color: isNam ? null : widget.themeColor,
                      border: Border.all(
                        color: isNam ? const Color(0xFF353434) : Colors.white,
                        width: isNam ? 3.0 : 4.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isNam ? const Color(0xFFFFB300) : widget.themeColor).withValues(alpha: 0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? CircularProgressIndicator(
                              color: isNam ? const Color(0xFFFFB300) : Colors.white,
                              strokeWidth: 3,
                            )
                          : Icon(
                              isNam ? CupertinoIcons.camera_fill : CupertinoIcons.camera,
                              color: isNam ? Colors.white70 : Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 36),

            // 3. Switch Camera Button
            GestureDetector(
              onTap: _cameras.length >= 2 ? _toggleCamera : null,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isNam ? null : Colors.white.withValues(alpha: 0.8),
                  gradient: isNam
                      ? const LinearGradient(
                          colors: [Color(0xFF474646), Color(0xFF1C1B1B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  border: isNam ? Border.all(color: Colors.white10) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isNam ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.switch_camera,
                  color: isNam ? Colors.white70 : widget.textColor,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
