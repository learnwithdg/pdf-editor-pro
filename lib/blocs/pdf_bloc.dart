import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_worker/pdf_worker.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/pdf_document.dart';
import '../utils/app_error_formatter.dart';
import 'pdf_event.dart';
import 'pdf_state.dart';

class PdfBloc extends Bloc<PdfEvent, PdfState> {
  PdfBloc() : super(const PdfInitial()) {
    on<LoadPdfEvent>(_onLoadPdf);
    on<ClosePdfEvent>(_onClosePdf);
    on<ChangePageEvent>(_onChangePage);
    on<ZoomInEvent>(_onZoomIn);
    on<ZoomOutEvent>(_onZoomOut);
    on<ResetZoomEvent>(_onResetZoom);
    on<SetZoomLevelEvent>(_onSetZoomLevel);
    on<ToggleEditModeEvent>(_onToggleEditMode);
    on<AddAnnotationEvent>(_onAddAnnotation);
    on<RemoveAnnotationEvent>(_onRemoveAnnotation);
    on<UpdateAnnotationEvent>(_onUpdateAnnotation);
    on<SavePdfEvent>(_onSavePdf);
    on<SelectToolEvent>(_onSelectTool);
    on<ChangeColorEvent>(_onChangeColor);
  }

  final Uuid _uuid = const Uuid();
  final PdfWorker _pdfWorker = PdfWorker();
  static const String _recentFilesKey = 'recent_pdf_files';

  Future<void> _onLoadPdf(LoadPdfEvent event, Emitter<PdfState> emit) async {
    emit(const PdfLoading());

    try {
      final file = File(event.filePath);
      if (!await file.exists()) {
        emit(const PdfError('Selected PDF file could not be found.'));
        return;
      }

      final workingPath = await _preparePdfForOpening(
        event.filePath,
        password: event.password,
      );
      final stat = await file.stat();
      final openedDocument = await pdfx.PdfDocument.openFile(workingPath);
      final pageCount = openedDocument.pagesCount;
      await openedDocument.close();

      await _addToRecentFiles(event.filePath);

      emit(
        PdfLoaded(
          document: PdfFileDocument(
            id: _uuid.v4(),
            filePath: workingPath,
            fileName: p.basename(event.filePath),
            pageCount: pageCount,
            lastModified: stat.modified,
            fileSize: stat.size,
          ),
        ),
      );
    } on _PdfPasswordRequiredException {
      emit(
        PdfPasswordRequired(
          filePath: event.filePath,
          fileName: p.basename(event.filePath),
          message: event.password == null || event.password!.trim().isEmpty
              ? 'This PDF is password protected. Enter the password to open it.'
              : 'That password did not work. Please try again.',
        ),
      );
    } catch (error) {
      emit(
        PdfError(
          AppErrorFormatter.format(
            error,
            fallback: 'This PDF could not be opened.',
          ),
        ),
      );
    }
  }

  Future<void> _addToRecentFiles(String path) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recent = prefs.getStringList(_recentFilesKey) ?? [];
    recent.remove(path);
    recent.insert(0, path);
    if (recent.length > 20) recent = recent.sublist(0, 20);
    await prefs.setStringList(_recentFilesKey, recent);
  }

  Future<String> _preparePdfForOpening(
    String filePath, {
    String? password,
  }) async {
    bool isEncrypted = false;
    try {
      isEncrypted = await _pdfWorker.isEncrypted(filePath: filePath);
    } catch (_) {
      return filePath;
    }

    if (!isEncrypted) {
      return filePath;
    }

    final cleanPassword = password?.trim() ?? '';
    if (cleanPassword.isEmpty) {
      throw const _PdfPasswordRequiredException();
    }

    final tempDirectory = await getTemporaryDirectory();
    final unlockedFile = File(
      p.join(
        tempDirectory.path,
        'open_unlocked_${DateTime.now().millisecondsSinceEpoch}_${p.basename(filePath)}',
      ),
    );
    await File(filePath).copy(unlockedFile.path);

    try {
      final success = await _pdfWorker.unlock(
        filePath: unlockedFile.path,
        password: cleanPassword,
      );
      if (!success) {
        throw const _PdfPasswordRequiredException();
      }
      return unlockedFile.path;
    } catch (error) {
      if (await unlockedFile.exists()) {
        await unlockedFile.delete();
      }
      final normalized = error.toString().toLowerCase();
      if (normalized.contains('password') || normalized.contains('encrypted')) {
        throw const _PdfPasswordRequiredException();
      }
      rethrow;
    }
  }

  void _onClosePdf(ClosePdfEvent event, Emitter<PdfState> emit) {
    emit(const PdfInitial());
  }

  void _onChangePage(ChangePageEvent event, Emitter<PdfState> emit) {
    final currentState = state;
    if (currentState is! PdfLoaded) return;

    final nextPage = event.pageIndex.clamp(
      0,
      currentState.document.pageCount - 1,
    );
    emit(
      currentState.copyWith(
        currentPage: nextPage,
        zoomLevel: 1.0,
        clearError: true,
      ),
    );
  }

  void _onZoomIn(ZoomInEvent event, Emitter<PdfState> emit) {
    final currentState = state;
    if (currentState is! PdfLoaded) return;
    emit(
      currentState.copyWith(
        zoomLevel: (currentState.zoomLevel + 0.25).clamp(1.0, 5.0),
      ),
    );
  }

  void _onZoomOut(ZoomOutEvent event, Emitter<PdfState> emit) {
    final currentState = state;
    if (currentState is! PdfLoaded) return;
    emit(
      currentState.copyWith(
        zoomLevel: (currentState.zoomLevel - 0.25).clamp(1.0, 5.0),
      ),
    );
  }

  void _onResetZoom(ResetZoomEvent event, Emitter<PdfState> emit) {
    if (state is PdfLoaded) emit((state as PdfLoaded).copyWith(zoomLevel: 1.0));
  }

  void _onSetZoomLevel(SetZoomLevelEvent event, Emitter<PdfState> emit) {
    if (state is PdfLoaded) {
      final zoom = event.zoomLevel.clamp(1.0, 5.0);
      emit((state as PdfLoaded).copyWith(zoomLevel: zoom));
    }
  }

  void _onToggleEditMode(ToggleEditModeEvent event, Emitter<PdfState> emit) {
    if (state is PdfLoaded) {
      final s = state as PdfLoaded;
      emit(
        s.copyWith(
          isEditMode: !s.isEditMode,
          selectedTool: s.isEditMode ? ToolType.none : ToolType.pen,
        ),
      );
    }
  }

  void _onAddAnnotation(AddAnnotationEvent event, Emitter<PdfState> emit) {
    final currentState = state;
    if (currentState is! PdfLoaded) return;

    final annotation = PdfAnnotation(
      id: _uuid.v4(),
      type: _mapToolType(event.type),
      pageIndex: event.pageIndex,
      x: event.x,
      y: event.y,
      width: event.width ?? 0.24,
      height: event.height ?? 0.045,
      color: event.color,
      text: event.text,
      imageBytes: event.imageBytes,
      imageName: event.imageName,
      imageZoom: event.imageZoom ?? 1.0,
      imageFocusX: event.imageFocusX ?? 0.5,
      imageFocusY: event.imageFocusY ?? 0.5,
      tableRows: event.tableRows,
      tableColumns: event.tableColumns,
      tableCells: List<String>.unmodifiable(event.tableCells),
      tableBorderWidth: event.tableBorderWidth ?? 0.0,
      textFontSize: event.textFontSize ?? 18.0,
      textBoxStyle: event.textBoxStyle ?? PdfTextBoxStyle.plain,
      textAlignment: event.textAlignment ?? PdfTextAlignment.left,
      textFillColor: event.textFillColor ?? const Color(0x00000000),
      textBorderColor: event.textBorderColor ?? event.color,
      textBorderWidth: event.textBorderWidth ?? 0.0,
      textBold: event.textBold ?? false,
      textItalic: event.textItalic ?? false,
      textUnderline: event.textUnderline ?? false,
      strokeWidth: event.strokeWidth ?? 2.0,
      points: List<Offset>.unmodifiable(event.points),
      shapeType: event.shapeType,
    );

    emit(
      currentState.copyWith(
        document: currentState.document.copyWith(
          annotations: [...currentState.document.annotations, annotation],
          clearLastSavedPath: true,
        ),
      ),
    );
  }

  void _onRemoveAnnotation(
    RemoveAnnotationEvent event,
    Emitter<PdfState> emit,
  ) {
    final currentState = state;
    if (currentState is! PdfLoaded) return;

    final updated = currentState.document.annotations
        .where((a) => a.id != event.annotationId)
        .toList();

    emit(
      currentState.copyWith(
        document: currentState.document.copyWith(annotations: updated),
      ),
    );
  }

  void _onUpdateAnnotation(
    UpdateAnnotationEvent event,
    Emitter<PdfState> emit,
  ) {
    final currentState = state;
    if (currentState is! PdfLoaded) {
      return;
    }

    final updated = currentState.document.annotations
        .map(
          (annotation) => annotation.id == event.annotationId
              ? annotation.copyWith(
                  x: event.x ?? annotation.x,
                  y: event.y ?? annotation.y,
                  width: event.width ?? annotation.width,
                  height: event.height ?? annotation.height,
                  imageZoom: event.imageZoom ?? annotation.imageZoom,
                  imageFocusX: event.imageFocusX ?? annotation.imageFocusX,
                  imageFocusY: event.imageFocusY ?? annotation.imageFocusY,
                  tableBorderWidth:
                      event.tableBorderWidth ?? annotation.tableBorderWidth,
                  text: event.text ?? annotation.text,
                  color: event.color ?? annotation.color,
                  textFontSize: event.textFontSize ?? annotation.textFontSize,
                  textBoxStyle: event.textBoxStyle ?? annotation.textBoxStyle,
                  textAlignment:
                      event.textAlignment ?? annotation.textAlignment,
                  textFillColor:
                      event.textFillColor ?? annotation.textFillColor,
                  textBorderColor:
                      event.textBorderColor ?? annotation.textBorderColor,
                  textBorderWidth:
                      event.textBorderWidth ?? annotation.textBorderWidth,
                  textBold: event.textBold ?? annotation.textBold,
                  textItalic: event.textItalic ?? annotation.textItalic,
                  textUnderline:
                      event.textUnderline ?? annotation.textUnderline,
                )
              : annotation,
        )
        .toList(growable: false);

    emit(
      currentState.copyWith(
        document: currentState.document.copyWith(
          annotations: updated,
          clearLastSavedPath: true,
        ),
      ),
    );
  }

  Future<void> _onSavePdf(SavePdfEvent event, Emitter<PdfState> emit) async {
    final currentState = state;
    if (currentState is! PdfLoaded) return;

    emit(currentState.copyWith(isSaving: true));
    try {
      final path = await _exportAnnotatedPdf(currentState.document);
      emit(
        currentState.copyWith(
          isSaving: false,
          document: currentState.document.copyWith(lastSavedPath: path),
        ),
      );
    } catch (error) {
      emit(
        currentState.copyWith(
          isSaving: false,
          error: AppErrorFormatter.format(
            error,
            fallback: 'The edited PDF could not be saved.',
          ),
        ),
      );
    }
  }

  void _onSelectTool(SelectToolEvent event, Emitter<PdfState> emit) {
    if (state is PdfLoaded) {
      final s = state as PdfLoaded;
      emit(
        s.copyWith(
          selectedTool: event.tool,
          selectedShape: event.shapeType ?? s.selectedShape,
        ),
      );
    }
  }

  void _onChangeColor(ChangeColorEvent event, Emitter<PdfState> emit) {
    if (state is PdfLoaded) {
      emit((state as PdfLoaded).copyWith(selectedColor: event.color));
    }
  }

  AnnotationType _mapToolType(ToolType tool) {
    switch (tool) {
      case ToolType.highlight:
        return AnnotationType.highlight;
      case ToolType.underline:
        return AnnotationType.underline;
      case ToolType.strikethrough:
        return AnnotationType.strikethrough;
      case ToolType.text:
        return AnnotationType.text;
      case ToolType.image:
        return AnnotationType.image;
      case ToolType.table:
        return AnnotationType.table;
      case ToolType.pen:
        return AnnotationType.ink;
      case ToolType.shape:
        return AnnotationType.shape;
      case ToolType.signature:
        return AnnotationType.signature;
      default:
        return AnnotationType.highlight;
    }
  }

  Future<String> _exportAnnotatedPdf(PdfFileDocument document) async {
    final source = await pdfx.PdfDocument.openFile(document.filePath);
    final pdf = pw.Document();

    for (var i = 0; i < document.pageCount; i++) {
      final page = await source.getPage(i + 1);
      final rendered = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.png,
      );

      final flattened = await _flattenAnnotations(
        rendered!.bytes,
        rendered.width!,
        rendered.height!,
        document.annotations.where((a) => a.pageIndex == i).toList(),
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.SizedBox.expand(
            child: pw.Image(pw.MemoryImage(flattened), fit: pw.BoxFit.fill),
          ),
        ),
      );
      await page.close();
    }
    await source.close();

    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final fileName =
        'Edited_${p.basenameWithoutExtension(document.fileName)}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  Future<Uint8List> _flattenAnnotations(
    Uint8List bytes,
    int w,
    int h,
    List<PdfAnnotation> annotations,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(w.toDouble(), h.toDouble());

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    canvas.drawImage(frame.image, Offset.zero, Paint());

    for (final a in annotations) {
      final rect = Rect.fromLTWH(
        a.x * size.width,
        a.y * size.height,
        a.width * size.width,
        a.height * size.height,
      );
      final paint = Paint()
        ..color = a.color
        ..strokeWidth =
            a.strokeWidth *
            (w / 1000) // Scale stroke width relative to resolution
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      switch (a.type) {
        case AnnotationType.highlight:
          canvas.drawRect(
            rect,
            paint
              ..style = PaintingStyle.fill
              ..color = a.color.withValues(alpha: 0.35),
          );
          break;
        case AnnotationType.underline:
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, paint);
          break;
        case AnnotationType.strikethrough:
          canvas.drawLine(rect.centerLeft, rect.centerRight, paint);
          break;
        case AnnotationType.text:
          _drawTextAnnotationDecorationToCanvas(canvas, rect, a, w / 1000);
          final tp = TextPainter(
            text: TextSpan(
              text: a.text,
              style: TextStyle(
                color: a.color,
                fontSize: a.textFontSize * (w / 1000) * 1.4,
                fontWeight: a.textBold ? FontWeight.w800 : FontWeight.w600,
                fontStyle: a.textItalic ? FontStyle.italic : FontStyle.normal,
                decoration: a.textUnderline ? TextDecoration.underline : null,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: _textAlignFor(a.textAlignment),
            maxLines: 8,
            ellipsis: '...',
          );
          tp.layout(maxWidth: math.max(0.0, rect.width - (12 * (w / 1000))));
          final top = a.textBoxStyle == PdfTextBoxStyle.line
              ? rect.top
              : rect.top +
                    math.max(6 * (w / 1000), (rect.height - tp.height) / 2);
          tp.paint(canvas, Offset(rect.left + (6 * (w / 1000)), top));
          break;
        case AnnotationType.image:
          if (a.imageBytes != null && a.imageBytes!.isNotEmpty) {
            await _drawImageAnnotationToCanvas(canvas, rect, a);
          }
          break;
        case AnnotationType.table:
          _drawTableAnnotationToCanvas(canvas, rect, a, w / 1000);
          break;
        case AnnotationType.ink:
        case AnnotationType.signature:
          if (a.points.isNotEmpty) {
            final path = Path();
            path.moveTo(
              a.points.first.dx * size.width,
              a.points.first.dy * size.height,
            );
            for (var pt in a.points.skip(1)) {
              path.lineTo(pt.dx * size.width, pt.dy * size.height);
            }
            canvas.drawPath(path, paint);
          }
          break;
        case AnnotationType.shape:
          if (a.points.length == 2 && a.shapeType != null) {
            final start = Offset(
              a.points[0].dx * size.width,
              a.points[0].dy * size.height,
            );
            final end = Offset(
              a.points[1].dx * size.width,
              a.points[1].dy * size.height,
            );
            _drawShapeToCanvas(canvas, start, end, paint, a.shapeType!);
          }
          break;
      }
    }

    final img = await recorder.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void _drawShapeToCanvas(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    ShapeType type,
  ) {
    switch (type) {
      case ShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case ShapeType.arrow:
        canvas.drawLine(start, end, paint);
        final angle = (end - start).direction;
        const arrowLength = 30.0;
        canvas.drawLine(
          end,
          end - Offset.fromDirection(angle - 0.5, arrowLength),
          paint,
        );
        canvas.drawLine(
          end,
          end - Offset.fromDirection(angle + 0.5, arrowLength),
          paint,
        );
        break;
      case ShapeType.rectangle:
        canvas.drawRect(Rect.fromPoints(start, end), paint);
        break;
      case ShapeType.circle:
        canvas.drawOval(Rect.fromPoints(start, end), paint);
        break;
    }
  }

  void _drawTextAnnotationDecorationToCanvas(
    Canvas canvas,
    Rect rect,
    PdfAnnotation annotation,
    double scaleFactor,
  ) {
    final fillPaint = Paint()
      ..color = annotation.textFillColor
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = annotation.textBorderColor
      ..strokeWidth = annotation.textBorderWidth * scaleFactor
      ..style = PaintingStyle.stroke;

    final hasFill = _colorAlpha(annotation.textFillColor) > 0;
    final hasBorder = annotation.textBorderWidth > 0;

    switch (annotation.textBoxStyle) {
      case PdfTextBoxStyle.plain:
        return;
      case PdfTextBoxStyle.line:
        if (hasBorder) {
          canvas.drawLine(rect.bottomLeft, rect.bottomRight, borderPaint);
        }
        return;
      case PdfTextBoxStyle.box:
      case PdfTextBoxStyle.rectangle:
        if (hasFill) {
          canvas.drawRect(rect, fillPaint);
        }
        if (hasBorder) {
          canvas.drawRect(rect, borderPaint);
        }
        return;
      case PdfTextBoxStyle.roundedRectangle:
        final rounded = RRect.fromRectAndRadius(
          rect,
          Radius.circular(14 * scaleFactor),
        );
        if (hasFill) {
          canvas.drawRRect(rounded, fillPaint);
        }
        if (hasBorder) {
          canvas.drawRRect(rounded, borderPaint);
        }
        return;
      case PdfTextBoxStyle.circle:
        if (hasFill) {
          canvas.drawOval(rect, fillPaint);
        }
        if (hasBorder) {
          canvas.drawOval(rect, borderPaint);
        }
        return;
    }
  }

  TextAlign _textAlignFor(PdfTextAlignment alignment) {
    return switch (alignment) {
      PdfTextAlignment.left => TextAlign.left,
      PdfTextAlignment.center => TextAlign.center,
      PdfTextAlignment.right => TextAlign.right,
    };
  }

  int _colorAlpha(Color color) => (color.toARGB32() >> 24) & 0xFF;

  Future<void> _drawImageAnnotationToCanvas(
    Canvas canvas,
    Rect rect,
    PdfAnnotation annotation,
  ) async {
    final codec = await ui.instantiateImageCodec(annotation.imageBytes!);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final sourceRect = _calculateCoverSourceRect(
      image.width.toDouble(),
      image.height.toDouble(),
      rect.width,
      rect.height,
      zoom: annotation.imageZoom,
      focusX: annotation.imageFocusX,
      focusY: annotation.imageFocusY,
    );
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(
      image,
      sourceRect,
      rect,
      Paint()..filterQuality = FilterQuality.high,
    );
    canvas.restore();
  }

  void _drawTableAnnotationToCanvas(
    Canvas canvas,
    Rect rect,
    PdfAnnotation annotation,
    double scaleFactor,
  ) {
    final rows = annotation.tableRows ?? 0;
    final columns = annotation.tableColumns ?? 0;
    if (rows <= 0 || columns <= 0) {
      return;
    }

    final cellWidth = rect.width / columns;
    final cellHeight = rect.height / rows;
    final borderWidth = annotation.tableBorderWidth;
    final borderPaint = Paint()
      ..color = annotation.color
      ..strokeWidth = borderWidth * scaleFactor
      ..style = PaintingStyle.stroke;

    if (borderWidth > 0) {
      canvas.drawRect(rect, borderPaint);
      for (var column = 1; column < columns; column++) {
        final x = rect.left + (column * cellWidth);
        canvas.drawLine(
          Offset(x, rect.top),
          Offset(x, rect.bottom),
          borderPaint,
        );
      }
      for (var row = 1; row < rows; row++) {
        final y = rect.top + (row * cellHeight);
        canvas.drawLine(
          Offset(rect.left, y),
          Offset(rect.right, y),
          borderPaint,
        );
      }
    }

    final textStyle = TextStyle(
      color: annotation.color,
      fontSize: 20 * scaleFactor,
      fontWeight: FontWeight.w500,
    );
    final cellTexts = annotation.tableCells;
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final index = (row * columns) + column;
        if (index >= cellTexts.length || cellTexts[index].trim().isEmpty) {
          continue;
        }
        final cellRect = Rect.fromLTWH(
          rect.left + (column * cellWidth),
          rect.top + (row * cellHeight),
          cellWidth,
          cellHeight,
        );
        final painter = TextPainter(
          text: TextSpan(text: cellTexts[index], style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 4,
          ellipsis: '...',
        )..layout(maxWidth: cellRect.width - 12);
        painter.paint(canvas, cellRect.topLeft + const Offset(6, 6));
      }
    }
  }

  Rect _calculateCoverSourceRect(
    double sourceWidth,
    double sourceHeight,
    double destinationWidth,
    double destinationHeight, {
    required double zoom,
    required double focusX,
    required double focusY,
  }) {
    final destinationAspect = destinationWidth / destinationHeight;
    final sourceAspect = sourceWidth / sourceHeight;

    double cropWidth;
    double cropHeight;
    if (sourceAspect > destinationAspect) {
      cropHeight = sourceHeight;
      cropWidth = cropHeight * destinationAspect;
    } else {
      cropWidth = sourceWidth;
      cropHeight = cropWidth / destinationAspect;
    }

    final safeZoom = zoom.clamp(1.0, 3.0);
    cropWidth /= safeZoom;
    cropHeight /= safeZoom;

    final clampedFocusX = focusX.clamp(0.0, 1.0);
    final clampedFocusY = focusY.clamp(0.0, 1.0);
    final left = (sourceWidth - cropWidth) * clampedFocusX;
    final top = (sourceHeight - cropHeight) * clampedFocusY;

    return Rect.fromLTWH(left, top, cropWidth, cropHeight);
  }
}

class _PdfPasswordRequiredException implements Exception {
  const _PdfPasswordRequiredException();
}
