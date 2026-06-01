import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_foundation/path_provider_foundation.dart';
import 'widget_service.dart';

/// Hàm xử lý FCM Background Message được chạy trong một Headless Isolate riêng biệt.
/// Cần gắn annotation @pragma('vm:entry-point') để tránh bị tối ưu hóa (tree-shaking) bởi Dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase trong isolate phụ
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase already initialized or failed to initialize: $e');
  }

  final data = message.data;
  final String? imageUrl = data['imageUrl'];
  final String? audioUrl = data['audioUrl'];

  if (imageUrl != null && audioUrl != null) {
    final imagePath = await downloadAndSaveFile(imageUrl, 'widget_image.jpg');
    final audioPath = await downloadAndSaveFile(audioUrl, 'widget_audio.mp3');

    if (imagePath != null && audioPath != null) {
      await WidgetService.initialize();
      await WidgetService.updateWidgetMedia(
        imagePath: imagePath,
        audioPath: audioPath,
      );
    }
  }
}

/// Tải tệp tin từ URL và lưu trữ vào App Group container (iOS) hoặc Temp directory (Android/Fallback).
Future<String?> downloadAndSaveFile(String url, String fileName) async {
  if (kIsWeb) {
    // Trên Web: Không cần download và lưu file, trả về trực tiếp URL để hiển thị/phát trực tiếp
    return url;
  }
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      String? targetDir;
      try {
        if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
          final provider = PathProviderFoundation();
          targetDir = await provider.getContainerPath(
            appGroupIdentifier: WidgetService.appGroupId,
          );
        }
      } catch (e) {
        debugPrint('App Group container path not available: $e');
      }

      if (targetDir == null) {
        final tempDir = await getTemporaryDirectory();
        targetDir = tempDir.path;
      }

      final file = File('$targetDir/$fileName');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } else {
      debugPrint('Failed to download file, status code: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Error downloading file: $e');
  }
  return null;
}
