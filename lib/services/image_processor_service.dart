import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ImageProcessorService {
  static Future<String> processImage({
    required String rawPath,
    required String themeMode,
    required Color secondaryColor,
    required double displayZoom,
    required List<CameraDescription> cameras,
    required int selectedCameraIndex,
  }) async {
    try {
      final XFile file = XFile(rawPath);
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

      final ui.Paint bgPaint = ui.Paint()..color = secondaryColor;
      canvas.drawRect(ui.Rect.fromLTWH(0, 0, outputSize, outputSize), bgPaint);

      // Check if we are using the physical wide angle lens
      final rearCameras = cameras.where((c) => c.lensDirection == CameraLensDirection.back).toList();
      final bool isUsingPhysicalWideAngle = rearCameras.length > 1 && 
          selectedCameraIndex < cameras.length &&
          cameras[selectedCameraIndex].name == rearCameras[1].name;

      final double targetZoom = isUsingPhysicalWideAngle ? 1.0 : displayZoom;

      final ui.Paint imagePaint = ui.Paint()..filterQuality = ui.FilterQuality.high;
      if (themeMode == 'NAM') {
        imagePaint.colorFilter = const ui.ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]);
      }

      if (targetZoom >= 1.0) {
        // Normal cropping
        final double srcSize = minDim / targetZoom;
        final double sx = (width - srcSize) / 2;
        final double sy = (height - srcSize) / 2;

        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(sx, sy, srcSize, srcSize),
          ui.Rect.fromLTWH(0, 0, outputSize, outputSize),
          imagePaint,
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
          imagePaint,
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
      return rawPath;
    }
  }
}
