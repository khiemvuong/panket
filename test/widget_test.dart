import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:panket/main.dart';
import 'package:panket/viewmodels/locket_viewmodel.dart';

void main() {
  testWidgets('Panket HomeView smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocketViewModel()),
        ],
        child: const MyApp(),
      ),
    );

    // Verify title exists
    expect(find.text('PANKET'), findsOneWidget);

    // Verify ElevenLabs panel text exists
    expect(find.text('TẠO GIỌNG NÓI AI (ELEVENLABS)'), findsOneWidget);

    // Verify text inputs and buttons exist
    expect(find.byType(TextField), findsNWidgets(2)); // Key + Speech text fields
    expect(find.text('SINH GIỌNG NÓI AI'), findsOneWidget);
    expect(find.text('GIẢ LẬP NHẬN SILENT PUSH'), findsOneWidget);
  });
}
