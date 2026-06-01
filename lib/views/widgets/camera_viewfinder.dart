import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:camera/camera.dart';

class CameraViewfinder extends StatefulWidget {
  final Color themeColor;
  final Color textColor;
  final Color secondaryColor;
  final Function(String) onImageCaptured;
  final VoidCallback onGalleryPicked;

  const CameraViewfinder({
    super.key,
    required this.themeColor,
    required this.textColor,
    required this.secondaryColor,
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
    _controller?.dispose();
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
      await _controller!.dispose();
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

  Future<String> _processCapturedImage(XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();

      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final double width = image.width.toDouble();
      final double height = image.height.toDouble();
      final double minDim = width < height ? width : height;

      final double outputSize = 1080;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      final ui.Paint bgPaint = ui.Paint()..color = widget.secondaryColor;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, outputSize, outputSize), bgPaint);

      // Check if we are using the physical wide angle lens
      final rearCameras = _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
      final bool isUsingPhysicalWideAngle = rearCameras.length > 1 && 
          _selectedCameraIndex < _cameras.length &&
          _cameras[_selectedCameraIndex].name == rearCameras[1].name;

      final double targetZoom = isUsingPhysicalWideAngle ? 1.0 : _displayZoom;

      if (targetZoom >= 1.0) {
        final double cropSize = minDim / targetZoom;
        final double sx = (width - cropSize) / 2;
        final double sy = (height - cropSize) / 2;

        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(sx, sy, cropSize, cropSize),
          ui.Rect.fromLTWH(0, 0, outputSize, outputSize),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      } else {
        // targetZoom < 1.0 (visual scale down wide-angle)
        final double sx = (width - minDim) / 2;
        final double sy = (height - minDim) / 2;

        final double destSize = outputSize * targetZoom;
        final double destOffset = (outputSize - destSize) / 2;

        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(sx, sy, minDim, minDim),
          ui.Rect.fromLTWH(destOffset, destOffset, destSize, destSize),
          ui.Paint()..filterQuality = ui.FilterQuality.high,
        );
      }

      final ui.Picture picture = recorder.endRecording();
      final ui.Image croppedImage = await picture.toImage(outputSize.toInt(), outputSize.toInt());

      final ByteData? byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Failed to encode cropped image");
      final Uint8List croppedBytes = byteData.buffer.asUint8List();

      final XFile croppedXFile = XFile.fromData(croppedBytes, mimeType: 'image/png');
      return croppedXFile.path;
    } catch (e) {
      debugPrint("Image processing error: $e");
      return file.path;
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile file = await _controller!.takePicture();
      // Process picture to make it square 1:1 and apply zoom levels
      final String processedPath = await _processCapturedImage(file);
      widget.onImageCaptured(processedPath);
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

    // Viewfinder size responsive: hiển thị hết chiều ngang (trừ padding nhẹ 16px mỗi bên)
    final screenW = MediaQuery.of(context).size.width;
    final viewfinderSize = (screenW - 32).clamp(220.0, 420.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera Viewfinder Box (Square crop)
        Center(
          child: Container(
            width: viewfinderSize,
            height: viewfinderSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: widget.themeColor.withOpacity(0.4), width: 4),
              boxShadow: [
                BoxShadow(
                  color: widget.themeColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _isInitializing
                  ? Container(
                      color: widget.secondaryColor.withOpacity(0.8),
                      child: Center(
                        child: CircularProgressIndicator(color: widget.themeColor),
                      ),
                    )
                  : _initError != null
                      ? Container(
                          color: widget.secondaryColor.withOpacity(0.8),
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
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                     final rearCameras = _cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
                                     final bool isUsingPhysicalWideAngle = rearCameras.length > 1 && 
                                         _selectedCameraIndex < _cameras.length &&
                                         _cameras[_selectedCameraIndex].name == rearCameras[1].name;

                                     final double visualScale = isUsingPhysicalWideAngle
                                         ? 1.0
                                         : ((_maxZoom > _minZoom && _displayZoom >= 1.0) ? 1.0 : _displayZoom);

                                    return ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.center,
                                        child: FittedBox(
                                          fit: BoxFit.cover,
                                          child: SizedBox(
                                            width: constraints.maxWidth,
                                            height: constraints.maxWidth / controller.value.aspectRatio,
                                            child: GestureDetector(
                                              onScaleStart: (details) {
                                                _baseZoom = _displayZoom;
                                              },
                                              onScaleUpdate: (details) {
                                                _updateZoom(_baseZoom * details.scale);
                                              },
                                              child: Transform.scale(
                                                scale: visualScale,
                                                child: CameraPreview(controller),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                
                                // 2. Zoom Level Badge
                                Positioned(
                                  bottom: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      "${_displayZoom.toStringAsFixed(1)}x",
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                  
                                // 3. Overlay Flash button on Top-Right corner (Premium layout)
                                if (_isFlashSupported)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: GestureDetector(
                                      onTap: _toggleFlash,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.4),
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
                              ],
                            )
                          : Container(
                              color: widget.secondaryColor.withOpacity(0.8),
                              child: const Center(child: Text("Không có tín hiệu camera")),
                            ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Zoom Slider Row (Always available for virtual and hardware zoom)
        if (controller != null && controller.value.isInitialized)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.minus_circle, size: 16, color: widget.textColor.withOpacity(0.6)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: widget.themeColor,
                      inactiveTrackColor: widget.themeColor.withOpacity(0.2),
                      thumbColor: widget.themeColor,
                      overlayColor: widget.themeColor.withOpacity(0.12),
                      trackHeight: 2.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    ),
                    child: Slider(
                      value: _displayZoom,
                      min: 0.5,
                      max: 2.5,
                      onChanged: (value) => _updateZoom(value),
                    ),
                  ),
                ),
                Icon(CupertinoIcons.plus_circle, size: 16, color: widget.textColor.withOpacity(0.6)),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Camera control buttons (Gallery, Capture, Flip)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Gallery Picker Button
            IconButton(
              onPressed: widget.onGalleryPicked,
              icon: const Icon(CupertinoIcons.photo_on_rectangle, size: 24),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                foregroundColor: widget.textColor,
                minimumSize: const Size(46, 46),
                shape: const CircleBorder(),
                elevation: 1,
              ),
              tooltip: "Chọn từ Thư viện",
            ),
            
            const SizedBox(width: 32),

            // Capture button
            GestureDetector(
              onTap: _isCapturing ? null : _takePicture,
              child: Container(
                width: (screenW * 0.15).clamp(60.0, 90.0),
                height: (screenW * 0.15).clamp(60.0, 90.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.themeColor,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: widget.themeColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isCapturing
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : null,
              ),
            ),
            
            const SizedBox(width: 32),

            // Flip Camera button
            Opacity(
              opacity: _cameras.length >= 2 ? 1.0 : 0.5,
              child: IconButton(
                onPressed: _cameras.length >= 2 ? _toggleCamera : null,
                icon: const Icon(CupertinoIcons.switch_camera, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: widget.textColor,
                  minimumSize: const Size(46, 46),
                  shape: const CircleBorder(),
                  elevation: 1,
                ),
                tooltip: "Đổi Camera",
              ),
            ),
          ],
        ),
      ],
    );
  }
}
