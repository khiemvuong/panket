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

    // Verify camera placeholder text exists
    expect(find.text('BẤM ĐỂ CHỤP ẢNH'), findsOneWidget);

    // Verify swipe guidance text exists (TikTok mode default)
    expect(find.text('VUỐT XUỐNG ĐỂ XEM LOCKET BẠN BÈ'), findsOneWidget);

    // Verify profile switcher label exists
    expect(find.text('Vai trò:'), findsOneWidget);
  });
}
