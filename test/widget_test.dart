// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:sekom_clenner/main.dart';

void main() {
  testWidgets('Sekom Cleaner app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SekomCleanerApp());

    // Verify that our app loads with the correct title.
    expect(find.text('SEWA KOMPUTER Group'), findsOneWidget);
    
    // Verify that main sections are present
    expect(find.text('Browser Cleaning'), findsOneWidget);
    expect(find.text('System Folders'), findsOneWidget);
    expect(find.text('Windows System'), findsOneWidget);
    
    // Verify that main buttons are present
    expect(find.text('🔍 Check All'), findsOneWidget);
    expect(find.text('🧹 Bersihkan'), findsOneWidget);
  });
}
