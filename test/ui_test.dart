import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sekom_clenner/main.dart';
import 'package:sekom_clenner/services/system_service.dart';

void main() {
  // Ensure bindings and enable lightweight test mode to avoid OS shell calls
  TestWidgetsFlutterBinding.ensureInitialized();
  SystemService.testMode = true;

  group('Sekom Cleaner UI Tests', () {
    testWidgets('Main screen renders all sections', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const SekomCleanerApp());
      // Let initial frames settle
      await tester.pumpAndSettle();

      // Verify the app title
      expect(find.text('SEWA KOMPUTER Group'), findsOneWidget);

      // Verify all three main sections are present
      expect(find.text('Browser Cleaning'), findsOneWidget);
      expect(find.text('System Folders'), findsOneWidget);
      expect(find.text('Windows System'), findsOneWidget);

      // Verify main action buttons
      expect(find.text('🔍 Check All'), findsOneWidget);
      expect(find.text('✅ Pilih Semua'), findsOneWidget);
      expect(find.text('❌ Batal Pilih Semua'), findsOneWidget);
      expect(find.text('🧹 Bersihkan'), findsOneWidget);
      expect(find.text('❌ Keluar'), findsOneWidget);
    });

    testWidgets('Browser section checkboxes work', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();

      // Find browser checkboxes
      final chromeCheckbox = find.text('Google Chrome');
      final edgeCheckbox = find.text('Microsoft Edge');
      final firefoxCheckbox = find.text('Mozilla Firefox');

      expect(chromeCheckbox, findsOneWidget);
      expect(edgeCheckbox, findsOneWidget);
      expect(firefoxCheckbox, findsOneWidget);

      // Test checkbox interaction
      await tester.tap(chromeCheckbox);
      await tester.pumpAndSettle();
    });

    testWidgets('System folders section displays warning', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();

      // Verify warning message is displayed
      expect(find.text('PERINGATAN: File akan dihapus permanen!'), findsOneWidget);

      // Verify folder options
      expect(find.text('📦 3D Objects'), findsOneWidget);
      expect(find.text('📄 Documents'), findsOneWidget);
      expect(find.text('📥 Downloads'), findsOneWidget);
      expect(find.text('🎵 Music'), findsOneWidget);
      expect(find.text('🖼️ Pictures'), findsOneWidget);
      expect(find.text('🎬 Videos'), findsOneWidget);
    });

    testWidgets('Windows system section shows status', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();

      // Verify system status labels
      expect(find.textContaining('Windows Defender:'), findsOneWidget);
      expect(find.textContaining('Windows Update:'), findsOneWidget);
      expect(find.textContaining('Drivers:'), findsOneWidget);
      expect(find.textContaining('Windows Activation:'), findsOneWidget);
      expect(find.textContaining('Office Activation:'), findsOneWidget);

      // Verify recent files option (label text may vary, so use contains)
      expect(find.textContaining('Hapus Recent Items'), findsOneWidget);
    });

    testWidgets('Select all functionality works', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();
  
      // Scroll to make the action buttons visible in test viewport
      final scrollable = find.byType(Scrollable).first;
  
      // Test select all button
      final selectAllButton = find.text('✅ Pilih Semua');
      expect(selectAllButton, findsOneWidget);
      await tester.scrollUntilVisible(selectAllButton, 300.0, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(selectAllButton);
      await tester.pumpAndSettle();
  
      // Test deselect all button
      final deselectAllButton = find.text('❌ Batal Pilih Semua');
      expect(deselectAllButton, findsOneWidget);
      await tester.scrollUntilVisible(deselectAllButton, 300.0, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(deselectAllButton);
      await tester.pumpAndSettle();
    });

    testWidgets('Status message displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();

      // Verify initial status message
      expect(find.text('Siap untuk membersihkan browser dan folder sistem'), findsOneWidget);
    });

    testWidgets('Activation shell button shows and opens confirmation dialog', (WidgetTester tester) async {
      await tester.pumpWidget(const SekomCleanerApp());
      await tester.pumpAndSettle();
  
      // Verify the new activation PowerShell button exists
      final activationShellButton = find.text('Buka PowerShell Aktivasi');
      expect(activationShellButton, findsOneWidget);
  
      // Ensure the button is visible by scrolling the main scrollable
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(activationShellButton, 400.0, scrollable: scrollable);
      await tester.pumpAndSettle();
  
      // Tap the button to open confirmation dialog
      await tester.tap(activationShellButton);
      await tester.pumpAndSettle();
  
      // Verify confirmation dialog appears with expected title and content
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Buka PowerShell Aktivasi'), findsWidgets); // title + button text
      expect(find.textContaining('irm https://get.activated.win'), findsOneWidget);
  
      // Cancel the dialog to avoid executing any external command
      final cancelButton = find.text('Batal');
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();
  
      // Dialog should be closed
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
