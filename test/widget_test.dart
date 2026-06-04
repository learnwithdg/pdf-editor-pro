import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_editor_app/main.dart';

void main() {
  testWidgets('home screen renders open action', (tester) async {
    await tester.pumpWidget(const PdfEditorApp());
    await tester.pumpAndSettle();

    expect(find.text('PDF Editor Pro'), findsWidgets);
    expect(find.text('Open PDF File'), findsOneWidget);
  });
}
