import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String appGroupId = 'group.com.panket.app';
  static const String iOSWidgetName = 'WidgetExtension';

  // Fallback in-memory map for unsupported platforms (e.g. Windows/Web/Linux)
  static final Map<String, dynamic> _fallbackStorage = {};

  /// Khởi tạo và cấu hình App Group ID
  static Future<void> initialize() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        await HomeWidget.setAppGroupId(appGroupId);
      } catch (e) {
        debugPrint('HomeWidget initialization warning: $e');
      }
    }
  }

  /// Lưu dữ liệu vào UserDefaults (iOS) / SharedPreferences (Android) / Fallback map
  static Future<bool?> saveWidgetData(String key, dynamic value) async {
    _fallbackStorage[key] = value;
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        return await HomeWidget.saveWidgetData(key, value);
      } catch (e) {
        debugPrint('HomeWidget.saveWidgetData warning: $e');
      }
    }
    return true;
  }

  /// Kích hoạt Widget làm mới giao diện
  static Future<bool?> updateWidget() async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        return await HomeWidget.updateWidget(
          iOSName: iOSWidgetName,
        );
      } catch (e) {
        debugPrint('HomeWidget.updateWidget warning: $e');
      }
    }
    return true;
  }

  /// Đọc dữ liệu từ UserDefaults (iOS) / SharedPreferences (Android) / Fallback map
  static Future<T?> getWidgetData<T>(String key) async {
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        return await HomeWidget.getWidgetData<T>(key);
      } catch (e) {
        debugPrint('HomeWidget.getWidgetData warning: $e');
      }
    }
    return _fallbackStorage[key] as T?;
  }

  /// Lưu trữ đường dẫn ảnh và âm thanh mới cho Widget và kích hoạt cập nhật
  static Future<void> updateWidgetMedia({
    required String imagePath,
    String? audioPath,
  }) async {
    await saveWidgetData('imagePath', imagePath);
    if (audioPath != null) {
      await saveWidgetData('audioPath', audioPath);
    }
    await updateWidget();
  }
}
