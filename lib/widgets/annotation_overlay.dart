import 'dart:math';
import 'package:flutter/material.dart';
import '../blocs/pdf_event.dart';
import '../models/pdf_document.dart';

class AnnotationOverlay extends StatefulWidget {
  const AnnotationOverlay({
    super.key,
    required this.annotations,
    required this.enabled,
    required this.tool,
    required this.color,
    required this.onTap,
    required this.onDrawComplete,
    required this.selectedAnnotationId,
    required this.onSelectAnnotation,
    required this.onUpdateAnnotation,
    this.onViewerTap,
    this.shapeType,
  });

  final List<PdfAnnotation> annotations;
  final bool enabled;
  final ToolType tool;
  final Color color;
  final void Function(Offset position, Size canvasSize) onTap;
  final void Function(
    List<Offset> points,
    Size canvasSize, {
    ShapeType? shapeType,
  })
  onDrawComplete;
  final String? selectedAnnotationId;
  final ValueChanged<String?> onSelectAnnotation;
  final void Function(
    String annotationId,
    double x,
    double y,
    double width,
    double height,
  )
  onUpdateAnnotation;
  final VoidCallback? onViewerTap;
  final ShapeType? shapeType;

  @override
  State<AnnotationOverlay> createState() => _AnnotationOverlayState();
}

class _AnnotationOverlayState extends State<AnnotationOverlay> {
  final List<Offset> _currentStroke = <Offset>[];
  Offset? _shapeStart;
  Offset? _shapeEnd;
  String? _manipulatingAnnotationId;
  Rect? _manipulationStartRect;
  Offset? _manipulationStartPoint;
  _AnnotationManipulationMode? _manipulationMode;
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return IgnorePointer(
          ignoring: !widget.enabled,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapDown: (details) {
              if (widget.tool == ToolType.pen ||
                  widget.tool == ToolType.shape) {
                return;
              }
              final hitAnnotation = _findInteractiveAnnotation(
                details.localPosition,
                canvasSize,
              );
              if (hitAnnotation != null &&
                  _toolMatchesAnnotation(widget.tool, hitAnnotation.type)) {
                widget.onSelectAnnotation(hitAnnotation.id);
                return;
              }
              if (widget.selectedAnnotationId != null) {
                widget.onSelectAnnotation(null);
              }
              if (widget.tool == ToolType.none) {
                widget.onViewerTap?.call();
                return;
              }
              widget.onTap(details.localPosition, canvasSize);
            },
            onPanStart: (details) {
              if (widget.tool == ToolType.pen) {
                setState(() {
                  _isDrawing = true;
                  _currentStroke
                    ..clear()
                    ..add(details.localPosition);
                });
              } else if (widget.tool == ToolType.shape) {
                setState(() {
                  _isDrawing = true;
                  _shapeStart = details.localPosition;
                  _shapeEnd = details.localPosition;
                });
              } else {
                _startAnnotationManipulation(details.localPosition, canvasSize);
              }
            },
            onPanUpdate: (details) {
              if (widget.tool == ToolType.pen) {
                if (!_isDrawing) {
                  return;
                }
                setState(() {
                  _currentStroke.add(details.localPosition);
                });
              } else if (widget.tool == ToolType.shape) {
                if (!_isDrawing) {
                  return;
                }
                setState(() {
                  _shapeEnd = details.localPosition;
                });
              } else {
                _updateAnnotationManipulation(
                  details.localPosition,
                  canvasSize,
                );
              }
            },
            onPanEnd: (_) {
              if (widget.tool == ToolType.pen && _isDrawing) {
                final finishedStroke = List<Offset>.from(_currentStroke);
                setState(() {
                  _isDrawing = false;
                  _currentStroke.clear();
                });
                widget.onDrawComplete(finishedStroke, canvasSize);
              } else if (widget.tool == ToolType.shape &&
                  _isDrawing &&
                  _shapeStart != null &&
                  _shapeEnd != null) {
                final start = _shapeStart!;
                final end = _shapeEnd!;
                setState(() {
                  _isDrawing = false;
                  _shapeStart = null;
                  _shapeEnd = null;
                });
                widget.onDrawComplete(
                  [start, end],
                  canvasSize,
                  shapeType: widget.shapeType,
                );
              } else {
                _stopAnnotationManipulation();
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final annotation in widget.annotations)
                  if (annotation.type == AnnotationType.image ||
                      annotation.type == AnnotationType.table)
                    _AnnotationVisual(
                      annotation: annotation,
                      canvasSize: canvasSize,
                    ),
                if (_selectedInteractiveAnnotation != null)
                  _SelectionFrame(
                    rect: _annotationRect(
                      _selectedInteractiveAnnotation!,
                      canvasSize,
                    ),
                  ),
                CustomPaint(
                  size: Size.infinite,
                  painter: AnnotationPainter(
                    annotations: widget.annotations,
                    currentStroke: _currentStroke,
                    strokeColor: widget.color,
                    shapeStart: _shapeStart,
                    shapeEnd: _shapeEnd,
                    shapeType: widget.shapeType,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  PdfAnnotation? get _selectedInteractiveAnnotation {
    final selectedId = widget.selectedAnnotationId;
    if (selectedId == null) {
      return null;
    }
    for (final annotation in widget.annotations.reversed) {
      if (annotation.id == selectedId &&
          (annotation.type == AnnotationType.image ||
              annotation.type == AnnotationType.table ||
              annotation.type == AnnotationType.text)) {
        return annotation;
      }
    }
    return null;
  }

  PdfAnnotation? _findInteractiveAnnotation(Offset position, Size canvasSize) {
    for (final annotation in widget.annotations.reversed) {
      if (!_toolMatchesAnnotation(widget.tool, annotation.type)) {
        continue;
      }
      if (annotation.type != AnnotationType.image &&
          annotation.type != AnnotationType.table &&
          annotation.type != AnnotationType.text) {
        continue;
      }
      if (_annotationRect(
        annotation,
        canvasSize,
      ).inflate(6).contains(position)) {
        return annotation;
      }
    }
    return null;
  }

  Rect _annotationRect(PdfAnnotation annotation, Size canvasSize) {
    return Rect.fromLTWH(
      annotation.x * canvasSize.width,
      annotation.y * canvasSize.height,
      annotation.width * canvasSize.width,
      annotation.height * canvasSize.height,
    );
  }

  bool _toolMatchesAnnotation(ToolType tool, AnnotationType type) {
    return switch ((tool, type)) {
      (ToolType.image, AnnotationType.image) => true,
      (ToolType.table, AnnotationType.table) => true,
      (ToolType.text, AnnotationType.text) => true,
      _ => false,
    };
  }

  void _startAnnotationManipulation(Offset position, Size canvasSize) {
    final selected = _selectedInteractiveAnnotation;
    if (selected == null ||
        !_toolMatchesAnnotation(widget.tool, selected.type)) {
      return;
    }
    final rect = _annotationRect(selected, canvasSize);
    if (_resizeHandleRect(rect).contains(position)) {
      setState(() {
        _manipulatingAnnotationId = selected.id;
        _manipulationMode = _AnnotationManipulationMode.resize;
        _manipulationStartRect = rect;
        _manipulationStartPoint = position;
      });
      return;
    }
    if (rect.inflate(8).contains(position)) {
      setState(() {
        _manipulatingAnnotationId = selected.id;
        _manipulationMode = _AnnotationManipulationMode.move;
        _manipulationStartRect = rect;
        _manipulationStartPoint = position;
      });
    }
  }

  void _updateAnnotationManipulation(Offset position, Size canvasSize) {
    final annotationId = _manipulatingAnnotationId;
    final startRect = _manipulationStartRect;
    final startPoint = _manipulationStartPoint;
    final mode = _manipulationMode;
    if (annotationId == null ||
        startRect == null ||
        startPoint == null ||
        mode == null) {
      return;
    }

    final delta = position - startPoint;
    Rect nextRect;
    if (mode == _AnnotationManipulationMode.move) {
      nextRect = startRect.shift(delta);
    } else {
      nextRect = Rect.fromLTWH(
        startRect.left,
        startRect.top,
        max(44, startRect.width + delta.dx),
        max(34, startRect.height + delta.dy),
      );
    }

    final clampedLeft = nextRect.left.clamp(
      0.0,
      max(0.0, canvasSize.width - nextRect.width),
    );
    final clampedTop = nextRect.top.clamp(
      0.0,
      max(0.0, canvasSize.height - nextRect.height),
    );
    final clampedWidth = nextRect.width.clamp(
      44.0,
      canvasSize.width - clampedLeft,
    );
    final clampedHeight = nextRect.height.clamp(
      34.0,
      canvasSize.height - clampedTop,
    );

    widget.onUpdateAnnotation(
      annotationId,
      clampedLeft / canvasSize.width,
      clampedTop / canvasSize.height,
      clampedWidth / canvasSize.width,
      clampedHeight / canvasSize.height,
    );
  }

  void _stopAnnotationManipulation() {
    if (_manipulatingAnnotationId == null &&
        _manipulationMode == null &&
        _manipulationStartRect == null &&
        _manipulationStartPoint == null) {
      return;
    }
    setState(() {
      _manipulatingAnnotationId = null;
      _manipulationMode = null;
      _manipulationStartRect = null;
      _manipulationStartPoint = null;
    });
  }

  Rect _resizeHandleRect(Rect rect) {
    const handleSize = 28.0;
    return Rect.fromLTWH(
      rect.right - handleSize,
      rect.bottom - handleSize,
      handleSize,
      handleSize,
    );
  }
}

class AnnotationPainter extends CustomPainter {
  AnnotationPainter({
    required this.annotations,
    required this.currentStroke,
    required this.strokeColor,
    this.shapeStart,
    this.shapeEnd,
    this.shapeType,
  });

  final List<PdfAnnotation> annotations;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final Offset? shapeStart;
  final Offset? shapeEnd;
  final ShapeType? shapeType;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      _drawAnnotation(canvas, size, annotation);
    }

    if (currentStroke.length > 1) {
      _drawStroke(
        canvas,
        currentStroke,
        strokeColor,
        2.0,
        size: size,
        normalized: false,
      );
    }

    if (shapeStart != null && shapeEnd != null && shapeType != null) {
      _drawShape(canvas, shapeStart!, shapeEnd!, strokeColor, 2.0, shapeType!);
    }
  }

  void _drawAnnotation(Canvas canvas, Size size, PdfAnnotation annotation) {
    final rect = Rect.fromLTWH(
      annotation.x * size.width,
      annotation.y * size.height,
      annotation.width * size.width,
      annotation.height * size.height,
    );

    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth = annotation.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (annotation.type) {
      case AnnotationType.highlight:
        canvas.drawRect(
          rect,
          paint
            ..style = PaintingStyle.fill
            ..color = annotation.color.withValues(alpha: 0.35),
        );
        break;
      case AnnotationType.underline:
        canvas.drawLine(
          Offset(rect.left, rect.bottom),
          Offset(rect.right, rect.bottom),
          paint,
        );
        break;
      case AnnotationType.strikethrough:
        canvas.drawLine(
          Offset(rect.left, rect.center.dy),
          Offset(rect.right, rect.center.dy),
          paint,
        );
        break;
      case AnnotationType.text:
        final tp = TextPainter(
          text: TextSpan(
            text: annotation.text,
            style: TextStyle(
              color: annotation.color,
              fontSize: annotation.textFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 8,
          ellipsis: '...',
        )..layout(maxWidth: rect.width);
        tp.paint(canvas, rect.topLeft);
        break;
      case AnnotationType.ink:
      case AnnotationType.signature:
        _drawStroke(
          canvas,
          annotation.points,
          annotation.color,
          annotation.strokeWidth,
          size: size,
        );
        break;
      case AnnotationType.shape:
        if (annotation.points.length == 2 && annotation.shapeType != null) {
          final start = annotation.points[0].scale(size.width, size.height);
          final end = annotation.points[1].scale(size.width, size.height);
          _drawShape(
            canvas,
            start,
            end,
            annotation.color,
            annotation.strokeWidth,
            annotation.shapeType!,
          );
        }
        break;
      case AnnotationType.image:
      case AnnotationType.table:
        break;
    }
  }

  void _drawShape(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double width,
    ShapeType type,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    switch (type) {
      case ShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case ShapeType.arrow:
        _drawArrow(canvas, start, end, paint);
        break;
      case ShapeType.rectangle:
        canvas.drawRect(Rect.fromPoints(start, end), paint);
        break;
      case ShapeType.circle:
        canvas.drawOval(Rect.fromPoints(start, end), paint);
        break;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);
    const arrowAngle = 30 * pi / 180;
    const arrowLength = 15.0;
    canvas.drawLine(
      end,
      end - Offset.fromDirection(angle - arrowAngle, arrowLength),
      paint,
    );
    canvas.drawLine(
      end,
      end - Offset.fromDirection(angle + arrowAngle, arrowLength),
      paint,
    );
  }

  void _drawStroke(
    Canvas canvas,
    List<Offset> points,
    Color color,
    double width, {
    required Size size,
    bool normalized = true,
  }) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    final first = normalized
        ? points.first.scale(size.width, size.height)
        : points.first;
    path.moveTo(first.dx, first.dy);
    for (var p in points.skip(1)) {
      final pos = normalized ? p.scale(size.width, size.height) : p;
      path.lineTo(pos.dx, pos.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) => true;
}

class _AnnotationVisual extends StatelessWidget {
  const _AnnotationVisual({required this.annotation, required this.canvasSize});

  final PdfAnnotation annotation;
  final Size canvasSize;

  @override
  Widget build(BuildContext context) {
    final rect = Rect.fromLTWH(
      annotation.x * canvasSize.width,
      annotation.y * canvasSize.height,
      annotation.width * canvasSize.width,
      annotation.height * canvasSize.height,
    );

    return Positioned.fromRect(
      rect: rect,
      child: IgnorePointer(
        child: switch (annotation.type) {
          AnnotationType.image => _ImageAnnotationPreview(
            annotation: annotation,
          ),
          AnnotationType.table => _TableAnnotationPreview(
            annotation: annotation,
          ),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

class _ImageAnnotationPreview extends StatelessWidget {
  const _ImageAnnotationPreview({required this.annotation});

  final PdfAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final bytes = annotation.imageBytes;
    if (bytes == null || bytes.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Align(
          alignment: Alignment(
            (annotation.imageFocusX * 2) - 1,
            (annotation.imageFocusY * 2) - 1,
          ),
          child: Transform.scale(
            scale: annotation.imageZoom.clamp(1.0, 3.0),
            child: SizedBox.expand(
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableAnnotationPreview extends StatelessWidget {
  const _TableAnnotationPreview({required this.annotation});

  final PdfAnnotation annotation;

  @override
  Widget build(BuildContext context) {
    final rows = annotation.tableRows ?? 0;
    final columns = annotation.tableColumns ?? 0;
    if (rows <= 0 || columns <= 0) {
      return const SizedBox.shrink();
    }

    final border = annotation.tableBorderWidth > 0
        ? TableBorder.all(
            color: annotation.color,
            width: annotation.tableBorderWidth,
          )
        : null;

    return Container(
      color: Colors.transparent,
      child: Table(
        border: border,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: List<TableRow>.generate(
          rows,
          (row) => TableRow(
            children: List<Widget>.generate(columns, (column) {
              final index = (row * columns) + column;
              final value = index < annotation.tableCells.length
                  ? annotation.tableCells[index]
                  : '';
              return Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  value,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: annotation.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SelectionFrame extends StatelessWidget {
  const _SelectionFrame({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: rect.inflate(3),
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.open_in_full_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AnnotationManipulationMode { move, resize }
