import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:panket/firebase_options.dart';
import 'package:panket/services/background_handler.dart';
import 'package:panket/services/widget_service.dart';
import 'package:panket/services/firebase_service.dart';
import 'package:panket/viewmodels/locket_viewmodel.dart';
import 'package:panket/views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Khởi tạo và kiểm tra kết nối với Firebase
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization failed or config missing: $e');
  }

  // Cấu hình App Group cho home_widget
  await WidgetService.initialize();

  // Đăng ký background message handler cho FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocketViewModel()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context), // Cần cho DevicePreview
      builder: DevicePreview.appBuilder, // Cần cho DevicePreview
      title: 'Panket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF48FB1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeView(),
    );
  }
}
