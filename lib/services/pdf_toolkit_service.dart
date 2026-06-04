import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_worker/pdf_worker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';
import 'package:xml/xml.dart';

import '../models/text_pdf_document.dart';

class PdfToolkitResult {
  const PdfToolkitResult({
    required this.title,
    required this.message,
    required this.outputPaths,
    this.previewText,
  });

  final String title;
  final String message;
  final List<String> outputPaths;
  final String? previewText;

  bool get hasSinglePdfOutput =>
      outputPaths.length == 1 &&
      outputPaths.first.toLowerCase().endsWith('.pdf');
}

class PdfDocumentInfo {
  const PdfDocumentInfo({
    required this.path,
    required this.fileName,
    required this.pageCount,
    required this.fileSize,
  });

  final String path;
  final String fileName;
  final int pageCount;
  final int fileSize;
}

class ToolkitOutputFile {
  const ToolkitOutputFile({
    required this.path,
    required this.fileName,
    required this.toolLabel,
    required this.extension,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String path;
  final String fileName;
  final String toolLabel;
  final String extension;
  final int sizeBytes;
  final DateTime modifiedAt;

  bool get isPdf => extension == '.pdf';
  bool get isImage =>
      const <String>{'.jpg', '.jpeg', '.png'}.contains(extension);
  bool get isReport => extension == '.txt';
}

enum PdfOcrScript {
  latin('Latin (English)', TextRecognitionScript.latin),
  devanagari('Devanagari (Hindi)', TextRecognitionScript.devanagiri);

  const PdfOcrScript(this.label, this.mlKitScript);

  final String label;
  final TextRecognitionScript mlKitScript;
}

class PdfToolkitService {
  final PdfWorker _pdfWorker = PdfWorker();
  final ImagePicker _imagePicker = ImagePicker();

  Future<PdfDocumentInfo> inspectPdf(String pdfPath) async {
    final file = File(pdfPath);
    final document = await pdfx.PdfDocument.openFile(pdfPath);

    try {
      final stat = await file.stat();
      return PdfDocumentInfo(
        path: pdfPath,
        fileName: p.basename(pdfPath),
        pageCount: document.pagesCount,
        fileSize: stat.size,
      );
    } finally {
      await document.close();
    }
  }

  Future<bool> isPdfEncrypted(String pdfPath) async {
    try {
      return await _pdfWorker.isEncrypted(filePath: pdfPath);
    } catch (_) {
      return false;
    }
  }

  Future<void> printPdf(String path) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  Future<List<ToolkitOutputFile>> listToolkitOutputs() async {
    final root = await _toolkitRootDirectory();
    if (!await root.exists()) {
      return <ToolkitOutputFile>[];
    }

    final outputs = <ToolkitOutputFile>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final extension = p.extension(entity.path).toLowerCase();
      if (!const <String>{
        '.pdf',
        '.jpg',
        '.jpeg',
        '.png',
        '.txt',
      }.contains(extension)) {
        continue;
      }
      final stat = await entity.stat();
      final relativeParts = p.split(p.relative(entity.path, from: root.path));
      final toolFolder = relativeParts.isEmpty ? 'output' : relativeParts.first;
      outputs.add(
        ToolkitOutputFile(
          path: entity.path,
          fileName: p.basename(entity.path),
          toolLabel: _humanizeToolName(toolFolder),
          extension: extension,
          sizeBytes: stat.size,
          modifiedAt: stat.modified,
        ),
      );
    }

    outputs.sort((left, right) => right.modifiedAt.compareTo(left.modifiedAt));
    return outputs;
  }

  Future<void> deleteToolkitOutput(String outputPath) async {
    final root = await _toolkitRootDirectory();
    final normalizedRoot = p.normalize(root.path);
    final normalizedOutput = p.normalize(outputPath);
    if (!normalizedOutput.startsWith(normalizedRoot)) {
      throw ArgumentError('This file is outside the app output library.');
    }

    final file = File(outputPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<PdfToolkitResult> createPdfFromImages(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw ArgumentError('Select at least one image.');
    }

    final outputFile = await _createOutputFile(
      'image_to_pdf',
      'images_to_pdf',
      'pdf',
    );
    final document = pw.Document();

    for (final imagePath in imagePaths) {
      final bytes = await File(imagePath).readAsBytes();
      final dimensions = await _decodeImageSize(bytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(dimensions.width, dimensions.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Images to PDF',
      message: 'Your PDF is ready with ${imagePaths.length} image page(s).',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> createPdfFromText(String text, String title) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Enter some text first.');
    }

    final outputFile = await _createOutputFile('text_to_pdf', title, 'pdf');
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Text(cleanText),
        ],
      ),
    );
    await outputFile.writeAsBytes(await document.save());
    return PdfToolkitResult(
      title: 'Text to PDF',
      message: 'Your text document is ready as a polished PDF.',
      outputPaths: [outputFile.path],
      previewText: cleanText,
    );
  }

  Future<PdfToolkitResult> exportPdfToImages(String pdfPath) async {
    final info = await inspectPdf(pdfPath);
    final outputDirectory = await _createOutputDirectory('pdf_to_images');
    final source = await pdfx.PdfDocument.openFile(pdfPath);
    final paths = <String>[];

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.jpeg,
        quality: 92,
      );
      final imageFile = File(
        p.join(
          outputDirectory.path,
          '${p.basenameWithoutExtension(info.fileName)}_page_$i.jpg',
        ),
      );
      await imageFile.writeAsBytes(rendered!.bytes, flush: true);
      paths.add(imageFile.path);
      await page.close();
    }

    await source.close();
    return PdfToolkitResult(
      title: 'PDF to Images',
      message: '${paths.length} PDF page JPG image(s) are ready to use.',
      outputPaths: paths,
    );
  }

  Future<PdfToolkitResult> exportSelectedPdfPagesToImages(
    String pdfPath, {
    required List<int> pageNumbers,
  }) async {
    if (pageNumbers.isEmpty) {
      throw ArgumentError('Select at least one page to export.');
    }

    final info = await inspectPdf(pdfPath);
    final safePages = pageNumbers.toSet().toList(growable: false)..sort();
    if (safePages.any((page) => page < 1 || page > info.pageCount)) {
      throw ArgumentError('Selected pages are outside the document range.');
    }

    final outputDirectory = await _createOutputDirectory('pdf_to_images');
    final source = await pdfx.PdfDocument.openFile(pdfPath);
    final paths = <String>[];

    for (final pageNumber in safePages) {
      final page = await source.getPage(pageNumber);
      final rendered = await page.render(
        width: page.width * 2.2,
        height: page.height * 2.2,
        format: pdfx.PdfPageImageFormat.jpeg,
        quality: 94,
      );
      final imageFile = File(
        p.join(
          outputDirectory.path,
          '${p.basenameWithoutExtension(info.fileName)}_page_$pageNumber.jpg',
        ),
      );
      await imageFile.writeAsBytes(rendered!.bytes, flush: true);
      paths.add(imageFile.path);
      await page.close();
    }

    await source.close();
    return PdfToolkitResult(
      title: 'PDF to Images',
      message: '${paths.length} selected page JPG image(s) are ready.',
      outputPaths: paths,
    );
  }

  Future<bool> saveImagesToGallery(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      return false;
    }

    var allSaved = true;
    for (final path in imagePaths) {
      final saved = await GallerySaver.saveImage(
        path,
        albumName: 'PDF Editor Pro',
        toDcim: false,
      );
      allSaved = allSaved && (saved ?? false);
    }
    return allSaved;
  }

  Future<PdfToolkitResult> exportStyledDocumentToPdf(
    TextPdfDocumentModel document, {
    String? baseName,
  }) async {
    if (document.pages.isEmpty) {
      throw ArgumentError('Add at least one page before exporting.');
    }

    final outputFile = await _createOutputFile(
      'text_to_pdf',
      baseName ?? document.title,
      'pdf',
    );
    final pdfDocument = pw.Document();

    for (final page in document.pages) {
      pdfDocument.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.pageWidth, page.pageHeight),
          margin: pw.EdgeInsets.zero,
          build: (_) {
            final widgets = <pw.Widget>[
              pw.Positioned.fill(
                child: pw.Container(
                  color: PdfColor.fromInt(page.backgroundColor.toARGB32()),
                ),
              ),
            ];

            for (final element in page.elements) {
              widgets.add(_buildTextPdfElement(element));
            }

            return pw.Stack(children: widgets);
          },
        ),
      );
    }

    await outputFile.writeAsBytes(await pdfDocument.save(), flush: true);
    return PdfToolkitResult(
      title: 'Text to PDF',
      message: 'Your styled PDF has been exported successfully.',
      outputPaths: <String>[outputFile.path],
    );
  }

  Future<PdfToolkitResult> convertOfficeToPdf(
    String path,
    String typeLabel,
  ) async {
    final sections = await _extractOfficeSections(path);
    if (sections.isEmpty) {
      throw UnsupportedError(
        'This file does not contain readable text for conversion.',
      );
    }

    final outputFile = await _createOutputFile(
      'office_to_pdf',
      'converted_${p.basenameWithoutExtension(path)}',
      'pdf',
    );

    final document = pw.Document();
    final preview = StringBuffer();
    var previewLines = 0;

    document.addPage(
      pw.MultiPage(
        build: (_) {
          final widgets = <pw.Widget>[
            pw.Text(
              '$typeLabel to PDF',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              p.basename(path),
              style: const pw.TextStyle(color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 18),
          ];

          for (final section in sections) {
            widgets.add(
              pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 6));

            for (final line in section.lines.take(120)) {
              widgets.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(line),
                ),
              );
              if (previewLines < 18) {
                preview.writeln(line);
                previewLines++;
              }
            }

            widgets.add(pw.SizedBox(height: 12));
          }

          return widgets;
        },
      ),
    );

    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: '$typeLabel to PDF',
      message: '${p.basename(path)} has been converted into a PDF.',
      outputPaths: [outputFile.path],
      previewText: preview.toString().trim(),
    );
  }

  Future<PdfToolkitResult> duplicatePdf(String pdfPath) async {
    final source = File(pdfPath);
    if (!await source.exists()) {
      throw ArgumentError('Selected PDF file could not be found.');
    }

    final outputFile = await _createOutputFile(
      'duplicate_pdf',
      'copy_${p.basenameWithoutExtension(pdfPath)}',
      'pdf',
    );
    await source.copy(outputFile.path);
    return PdfToolkitResult(
      title: 'Duplicate PDF',
      message: 'A backup copy of ${p.basename(pdfPath)} is ready.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> createPdfInfoReport(String pdfPath) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw ArgumentError('Selected PDF file could not be found.');
    }

    final stat = await file.stat();
    final encrypted = await isPdfEncrypted(pdfPath);
    PdfDocumentInfo? info;
    if (!encrypted) {
      try {
        info = await inspectPdf(pdfPath);
      } catch (_) {
        info = null;
      }
    }

    final report = StringBuffer()
      ..writeln('PDF Editor Pro - PDF Info Report')
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln()
      ..writeln('File name: ${p.basename(pdfPath)}')
      ..writeln('Path: $pdfPath')
      ..writeln('Pages: ${info?.pageCount ?? 'Unknown'}')
      ..writeln('File size: ${_formatBytes(stat.size)}')
      ..writeln('Encrypted: ${encrypted ? 'Yes' : 'No'}')
      ..writeln('Last modified: ${stat.modified}');

    final outputFile = await _createOutputFile(
      'pdf_info',
      'info_${p.basenameWithoutExtension(pdfPath)}',
      'txt',
    );
    await outputFile.writeAsString(report.toString(), flush: true);

    return PdfToolkitResult(
      title: 'PDF Info Report',
      message: 'A PDF details report has been generated.',
      outputPaths: [outputFile.path],
      previewText: report.toString(),
    );
  }

  Future<PdfToolkitResult> fitPdfToA4(String pdfPath) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'fit_a4',
      'a4_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(
            child: pw.Image(
              pw.MemoryImage(rendered!.bytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Fit to A4',
      message: '${info.pageCount} page(s) have been rebuilt into an A4 PDF.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> addPageNumbers(
    String pdfPath, {
    required String prefix,
  }) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'page_numbers',
      'numbered_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);
    final cleanPrefix = prefix.trim();

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      final label = cleanPrefix.isEmpty
          ? '$i / ${source.pagesCount}'
          : '$cleanPrefix $i / ${source.pagesCount}';

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
              pw.Positioned(
                bottom: 18,
                left: 0,
                right: 0,
                child: pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(10),
                    ),
                    child: pw.Text(
                      label,
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey800,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Page Numbers',
      message: 'Footer page numbers have been added to the document.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> mergePdfs(List<String> pdfPaths) async {
    if (pdfPaths.length < 2) {
      throw ArgumentError('Select at least two PDFs to merge.');
    }

    final outputFile = await _createOutputFile(
      'merge_pdf',
      'merged_pdf',
      'pdf',
    );
    final document = pw.Document();

    for (final path in pdfPaths) {
      final source = await pdfx.PdfDocument.openFile(path);
      for (var i = 1; i <= source.pagesCount; i++) {
        final page = await source.getPage(i);
        final rendered = await page.render(
          width: page.width * 2.0,
          height: page.height * 2.0,
        );
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              page.width.toDouble(),
              page.height.toDouble(),
            ),
            margin: pw.EdgeInsets.zero,
            build: (_) =>
                pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
          ),
        );
        await page.close();
      }
      await source.close();
    }

    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Merge PDFs',
      message:
          '${pdfPaths.length} PDF files have been combined into one document.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> compressPdf(String pdfPath) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'compress_pdf',
      'compressed_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width.toDouble(),
        height: page.height.toDouble(),
        format: pdfx.PdfPageImageFormat.jpeg,
        quality: 40,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Compress PDF',
      message: 'A lighter PDF copy is ready for easier sharing.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> protectPdf(String pdfPath, String password) async {
    if (password.trim().isEmpty) {
      throw ArgumentError('Password is required.');
    }
    if (await isPdfEncrypted(pdfPath)) {
      throw StateError('This PDF already has password protection.');
    }

    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'protect_pdf',
      'protected_${info.fileName}',
      'pdf',
    );
    await File(pdfPath).copy(outputFile.path);
    await _pdfWorker.lock(
      filePath: outputFile.path,
      userPassword: password,
      ownerPassword: password,
    );
    return PdfToolkitResult(
      title: 'Protect PDF',
      message: 'Password protection has been applied to your PDF.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> unlockPdfWithPassword(
    String pdfPath, {
    required String password,
  }) async {
    if (password.trim().isEmpty) {
      throw ArgumentError('Password is required.');
    }
    if (!await isPdfEncrypted(pdfPath)) {
      throw StateError('This PDF is not password protected.');
    }

    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'unlock_pdf',
      'unlocked_${info.fileName}',
      'pdf',
    );
    await File(pdfPath).copy(outputFile.path);
    final unlocked = await _pdfWorker.unlock(
      filePath: outputFile.path,
      password: password,
    );
    if (!unlocked) {
      throw StateError('The password was incorrect.');
    }
    return PdfToolkitResult(
      title: 'Unlock PDF',
      message: 'The PDF password has been removed successfully.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> flattenPdf(String pdfPath) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'flatten_pdf',
      'flattened_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
        format: pdfx.PdfPageImageFormat.png,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Flatten PDF',
      message: 'A flattened PDF copy is ready.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> applyBatesNumbering(
    String pdfPath, {
    required String prefix,
  }) async {
    final cleanPrefix = prefix.trim();
    if (cleanPrefix.isEmpty) {
      throw ArgumentError('Prefix is required.');
    }

    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'bates_number',
      'bates_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      final bates = '$cleanPrefix-${i.toString().padLeft(6, '0')}';

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
              pw.Positioned(
                bottom: 20,
                right: 20,
                child: pw.Text(
                  bates,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Bates Numbering',
      message: 'Legal page numbering has been added to the document.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> ocrPdf(
    String pdfPath, {
    required PdfOcrScript script,
  }) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'ocr_pdf',
      'ocr_${info.fileName}',
      'txt',
    );
    final source = await pdfx.PdfDocument.openFile(pdfPath);
    final textRecognizer = TextRecognizer(script: script.mlKitScript);
    final buffer = StringBuffer();

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        p.join(
          tempDir.path,
          'ocr_tmp_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await tempFile.writeAsBytes(rendered!.bytes, flush: true);

      final recognized = await textRecognizer.processImage(
        InputImage.fromFilePath(tempFile.path),
      );
      buffer.writeln('--- Page $i ---');
      buffer.writeln(recognized.text);
      buffer.writeln();
      await page.close();
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }

    await source.close();
    await textRecognizer.close();

    await outputFile.writeAsString(buffer.toString(), flush: true);
    return PdfToolkitResult(
      title: 'OCR (Image to Text)',
      message: 'Text has been extracted from ${info.pageCount} page(s).',
      outputPaths: [outputFile.path],
      previewText: buffer.toString().trim(),
    );
  }

  Future<List<String>> pickImages() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    return result?.paths.whereType<String>().toList(growable: false) ??
        <String>[];
  }

  Future<String?> captureImageFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
      maxWidth: 2480,
      maxHeight: 3508,
      preferredCameraDevice: CameraDevice.rear,
    );
    return image?.path;
  }

  Future<List<String>> pickPdfs({bool allowMultiple = false}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    return result?.paths.whereType<String>().toList(growable: false) ??
        <String>[];
  }

  Future<List<String>> pickOfficeFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['docx', 'pptx', 'xlsx', 'txt'],
    );
    return result?.paths.whereType<String>().toList(growable: false) ??
        <String>[];
  }

  Future<PdfToolkitResult> reorderPdfPages(
    String path, {
    required List<int> newOrder,
  }) async {
    final info = await inspectPdf(path);
    if (newOrder.length != info.pageCount) {
      throw ArgumentError('Enter all page numbers exactly once.');
    }

    final outputFile = await _createOutputFile(
      'reorder',
      'reordered_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(path);

    for (final pageIndex in newOrder) {
      final page = await source.getPage(pageIndex);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Reorder Pages',
      message: 'The new page order has been saved.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> rotatePdfPages(
    String pdfPath, {
    required List<int> pageNumbers,
    required int quarterTurns,
  }) async {
    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'rotate',
      'rotated_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      final shouldRotate = pageNumbers.isEmpty || pageNumbers.contains(i);
      final angle = shouldRotate ? quarterTurns * pi / 2 : 0.0;

      document.addPage(
        pw.Page(
          pageFormat: shouldRotate && quarterTurns.isOdd
              ? PdfPageFormat(page.height.toDouble(), page.width.toDouble())
              : PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(
            child: pw.Transform.rotateBox(
              angle: angle,
              child: pw.Image(
                pw.MemoryImage(rendered!.bytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Rotate Pages',
      message: 'Page rotation has been applied.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> watermarkPdf(
    String pdfPath, {
    required String watermarkText,
  }) async {
    final cleanText = watermarkText.trim();
    if (cleanText.isEmpty) {
      throw ArgumentError('Watermark text is required.');
    }

    final info = await inspectPdf(pdfPath);
    final outputFile = await _createOutputFile(
      'watermark',
      'watermarked_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
              pw.Center(
                child: pw.Opacity(
                  opacity: 0.24,
                  child: pw.Transform.rotateBox(
                    angle: -0.5,
                    child: pw.Text(
                      cleanText,
                      style: pw.TextStyle(
                        fontSize: 50,
                        color: PdfColors.grey,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Watermark PDF',
      message: 'Your watermark has been added to the PDF.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> extractPageRange(
    String pdfPath, {
    required int startPage,
    required int endPage,
  }) async {
    final info = await inspectPdf(pdfPath);
    if (startPage < 1 || endPage > info.pageCount || startPage > endPage) {
      throw ArgumentError('Enter a valid page range.');
    }

    final outputFile = await _createOutputFile(
      'extract',
      'extracted_${info.fileName}',
      'pdf',
    );
    final document = pw.Document();
    final source = await pdfx.PdfDocument.openFile(pdfPath);

    for (var i = startPage; i <= endPage; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
        ),
      );
      await page.close();
    }

    await source.close();
    await outputFile.writeAsBytes(await document.save(), flush: true);
    return PdfToolkitResult(
      title: 'Extract Pages',
      message:
          'Pages $startPage to $endPage have been extracted into a new PDF.',
      outputPaths: [outputFile.path],
    );
  }

  Future<PdfToolkitResult> splitIntoSinglePagePdfs(String pdfPath) async {
    final info = await inspectPdf(pdfPath);
    final outputDirectory = await _createOutputDirectory('split');
    final source = await pdfx.PdfDocument.openFile(pdfPath);
    final paths = <String>[];

    for (var i = 1; i <= source.pagesCount; i++) {
      final page = await source.getPage(i);
      final rendered = await page.render(
        width: page.width * 2.0,
        height: page.height * 2.0,
      );
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            page.width.toDouble(),
            page.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(rendered!.bytes), fit: pw.BoxFit.fill),
        ),
      );
      final file = File(
        p.join(
          outputDirectory.path,
          '${p.basenameWithoutExtension(info.fileName)}_page_$i.pdf',
        ),
      );
      await file.writeAsBytes(await document.save(), flush: true);
      paths.add(file.path);
      await page.close();
    }

    await source.close();
    return PdfToolkitResult(
      title: 'Split PDF',
      message: '${paths.length} single-page PDF files are ready.',
      outputPaths: paths,
    );
  }

  Future<File> _createOutputFile(
    String tool,
    String baseName,
    String extension,
  ) async {
    final directory = await _createOutputDirectory(tool);
    return File(
      p.join(
        directory.path,
        '${_slugify(baseName)}_${DateTime.now().millisecondsSinceEpoch}.$extension',
      ),
    );
  }

  Future<Directory> _createOutputDirectory(String tool) async {
    final root = await _toolkitRootDirectory();
    final dir = Directory(p.join(root.path, tool));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _toolkitRootDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'pdf_toolkit'));
  }

  Future<ui.Size> _decodeImageSize(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble());
  }

  Future<List<_OfficeSection>> _extractOfficeSections(String path) async {
    final extension = p.extension(path).toLowerCase();
    switch (extension) {
      case '.txt':
        return _extractTextSections(path);
      case '.docx':
        return _extractDocxSections(path);
      case '.pptx':
        return _extractPptxSections(path);
      case '.xlsx':
        return _extractXlsxSections(path);
      default:
        throw UnsupportedError(
          'Mobile conversion currently supports .docx, .pptx, .xlsx, and .txt files.',
        );
    }
  }

  Future<List<_OfficeSection>> _extractTextSections(String path) async {
    final text = await File(path).readAsString();
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return <_OfficeSection>[
      _OfficeSection(title: 'Text Document', lines: lines),
    ];
  }

  Future<List<_OfficeSection>> _extractDocxSections(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final documentXml = _readArchiveText(archive, 'word/document.xml');
    if (documentXml == null) {
      throw UnsupportedError('Could not read the DOCX document contents.');
    }

    final xmlDocument = XmlDocument.parse(documentXml);
    final paragraphs = _xmlDescendants(xmlDocument, 'p')
        .map(
          (paragraph) => _xmlDescendants(
            paragraph,
            't',
          ).map((node) => node.innerText).join(),
        )
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return <_OfficeSection>[
      _OfficeSection(title: 'Word Document', lines: paragraphs),
    ];
  }

  Future<List<_OfficeSection>> _extractPptxSections(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final slideFiles =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('ppt/slides/slide') &&
                  file.name.endsWith('.xml'),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => _extractSequenceNumber(
              left.name,
            ).compareTo(_extractSequenceNumber(right.name)),
          );

    final sections = <_OfficeSection>[];
    for (var i = 0; i < slideFiles.length; i++) {
      final slideXml = utf8.decode(slideFiles[i].content);
      final xmlDocument = XmlDocument.parse(slideXml);
      final lines = _xmlDescendants(xmlDocument, 't')
          .map((node) => _normalizeLine(node.innerText))
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      if (lines.isNotEmpty) {
        sections.add(_OfficeSection(title: 'Slide ${i + 1}', lines: lines));
      }
    }

    return sections;
  }

  Future<List<_OfficeSection>> _extractXlsxSections(String path) async {
    final archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    final sharedStringsXml = _readArchiveText(archive, 'xl/sharedStrings.xml');
    final sharedStrings = sharedStringsXml == null
        ? <String>[]
        : _xmlDescendants(XmlDocument.parse(sharedStringsXml), 'si')
              .map(
                (stringItem) => _xmlDescendants(
                  stringItem,
                  't',
                ).map((node) => node.innerText).join(),
              )
              .map(_normalizeLine)
              .toList(growable: false);

    final sheetFiles =
        archive.files
            .where(
              (file) =>
                  file.name.startsWith('xl/worksheets/sheet') &&
                  file.name.endsWith('.xml'),
            )
            .toList(growable: false)
          ..sort(
            (left, right) => _extractSequenceNumber(
              left.name,
            ).compareTo(_extractSequenceNumber(right.name)),
          );

    final sections = <_OfficeSection>[];
    for (var i = 0; i < sheetFiles.length; i++) {
      final xmlDocument = XmlDocument.parse(utf8.decode(sheetFiles[i].content));
      final rows = <String>[];

      for (final row in _xmlDescendants(xmlDocument, 'row')) {
        final values = <String>[];
        for (final cell in row.children.whereType<XmlElement>().where(
          (element) => element.name.local == 'c',
        )) {
          final cellValue = _extractSpreadsheetCellText(cell, sharedStrings);
          if (cellValue.isNotEmpty) {
            values.add(cellValue);
          }
        }
        if (values.isNotEmpty) {
          rows.add(values.join(' | '));
        }
      }

      if (rows.isNotEmpty) {
        sections.add(_OfficeSection(title: 'Sheet ${i + 1}', lines: rows));
      }
    }

    return sections;
  }

  String _extractSpreadsheetCellText(
    XmlElement cell,
    List<String> sharedStrings,
  ) {
    final type = cell.getAttribute('t');
    if (type == 'inlineStr') {
      return _xmlDescendants(
        cell,
        't',
      ).map((node) => node.innerText).join(' ').trim();
    }

    final valueElement = cell.children.whereType<XmlElement>().firstWhere(
      (element) => element.name.local == 'v',
      orElse: () => XmlElement(XmlName('empty')),
    );
    final rawValue = valueElement.name.local == 'empty'
        ? ''
        : valueElement.innerText.trim();
    if (rawValue.isEmpty) {
      return '';
    }
    if (type == 's') {
      final index = int.tryParse(rawValue);
      if (index != null && index >= 0 && index < sharedStrings.length) {
        return sharedStrings[index];
      }
    }
    return rawValue;
  }

  Iterable<XmlElement> _xmlDescendants(XmlNode node, String localName) {
    return node.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == localName,
    );
  }

  String? _readArchiveText(Archive archive, String fileName) {
    for (final file in archive.files) {
      if (file.name == fileName) {
        return utf8.decode(file.content);
      }
    }
    return null;
  }

  int _extractSequenceNumber(String value) {
    final match = RegExp(r'(\d+)').firstMatch(value);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  String _normalizeLine(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    const suffixes = <String>['KB', 'MB', 'GB'];
    var value = bytes / 1024;
    var suffixIndex = 0;
    while (value >= 1024 && suffixIndex < suffixes.length - 1) {
      value /= 1024;
      suffixIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 ? 1 : 2)} ${suffixes[suffixIndex]}';
  }

  String _humanizeToolName(String value) {
    return value
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _slugify(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  pw.Widget _buildTextPdfElement(TextPdfElement element) {
    if (element is TextPdfTextBlock) {
      final textWidgets = _buildStyledTextLayers(element);
      return pw.Positioned(
        left: element.left,
        top: element.top,
        child: pw.SizedBox(
          width: element.width,
          height: element.height,
          child: pw.Container(
            padding: pw.EdgeInsets.all(element.padding),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(element.fillColor.toARGB32()),
              borderRadius: pw.BorderRadius.circular(element.cornerRadius),
              border: element.boxBorderWidth > 0
                  ? pw.Border.all(
                      color: PdfColor.fromInt(
                        element.boxBorderColor.toARGB32(),
                      ),
                      width: element.boxBorderWidth,
                    )
                  : null,
            ),
            child: pw.Stack(children: textWidgets),
          ),
        ),
      );
    }

    if (element is TextPdfImageBlock) {
      final imageBytes = File(element.imagePath).readAsBytesSync();
      final fit = element.fit == TextPdfImageFit.cover
          ? pw.BoxFit.cover
          : pw.BoxFit.contain;
      final alignment = pw.Alignment(
        (element.focusX * 2) - 1,
        1 - (element.focusY * 2),
      );
      final imageWidget = pw.FittedBox(
        fit: fit,
        alignment: alignment,
        child: pw.Transform.scale(
          scale: element.zoom,
          alignment: alignment,
          child: pw.Image(pw.MemoryImage(imageBytes), fit: fit),
        ),
      );

      final clippedImage = element.borderRadius > 0
          ? pw.ClipRRect(
              horizontalRadius: element.borderRadius,
              verticalRadius: element.borderRadius,
              child: imageWidget,
            )
          : pw.ClipRect(child: imageWidget);

      return pw.Positioned(
        left: element.left,
        top: element.top,
        child: pw.SizedBox(
          width: element.width,
          height: element.height,
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: element.borderWidth > 0
                  ? pw.Border.all(
                      color: PdfColor.fromInt(element.borderColor.toARGB32()),
                      width: element.borderWidth,
                    )
                  : null,
              borderRadius: pw.BorderRadius.circular(element.borderRadius),
            ),
            child: pw.Opacity(opacity: element.opacity, child: clippedImage),
          ),
        ),
      );
    }

    final table = element as TextPdfTableBlock;
    final rows = <pw.TableRow>[];
    for (var rowIndex = 0; rowIndex < table.rows; rowIndex++) {
      final rowCells = <pw.Widget>[];
      for (var columnIndex = 0; columnIndex < table.columns; columnIndex++) {
        final cellIndex = (rowIndex * table.columns) + columnIndex;
        final cell = table.cells[cellIndex];
        final isHeader = rowIndex == 0;
        rowCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            color: PdfColor.fromInt(
              (isHeader ? table.headerFillColor : cell.backgroundColor)
                  .toARGB32(),
            ),
            child: pw.Text(
              cell.text,
              style: pw.TextStyle(
                fontSize: table.fontSize,
                color: PdfColor.fromInt(table.textColor.toARGB32()),
                fontWeight: isHeader
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal,
              ),
            ),
          ),
        );
      }
      rows.add(pw.TableRow(children: rowCells));
    }

    return pw.Positioned(
      left: table.left,
      top: table.top,
      child: pw.SizedBox(
        width: table.width,
        height: table.height,
        child: pw.Container(
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(table.cornerRadius),
          ),
          child: pw.Table(
            border: table.borderWidth > 0
                ? pw.TableBorder.all(
                    color: PdfColor.fromInt(table.borderColor.toARGB32()),
                    width: table.borderWidth,
                  )
                : null,
            children: rows,
          ),
        ),
      ),
    );
  }

  List<pw.Widget> _buildStyledTextLayers(TextPdfTextBlock block) {
    final layers = <pw.Widget>[];
    final textStyle = _textPdfStyle(
      block,
      color: PdfColor.fromInt(block.textColor.toARGB32()),
    );
    final borderStyle = _textPdfStyle(
      block,
      color: PdfColor.fromInt(block.textBorderColor.toARGB32()),
    );
    final shadowStyle = _textPdfStyle(
      block,
      color: PdfColor.fromInt(block.shadowColor.toARGB32()),
      decoration: pw.TextDecoration.none,
    );

    if (block.textEffect == TextPdfTextEffect.shadow ||
        block.textEffect == TextPdfTextEffect.raised3d) {
      layers.add(
        pw.Positioned(
          left: block.shadowOffsetX,
          top: block.shadowOffsetY,
          child: pw.SizedBox(
            width: block.width,
            child: pw.Text(
              block.text,
              textAlign: _toPdfTextAlign(block.alignment),
              style: shadowStyle,
            ),
          ),
        ),
      );
    }

    if (block.textEffect == TextPdfTextEffect.outline ||
        block.textEffect == TextPdfTextEffect.raised3d) {
      final offset = block.textBorderWidth;
      final outlineOffsets = <Point<double>>[
        Point<double>(-offset, 0),
        Point<double>(offset, 0),
        Point<double>(0, -offset),
        Point<double>(0, offset),
      ];
      for (final point in outlineOffsets) {
        layers.add(
          pw.Positioned(
            left: point.x,
            top: point.y,
            child: pw.SizedBox(
              width: block.width,
              child: pw.Text(
                block.text,
                textAlign: _toPdfTextAlign(block.alignment),
                style: borderStyle,
              ),
            ),
          ),
        );
      }
    }

    layers.add(
      pw.Positioned(
        left: 0,
        top: 0,
        child: pw.SizedBox(
          width: block.width,
          child: pw.Text(
            block.text,
            textAlign: _toPdfTextAlign(block.alignment),
            style: textStyle,
          ),
        ),
      ),
    );
    return layers;
  }

  pw.TextStyle _textPdfStyle(
    TextPdfTextBlock block, {
    required PdfColor color,
    pw.TextDecoration? decoration,
  }) {
    return pw.TextStyle(
      fontNormal: _pdfFont(block.fontFamily, bold: false, italic: false),
      fontBold: _pdfFont(block.fontFamily, bold: true, italic: false),
      fontItalic: _pdfFont(block.fontFamily, bold: false, italic: true),
      fontBoldItalic: _pdfFont(block.fontFamily, bold: true, italic: true),
      fontSize: block.fontSize,
      color: color,
      fontWeight: block.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontStyle: block.italic ? pw.FontStyle.italic : pw.FontStyle.normal,
      letterSpacing: block.letterSpacing,
      lineSpacing: block.lineSpacing,
      decoration: decoration ?? _toPdfTextDecoration(block),
      decorationColor: color,
    );
  }

  pw.Font _pdfFont(
    TextPdfFontFamily fontFamily, {
    required bool bold,
    required bool italic,
  }) {
    return switch (fontFamily) {
      TextPdfFontFamily.mono =>
        bold && italic
            ? pw.Font.courierBoldOblique()
            : bold
            ? pw.Font.courierBold()
            : italic
            ? pw.Font.courierOblique()
            : pw.Font.courier(),
      TextPdfFontFamily.serif || TextPdfFontFamily.display =>
        bold && italic
            ? pw.Font.timesBoldItalic()
            : bold
            ? pw.Font.timesBold()
            : italic
            ? pw.Font.timesItalic()
            : pw.Font.times(),
      TextPdfFontFamily.sans =>
        bold && italic
            ? pw.Font.helveticaBoldOblique()
            : bold
            ? pw.Font.helveticaBold()
            : italic
            ? pw.Font.helveticaOblique()
            : pw.Font.helvetica(),
    };
  }

  pw.TextDecoration _toPdfTextDecoration(TextPdfTextBlock block) {
    final decorations = <pw.TextDecoration>[];
    if (block.underline) {
      decorations.add(pw.TextDecoration.underline);
    }
    if (block.strikethrough) {
      decorations.add(pw.TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) {
      return pw.TextDecoration.none;
    }
    return pw.TextDecoration.combine(decorations);
  }

  pw.TextAlign _toPdfTextAlign(TextPdfAlignment alignment) {
    switch (alignment) {
      case TextPdfAlignment.center:
        return pw.TextAlign.center;
      case TextPdfAlignment.right:
        return pw.TextAlign.right;
      case TextPdfAlignment.justify:
        return pw.TextAlign.justify;
      case TextPdfAlignment.left:
        return pw.TextAlign.left;
    }
  }
}

class _OfficeSection {
  const _OfficeSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}
