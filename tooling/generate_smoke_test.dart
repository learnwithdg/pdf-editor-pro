import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Padding(
        padding: const pw.EdgeInsets.all(32),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('PDF Editor Pro Smoke Test', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('This file is used for emulator smoke testing of image and table insertion.'),
            pw.SizedBox(height: 20),
            pw.Container(height: 160, color: PdfColors.grey200),
          ],
        ),
      ),
    ),
  );
  final file = File('tooling/smoke_test.pdf');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(await doc.save());
}
