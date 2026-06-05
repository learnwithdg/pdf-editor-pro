import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../blocs/pdf_state.dart';
import '../models/pdf_document.dart';
import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/annotation_overlay.dart';
import '../widgets/ad_widgets.dart';
import '../widgets/signature_dialog.dart';
import '../widgets/toolbar.dart';
import 'page_organizer_screen.dart';
import 'pdf_to_image_studio_screen.dart';
import 'pdf_tools_hub_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  static const String _smokeImagePath = String.fromEnvironment(
    'SMOKE_IMAGE_PATH',
  );
  static Future<void> _renderQueue = Future<void>.value();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TransformationController _transformationController =
      TransformationController();
  final Map<int, Future<_RenderedPage>> _pageCache =
      <int, Future<_RenderedPage>>{};
  final PdfToolkitService _toolkitService = PdfToolkitService();

  pdfx.PdfDocument? _document;
  String? _openedPath;
  String? _lastSavedPath;
  bool _isSyncingTransform = false;
  double _lastAppliedZoom = 1.0;
  bool _showUI = true;
  String? _selectedAnnotationId;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    _transformationController.addListener(_handleTransformChanged);
  }

  @override
  void dispose() {
    unawaited(_document?.close());
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PdfBloc, PdfState>(
      listener: (context, state) {
        if (state is! PdfLoaded) {
          return;
        }
        if (_openedPath != state.document.filePath) {
          _openDocument(state.document.filePath);
        }
        _syncZoom(state.zoomLevel);
        if (state.document.lastSavedPath != null &&
            state.document.lastSavedPath != _lastSavedPath) {
          _lastSavedPath = state.document.lastSavedPath;
          AppFeedback.showSuccess(
            context,
            'Your edited PDF has been saved and is ready to share.',
            behavior: SnackBarBehavior.floating,
          );
        }
        if (state.error != null) {
          AppFeedback.showError(
            context,
            state.error!,
            fallback: 'The PDF action could not be completed.',
          );
        }
        final selectedToolSupportsObjectEditing =
            state.selectedTool == ToolType.image ||
            state.selectedTool == ToolType.table ||
            state.selectedTool == ToolType.text;
        final hasSelectedAnnotation =
            _selectedAnnotationId != null &&
            state.document.annotations.any(
              (annotation) =>
                  annotation.id == _selectedAnnotationId &&
                  annotation.pageIndex == state.currentPage,
            );
        if ((!selectedToolSupportsObjectEditing || !hasSelectedAnnotation) &&
            _selectedAnnotationId != null) {
          setState(() {
            _selectedAnnotationId = null;
          });
        }
      },
      builder: (context, state) {
        if (state is! PdfLoaded) {
          return const SizedBox.shrink();
        }

        final annotations = state.document.annotations
            .where((annotation) => annotation.pageIndex == state.currentPage)
            .toList(growable: false);
        final canTransform =
            !state.isEditMode || state.selectedTool == ToolType.none;

        return PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              context.read<PdfBloc>().add(const ClosePdfEvent());
            }
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Theme.of(context).colorScheme.surface,
            drawer: _buildThumbnailDrawer(context, state),
            appBar: _showUI ? _buildAppBar(context, state) : null,
            body: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canTransform ? _toggleUi : null,
                    child: Center(
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        minScale: 1.0,
                        maxScale: 5.0,
                        panEnabled: canTransform,
                        scaleEnabled: canTransform,
                        boundaryMargin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: _buildPageContainer(
                            context,
                            state,
                            annotations,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.isSaving) _buildSavingOverlay(),
              ],
            ),
            bottomNavigationBar: _showUI
                ? _buildBottomPanel(context, state)
                : null,
          ),
        );
      },
    );
  }

  void _toggleUi() {
    setState(() {
      _showUI = !_showUI;
    });
  }

  Widget _buildSavingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Saving edited PDF...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Rendering pages and applying annotations',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContainer(
    BuildContext context,
    PdfLoaded state,
    List<PdfAnnotation> annotations,
  ) {
    if (_document == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final overlayEnabled =
        state.isEditMode && state.selectedTool != ToolType.none;

    return FutureBuilder<_RenderedPage>(
      future: _pageCache.putIfAbsent(
        state.currentPage,
        () => _renderPage(state.currentPage, scale: 2.0),
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildPageRenderError(
            context,
            state.currentPage,
            snapshot.error,
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final page = snapshot.data!;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRect(
              child: AspectRatio(
                aspectRatio: page.width / page.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(
                        page.bytes,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned.fill(
                      child: AnnotationOverlay(
                        enabled: overlayEnabled,
                        annotations: annotations,
                        tool: state.selectedTool,
                        color: state.selectedColor,
                        selectedAnnotationId: _selectedAnnotationId,
                        onSelectAnnotation: (annotationId) {
                          if (_selectedAnnotationId == annotationId) {
                            return;
                          }
                          setState(() {
                            _selectedAnnotationId = annotationId;
                          });
                        },
                        onUpdateAnnotation:
                            (annotationId, x, y, width, height) {
                              context.read<PdfBloc>().add(
                                UpdateAnnotationEvent(
                                  annotationId: annotationId,
                                  x: x,
                                  y: y,
                                  width: width,
                                  height: height,
                                ),
                              );
                            },
                        shapeType: state.selectedShape,
                        onTap: (position, canvasSize) =>
                            _handleTap(context, state, position, canvasSize),
                        onDrawComplete: (points, canvasSize, {shapeType}) =>
                            _handleDraw(
                              context,
                              state,
                              points,
                              canvasSize,
                              shapeType: shapeType,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageRenderError(
    BuildContext context,
    int pageIndex,
    Object? error,
  ) {
    final theme = Theme.of(context);
    final message = error?.toString().trim().isNotEmpty == true
        ? error.toString().trim()
        : 'This page could not be rendered on the current device.';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.error.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 34,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Page preview could not be loaded',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () {
                setState(() {
                  _pageCache.remove(pageIndex);
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry page'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(
    BuildContext context,
    PdfLoaded state,
    Offset position,
    Size canvasSize,
  ) {
    if (state.selectedTool == ToolType.text) {
      _showTextDialog(context, state, position, canvasSize);
      return;
    }

    if (state.selectedTool == ToolType.image) {
      unawaited(_showImageInsertFlow(context, state, position, canvasSize));
      return;
    }

    if (state.selectedTool == ToolType.table) {
      unawaited(_showTableInsertFlow(context, state, position, canvasSize));
      return;
    }

    if (state.selectedTool == ToolType.signature) {
      _showSignatureDialog(context, state, position, canvasSize);
      return;
    }

    if (state.selectedTool == ToolType.none ||
        state.selectedTool == ToolType.pen ||
        state.selectedTool == ToolType.shape) {
      return;
    }

    Vibration.vibrate(duration: 30);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: position.dx / canvasSize.width,
        y: position.dy / canvasSize.height,
        type: state.selectedTool,
        color: state.selectedColor,
      ),
    );
  }

  Future<_PickedEditorImage?> _pickEditorImageBytes(
    BuildContext context,
  ) async {
    final source = await showModalBottomSheet<_EditorImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('Camera photo'),
                  subtitle: const Text(
                    'Click a new photo and place it on this PDF page.',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _EditorImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Gallery image'),
                  subtitle: const Text(
                    'Choose an existing image from the device.',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _EditorImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || source == null) {
      return null;
    }

    if (source == _EditorImageSource.camera) {
      final path = await _toolkitService.captureImageFromCamera();
      if (path == null) {
        return null;
      }
      final file = File(path);
      return _PickedEditorImage(
        bytes: await file.readAsBytes(),
        name: file.uri.pathSegments.isEmpty
            ? 'Camera image'
            : file.uri.pathSegments.last,
      );
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.single;
    var bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return _PickedEditorImage(bytes: bytes, name: file.name);
  }

  Future<void> _showImageInsertFlow(
    BuildContext context,
    PdfLoaded state,
    Offset position,
    Size canvasSize,
  ) async {
    Uint8List? bytes;
    String fileName = 'Inserted image';
    if (_smokeImagePath.isNotEmpty) {
      final smokeImage = File(_smokeImagePath);
      if (smokeImage.existsSync()) {
        bytes = await smokeImage.readAsBytes();
        fileName = smokeImage.uri.pathSegments.isNotEmpty
            ? smokeImage.uri.pathSegments.last
            : fileName;
      }
    }
    if (!context.mounted) {
      return;
    }

    if (bytes == null) {
      final picked = await _pickEditorImageBytes(context);
      if (!context.mounted || picked == null) {
        return;
      }
      bytes = picked.bytes;
      fileName = picked.name;
    }
    if (!context.mounted) {
      return;
    }
    if (bytes.isEmpty) {
      AppFeedback.showError(context, 'The selected image could not be loaded.');
      return;
    }

    final draft = await _showImageConfigSheet(context, bytes, fileName);
    if (!context.mounted || draft == null) {
      return;
    }

    Vibration.vibrate(duration: 30);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: position.dx / canvasSize.width,
        y: position.dy / canvasSize.height,
        type: ToolType.image,
        color: state.selectedColor,
        width: draft.width,
        height: draft.height,
        imageBytes: draft.bytes,
        imageName: draft.name,
        imageZoom: draft.zoom,
        imageFocusX: draft.focusX,
        imageFocusY: draft.focusY,
      ),
    );
  }

  Future<void> _showTableInsertFlow(
    BuildContext context,
    PdfLoaded state,
    Offset position,
    Size canvasSize,
  ) async {
    final draft = await _showTableConfigSheet(context);
    if (!context.mounted || draft == null) {
      return;
    }

    Vibration.vibrate(duration: 30);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: position.dx / canvasSize.width,
        y: position.dy / canvasSize.height,
        type: ToolType.table,
        color: state.selectedColor,
        width: draft.width,
        height: draft.height,
        tableRows: draft.rows,
        tableColumns: draft.columns,
        tableCells: draft.cells,
        tableBorderWidth: draft.borderWidth,
      ),
    );
  }

  void _handleDraw(
    BuildContext context,
    PdfLoaded state,
    List<Offset> points,
    Size canvasSize, {
    ShapeType? shapeType,
  }) {
    if (points.isEmpty) {
      return;
    }

    Vibration.vibrate(duration: 40);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: points.first.dx / canvasSize.width,
        y: points.first.dy / canvasSize.height,
        type: state.selectedTool,
        points: points
            .map(
              (point) => Offset(
                point.dx / canvasSize.width,
                point.dy / canvasSize.height,
              ),
            )
            .toList(growable: false),
        color: state.selectedColor,
        shapeType: shapeType,
      ),
    );
  }

  Future<void> _showTextDialog(
    BuildContext context,
    PdfLoaded state,
    Offset position,
    Size canvasSize,
  ) async {
    final draft = await _showOfficeTextSheet(
      context,
      initialColor: state.selectedColor,
    );

    if (!context.mounted || draft == null || draft.text.isEmpty) {
      return;
    }

    Vibration.vibrate(duration: 30);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: position.dx / canvasSize.width,
        y: position.dy / canvasSize.height,
        type: ToolType.text,
        text: draft.text,
        color: draft.textColor,
        width: draft.width,
        height: draft.height,
        textFontSize: draft.fontSize,
        textBoxStyle: draft.boxStyle,
        textAlignment: draft.alignment,
        textFillColor: draft.fillColor,
        textBorderColor: draft.borderColor,
        textBorderWidth: draft.borderWidth,
        textBold: draft.bold,
        textItalic: draft.italic,
        textUnderline: draft.underline,
      ),
    );
  }

  Future<void> _editTextAnnotation(
    BuildContext context,
    PdfAnnotation annotation,
  ) async {
    final draft = await _showOfficeTextSheet(
      context,
      initialColor: annotation.color,
      existing: annotation,
    );

    if (!context.mounted || draft == null || draft.text.isEmpty) {
      return;
    }

    context.read<PdfBloc>().add(
      UpdateAnnotationEvent(
        annotationId: annotation.id,
        text: draft.text,
        color: draft.textColor,
        width: draft.width,
        height: draft.height,
        textFontSize: draft.fontSize,
        textBoxStyle: draft.boxStyle,
        textAlignment: draft.alignment,
        textFillColor: draft.fillColor,
        textBorderColor: draft.borderColor,
        textBorderWidth: draft.borderWidth,
        textBold: draft.bold,
        textItalic: draft.italic,
        textUnderline: draft.underline,
      ),
    );
  }

  Future<_TextInsertDraft?> _showOfficeTextSheet(
    BuildContext context, {
    required Color initialColor,
    PdfAnnotation? existing,
  }) async {
    final controller = TextEditingController(text: existing?.text ?? '');
    var boxStyle = existing?.textBoxStyle ?? PdfTextBoxStyle.plain;
    var alignment = existing?.textAlignment ?? PdfTextAlignment.left;
    var textColor = existing?.color ?? initialColor;
    var fillColor = existing?.textFillColor ?? const Color(0x00000000);
    var borderColor = existing?.textBorderColor ?? initialColor;
    var borderWidth = existing?.textBorderWidth ?? 0.0;
    var fontSize = existing?.textFontSize ?? 18.0;
    var width = existing?.width ?? 0.42;
    var height = existing?.height ?? 0.08;
    var bold = existing?.textBold ?? false;
    var italic = existing?.textItalic ?? false;
    var underline = existing?.textUnderline ?? false;

    final result = await showModalBottomSheet<_TextInsertDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            const transparent = Color(0x00000000);
            final colorChoices = <Color>[
              Colors.black,
              const Color(0xFF0E6B5C),
              const Color(0xFF1976D2),
              const Color(0xFFD32F2F),
              const Color(0xFF8E24AA),
              const Color(0xFFFF9800),
              Colors.white,
            ];
            final fillChoices = <Color>[
              transparent,
              Colors.white,
              const Color(0xFFFFF3C4),
              const Color(0xFFE0F2FE),
              const Color(0xFFE9D5FF),
              const Color(0xFFFFDAD6),
              const Color(0xFFE8F5E9),
            ];
            final modeChoices =
                <({PdfTextBoxStyle value, String label, IconData icon})>[
                  (
                    value: PdfTextBoxStyle.plain,
                    label: 'Text',
                    icon: Icons.text_fields_rounded,
                  ),
                  (
                    value: PdfTextBoxStyle.box,
                    label: 'Box',
                    icon: Icons.check_box_outline_blank_rounded,
                  ),
                  (
                    value: PdfTextBoxStyle.line,
                    label: 'Line',
                    icon: Icons.horizontal_rule_rounded,
                  ),
                  (
                    value: PdfTextBoxStyle.rectangle,
                    label: 'Rect',
                    icon: Icons.crop_square_rounded,
                  ),
                  (
                    value: PdfTextBoxStyle.roundedRectangle,
                    label: 'Round',
                    icon: Icons.rounded_corner_rounded,
                  ),
                  (
                    value: PdfTextBoxStyle.circle,
                    label: 'Oval',
                    icon: Icons.circle_outlined,
                  ),
                ];

            Widget buildColorDot(
              Color color,
              Color selected,
              ValueChanged<Color> onTap,
            ) {
              final isTransparent = ((color.toARGB32() >> 24) & 0xFF) == 0;
              final isSelected = color.toARGB32() == selected.toARGB32();
              return GestureDetector(
                onTap: () => setModalState(() => onTap(color)),
                child: Container(
                  width: 34,
                  height: 34,
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  decoration: BoxDecoration(
                    color: isTransparent ? Colors.white : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isTransparent
                      ? Icon(
                          Icons.format_color_reset_rounded,
                          size: 17,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        existing == null
                            ? 'Office Text Insert'
                            : 'Edit Office Text',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create plain text, text boxes, line text, or text inside shapes. Drag and resize later like an office document.',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Type text for this PDF page...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Text Style',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: modeChoices
                            .map((mode) {
                              final selected = boxStyle == mode.value;
                              return ChoiceChip(
                                avatar: Icon(mode.icon, size: 16),
                                label: Text(mode.label),
                                selected: selected,
                                onSelected: (_) => setModalState(() {
                                  boxStyle = mode.value;
                                  if (boxStyle != PdfTextBoxStyle.plain &&
                                      borderWidth == 0) {
                                    borderWidth =
                                        boxStyle == PdfTextBoxStyle.line
                                        ? 2.0
                                        : 1.2;
                                  }
                                }),
                              );
                            })
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          FilterChip(
                            selected: bold,
                            label: const Text('Bold'),
                            avatar: const Icon(
                              Icons.format_bold_rounded,
                              size: 16,
                            ),
                            onSelected: (value) =>
                                setModalState(() => bold = value),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: italic,
                            label: const Text('Italic'),
                            avatar: const Icon(
                              Icons.format_italic_rounded,
                              size: 16,
                            ),
                            onSelected: (value) =>
                                setModalState(() => italic = value),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: underline,
                            label: const Text('Underline'),
                            avatar: const Icon(
                              Icons.format_underline_rounded,
                              size: 16,
                            ),
                            onSelected: (value) =>
                                setModalState(() => underline = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<PdfTextAlignment>(
                        segments: const <ButtonSegment<PdfTextAlignment>>[
                          ButtonSegment(
                            value: PdfTextAlignment.left,
                            icon: Icon(Icons.format_align_left_rounded),
                            label: Text('Left'),
                          ),
                          ButtonSegment(
                            value: PdfTextAlignment.center,
                            icon: Icon(Icons.format_align_center_rounded),
                            label: Text('Center'),
                          ),
                          ButtonSegment(
                            value: PdfTextAlignment.right,
                            icon: Icon(Icons.format_align_right_rounded),
                            label: Text('Right'),
                          ),
                        ],
                        selected: {alignment},
                        onSelectionChanged: (value) =>
                            setModalState(() => alignment = value.first),
                      ),
                      const SizedBox(height: 14),
                      Text('Font size ${fontSize.toStringAsFixed(0)}'),
                      Slider(
                        value: fontSize,
                        min: 10,
                        max: 42,
                        divisions: 32,
                        onChanged: (value) =>
                            setModalState(() => fontSize = value),
                      ),
                      Text('Box width ${(width * 100).toStringAsFixed(0)}%'),
                      Slider(
                        value: width,
                        min: 0.18,
                        max: 0.86,
                        divisions: 34,
                        onChanged: (value) =>
                            setModalState(() => width = value),
                      ),
                      Text('Box height ${(height * 100).toStringAsFixed(0)}%'),
                      Slider(
                        value: height,
                        min: 0.04,
                        max: 0.30,
                        divisions: 26,
                        onChanged: (value) =>
                            setModalState(() => height = value),
                      ),
                      Text('Border width ${borderWidth.toStringAsFixed(1)}'),
                      Slider(
                        value: borderWidth.clamp(0.0, 6.0),
                        min: 0,
                        max: 6,
                        divisions: 30,
                        onChanged: (value) =>
                            setModalState(() => borderWidth = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Text color',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: colorChoices
                            .map(
                              (color) => buildColorDot(
                                color,
                                textColor,
                                (value) => textColor = value,
                              ),
                            )
                            .toList(growable: false),
                      ),
                      Text(
                        'Shape fill',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: fillChoices
                            .map(
                              (color) => buildColorDot(
                                color,
                                fillColor,
                                (value) => fillColor = value,
                              ),
                            )
                            .toList(growable: false),
                      ),
                      Text(
                        'Border color',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        children: colorChoices
                            .map(
                              (color) => buildColorDot(
                                color,
                                borderColor,
                                (value) => borderColor = value,
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                final text = controller.text.trim();
                                if (text.isEmpty) {
                                  return;
                                }
                                Navigator.pop(
                                  sheetContext,
                                  _TextInsertDraft(
                                    text: text,
                                    textColor: textColor,
                                    fontSize: fontSize,
                                    width: width,
                                    height: height,
                                    boxStyle: boxStyle,
                                    alignment: alignment,
                                    fillColor: fillColor,
                                    borderColor: borderColor,
                                    borderWidth: borderWidth,
                                    bold: bold,
                                    italic: italic,
                                    underline: underline,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.text_fields_rounded),
                              label: Text(
                                existing == null ? 'Add Text' : 'Save Text',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<void> _showSignatureDialog(
    BuildContext context,
    PdfLoaded state,
    Offset position,
    Size canvasSize,
  ) async {
    final result = await showDialog<SignatureResult>(
      context: context,
      builder: (dialogContext) => SignatureDialog(color: state.selectedColor),
    );

    if (!context.mounted || result == null || result.points.isEmpty) {
      return;
    }

    Vibration.vibrate(duration: 30);
    context.read<PdfBloc>().add(
      AddAnnotationEvent(
        pageIndex: state.currentPage,
        x: position.dx / canvasSize.width,
        y: position.dy / canvasSize.height,
        type: ToolType.signature,
        points: result.points
            .map(
              (point) => Offset(
                point.dx / result.canvasSize.width,
                point.dy / result.canvasSize.height,
              ),
            )
            .toList(growable: false),
        color: state.selectedColor,
      ),
    );
  }

  Future<_ImageInsertDraft?> _showImageConfigSheet(
    BuildContext context,
    Uint8List bytes,
    String name,
  ) {
    var width = 0.28;
    var height = 0.18;
    var zoom = 1.0;
    var focusX = 0.5;
    var focusY = 0.5;

    return showModalBottomSheet<_ImageInsertDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildSlider({
              required String label,
              required double value,
              required double min,
              required double max,
              required int divisions,
              required String valueLabel,
              required ValueChanged<double> onChanged,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label $valueLabel',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                  ),
                ],
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Place Image',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose how the image should appear on the PDF page before placing it.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 190,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Align(
                            alignment: Alignment(
                              (focusX * 2) - 1,
                              (focusY * 2) - 1,
                            ),
                            child: Transform.scale(
                              scale: zoom,
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
                      ),
                      const SizedBox(height: 16),
                      buildSlider(
                        label: 'Width',
                        value: width,
                        min: 0.14,
                        max: 0.7,
                        divisions: 28,
                        valueLabel: '${(width * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setModalState(() => width = value),
                      ),
                      buildSlider(
                        label: 'Height',
                        value: height,
                        min: 0.08,
                        max: 0.55,
                        divisions: 24,
                        valueLabel: '${(height * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setModalState(() => height = value),
                      ),
                      buildSlider(
                        label: 'Crop zoom',
                        value: zoom,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        valueLabel: '${zoom.toStringAsFixed(2)}x',
                        onChanged: (value) => setModalState(() => zoom = value),
                      ),
                      buildSlider(
                        label: 'Horizontal focus',
                        value: focusX,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        valueLabel: '${(focusX * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setModalState(() => focusX = value),
                      ),
                      buildSlider(
                        label: 'Vertical focus',
                        value: focusY,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        valueLabel: '${(focusY * 100).toStringAsFixed(0)}%',
                        onChanged: (value) =>
                            setModalState(() => focusY = value),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(
                                sheetContext,
                                _ImageInsertDraft(
                                  bytes: bytes,
                                  name: name,
                                  width: width,
                                  height: height,
                                  zoom: zoom,
                                  focusX: focusX,
                                  focusY: focusY,
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_photo_alternate_rounded,
                              ),
                              label: const Text('Add Image'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<_TableInsertDraft?> _showTableConfigSheet(BuildContext context) {
    var rows = 2;
    var columns = 2;
    var width = 0.42;
    var height = 0.18;
    var borderWidth = 0.0;
    var cells = List<String>.filled(rows * columns, '');

    List<String> resizedCells(
      List<String> current,
      int nextRows,
      int nextColumns,
    ) {
      final resized = List<String>.filled(nextRows * nextColumns, '');
      for (var row = 0; row < nextRows; row++) {
        for (var column = 0; column < nextColumns; column++) {
          final newIndex = (row * nextColumns) + column;
          if (row < rows && column < columns) {
            final oldIndex = (row * columns) + column;
            if (oldIndex < current.length) {
              resized[newIndex] = current[oldIndex];
            }
          }
        }
      }
      return resized;
    }

    return showModalBottomSheet<_TableInsertDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildCounter({
              required String label,
              required int value,
              required VoidCallback onDecrement,
              required VoidCallback onIncrement,
            }) {
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: onDecrement,
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Text(
                            '$value',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          IconButton(
                            onPressed: onIncrement,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Insert Table',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Start borderless if you want a clean office-style layout, then fill in only the cells you need.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          buildCounter(
                            label: 'Rows',
                            value: rows,
                            onDecrement: rows <= 1
                                ? () {}
                                : () => setModalState(() {
                                    final nextRows = rows - 1;
                                    cells = resizedCells(
                                      cells,
                                      nextRows,
                                      columns,
                                    );
                                    rows = nextRows;
                                  }),
                            onIncrement: rows >= 6
                                ? () {}
                                : () => setModalState(() {
                                    final nextRows = rows + 1;
                                    cells = resizedCells(
                                      cells,
                                      nextRows,
                                      columns,
                                    );
                                    rows = nextRows;
                                  }),
                          ),
                          const SizedBox(width: 12),
                          buildCounter(
                            label: 'Columns',
                            value: columns,
                            onDecrement: columns <= 1
                                ? () {}
                                : () => setModalState(() {
                                    final nextColumns = columns - 1;
                                    cells = resizedCells(
                                      cells,
                                      rows,
                                      nextColumns,
                                    );
                                    columns = nextColumns;
                                  }),
                            onIncrement: columns >= 6
                                ? () {}
                                : () => setModalState(() {
                                    final nextColumns = columns + 1;
                                    cells = resizedCells(
                                      cells,
                                      rows,
                                      nextColumns,
                                    );
                                    columns = nextColumns;
                                  }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cell Text',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: List<Widget>.generate(rows, (row) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: List<Widget>.generate(columns, (
                                column,
                              ) {
                                final index = (row * columns) + column;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: column == columns - 1 ? 0 : 8,
                                    ),
                                    child: TextFormField(
                                      key: ValueKey(
                                        'table_cell_${rows}_${columns}_$index',
                                      ),
                                      initialValue: cells[index],
                                      maxLines: 2,
                                      onChanged: (value) =>
                                          cells[index] = value,
                                      decoration: InputDecoration(
                                        labelText: 'R${row + 1} C${column + 1}',
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Table Width ${(width * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: width,
                        min: 0.18,
                        max: 0.82,
                        divisions: 32,
                        onChanged: (value) =>
                            setModalState(() => width = value),
                      ),
                      Text(
                        'Table Height ${(height * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: height,
                        min: 0.10,
                        max: 0.55,
                        divisions: 24,
                        onChanged: (value) =>
                            setModalState(() => height = value),
                      ),
                      Text(
                        'Border ${(borderWidth * 10).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Slider(
                        value: borderWidth,
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                        onChanged: (value) =>
                            setModalState(() => borderWidth = value),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => Navigator.pop(
                                sheetContext,
                                _TableInsertDraft(
                                  rows: rows,
                                  columns: columns,
                                  width: width,
                                  height: height,
                                  borderWidth: borderWidth,
                                  cells: List<String>.unmodifiable(cells),
                                ),
                              ),
                              icon: const Icon(Icons.table_rows_rounded),
                              label: const Text('Add Table'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThumbnailDrawer(BuildContext context, PdfLoaded state) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Quick Navigation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.grid_view_rounded),
            title: const Text(
              'Organize & Reorder',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PageOrganizerScreen()),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SmartNativeAd(isSmall: true),
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: state.document.pageCount,
              itemBuilder: (context, index) {
                final isSelected = state.currentPage == index;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text('Page ${index + 1}'),
                  selected: isSelected,
                  onTap: () {
                    Vibration.vibrate(duration: 20);
                    context.read<PdfBloc>().add(ChangePageEvent(index));
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, PdfLoaded state) {
    final theme = Theme.of(context);
    final annotationCount = state.document.annotations
        .where((annotation) => annotation.pageIndex == state.currentPage)
        .length;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        style: IconButton.styleFrom(
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        onPressed: () => context.read<PdfBloc>().add(const ClosePdfEvent()),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.document.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(104),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewerStatusBar(context, state, annotationCount),
              const SizedBox(height: 8),
              _buildPageScrubber(context, state),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu_open_rounded),
          tooltip: 'Pages',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        IconButton(
          icon: Icon(
            state.isEditMode ? Icons.edit_off_rounded : Icons.edit_rounded,
          ),
          tooltip: state.isEditMode ? 'Close editor' : 'Edit PDF',
          style: IconButton.styleFrom(
            backgroundColor: state.isEditMode
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerLow,
            foregroundColor: state.isEditMode
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
          onPressed: () {
            Vibration.vibrate(duration: 30);
            setState(() {
              _showUI = true;
            });
            context.read<PdfBloc>().add(const ToggleEditModeEvent());
          },
        ),
        IconButton(
          icon: const Icon(Icons.print_rounded),
          tooltip: 'Print',
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerLow,
            foregroundColor: theme.colorScheme.onSurface,
          ),
          onPressed: () => _toolkitService.printPdf(state.document.filePath),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'share') {
              unawaited(
                SharePlus.instance.share(
                  ShareParams(files: [XFile(state.document.filePath)]),
                ),
              );
              return;
            }
            if (value == 'toolkit') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfToolsHubScreen()),
              );
              return;
            }
            if (value == 'pages_to_jpg') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      PdfToImageStudioScreen(pdfPath: state.document.filePath),
                ),
              );
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'pages_to_jpg',
              child: Row(
                children: [
                  Icon(Icons.photo_library_rounded),
                  SizedBox(width: 8),
                  Text('Save Pages as JPG'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toolkit',
              child: Row(
                children: [
                  Icon(Icons.auto_fix_high_rounded),
                  SizedBox(width: 8),
                  Text('Open Toolkit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_rounded),
                  SizedBox(width: 8),
                  Text('Share Original'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, PdfLoaded state) {
    final theme = Theme.of(context);
    final isEditing = state.isEditMode;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, isEditing ? 14 : 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUtilityBar(context, state),
              if (isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _editingStatusText(state),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const EditorToolbar(),
                if (_selectedEditableAnnotation(state) != null) ...[
                  const SizedBox(height: 10),
                  _buildSelectedObjectBar(context, state),
                ],
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              const SmartBannerAd(),
            ],
          ),
        ),
      ),
    );
  }

  PdfAnnotation? _selectedEditableAnnotation(PdfLoaded state) {
    final selectedId = _selectedAnnotationId;
    if (selectedId == null) {
      return null;
    }
    for (final annotation in state.document.annotations) {
      if (annotation.id == selectedId &&
          annotation.pageIndex == state.currentPage &&
          (annotation.type == AnnotationType.image ||
              annotation.type == AnnotationType.table ||
              annotation.type == AnnotationType.text)) {
        return annotation;
      }
    }
    return null;
  }

  Widget _buildSelectedObjectBar(BuildContext context, PdfLoaded state) {
    final theme = Theme.of(context);
    final selected = _selectedEditableAnnotation(state);
    if (selected == null) {
      return const SizedBox.shrink();
    }

    final label = switch (selected.type) {
      AnnotationType.image => 'Image selected',
      AnnotationType.table => 'Table selected',
      AnnotationType.text => 'Text selected',
      _ => 'Object selected',
    };
    final icon = switch (selected.type) {
      AnnotationType.image => Icons.image_rounded,
      AnnotationType.table => Icons.table_chart_rounded,
      AnnotationType.text => Icons.text_fields_rounded,
      _ => Icons.open_in_full_rounded,
    };
    final quickActions = <Widget>[];
    if (selected.type == AnnotationType.text) {
      quickActions.addAll([
        _MiniObjectButton(
          label: 'Edit',
          onTap: () => unawaited(_editTextAnnotation(context, selected)),
        ),
        _MiniObjectButton(
          label: 'A-',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              textFontSize: (selected.textFontSize - 2).clamp(8.0, 56.0),
            ),
          ),
        ),
        _MiniObjectButton(
          label: 'A+',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              textFontSize: (selected.textFontSize + 2).clamp(8.0, 56.0),
            ),
          ),
        ),
        _MiniObjectButton(
          label: selected.textBold ? 'B on' : 'B',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              textBold: !selected.textBold,
            ),
          ),
        ),
        _MiniObjectButton(
          label: selected.textItalic ? 'I on' : 'I',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              textItalic: !selected.textItalic,
            ),
          ),
        ),
        _MiniObjectButton(
          label: selected.textUnderline ? 'U on' : 'U',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              textUnderline: !selected.textUnderline,
            ),
          ),
        ),
      ]);
    } else if (selected.type == AnnotationType.image) {
      quickActions.addAll([
        _MiniObjectButton(
          label: 'Crop -',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              imageZoom: (selected.imageZoom - 0.15).clamp(1.0, 3.0),
            ),
          ),
        ),
        _MiniObjectButton(
          label: 'Crop +',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              imageZoom: (selected.imageZoom + 0.15).clamp(1.0, 3.0),
            ),
          ),
        ),
      ]);
    } else if (selected.type == AnnotationType.table) {
      quickActions.addAll([
        _MiniObjectButton(
          label: 'Line -',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              tableBorderWidth: (selected.tableBorderWidth - 0.2).clamp(
                0.0,
                4.0,
              ),
            ),
          ),
        ),
        _MiniObjectButton(
          label: 'Line +',
          onTap: () => context.read<PdfBloc>().add(
            UpdateAnnotationEvent(
              annotationId: selected.id,
              tableBorderWidth: (selected.tableBorderWidth + 0.2).clamp(
                0.0,
                4.0,
              ),
            ),
          ),
        ),
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$label. Drag to move, pull the corner handle to resize.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  context.read<PdfBloc>().add(
                    RemoveAnnotationEvent(selected.id),
                  );
                  setState(() {
                    _selectedAnnotationId = null;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Delete'),
              ),
            ],
          ),
          if (quickActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: quickActions),
            ),
          ],
        ],
      ),
    );
  }

  String _editingStatusText(PdfLoaded state) {
    switch (state.selectedTool) {
      case ToolType.none:
        return 'Pan and zoom mode active. Pick a tool below to annotate the page.';
      case ToolType.pen:
        return 'Draw freehand on the page with one finger.';
      case ToolType.highlight:
        return 'Tap on the page to place a highlight marker.';
      case ToolType.underline:
        return 'Tap where you want to place an underline.';
      case ToolType.strikethrough:
        return 'Tap where you want to place a strike-through.';
      case ToolType.text:
        return 'Tap to add clean text. Tap existing text to move, resize, or adjust font size.';
      case ToolType.image:
        return 'Tap on the page to place an image and adjust the crop before adding it.';
      case ToolType.table:
        return 'Tap on the page to insert a table with your own rows, columns, and cell text.';
      case ToolType.shape:
        return 'Drag on the page to place a ${state.selectedShape.name}.';
      case ToolType.signature:
        return 'Tap on the page to place your signature.';
    }
  }

  Widget _buildViewerStatusBar(
    BuildContext context,
    PdfLoaded state,
    int annotationCount,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatusPill(
            label: '${(state.zoomLevel * 100).toInt()}% zoom',
            color: theme.colorScheme.surfaceContainerHigh,
            textColor: theme.colorScheme.onSurface,
          ),
          _StatusPill(
            label: '$annotationCount marks',
            color: theme.colorScheme.secondaryContainer,
            textColor: theme.colorScheme.onSecondaryContainer,
          ),
          _StatusPill(
            label: state.isEditMode ? _toolModeLabel(state) : 'Reader',
            color: state.isEditMode
                ? theme.colorScheme.tertiaryContainer
                : theme.colorScheme.surfaceContainerHigh,
            textColor: state.isEditMode
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSurface,
          ),
        ],
      ),
    );
  }

  Widget _buildPageScrubber(BuildContext context, PdfLoaded state) {
    final theme = Theme.of(context);
    final pageCount = state.document.pageCount;
    final sliderEnabled = pageCount > 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _MiniNavButton(
            icon: Icons.arrow_back_ios_new_rounded,
            enabled: state.currentPage > 0,
            onTap: () => context.read<PdfBloc>().add(
              ChangePageEvent(state.currentPage - 1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: state.currentPage.toDouble().clamp(
                  0.0,
                  (pageCount - 1).toDouble(),
                ),
                min: 0,
                max: sliderEnabled ? (pageCount - 1).toDouble() : 1,
                divisions: sliderEnabled ? pageCount - 1 : 1,
                onChanged: !sliderEnabled
                    ? null
                    : (value) => context.read<PdfBloc>().add(
                        ChangePageEvent(value.round()),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: '${state.currentPage + 1}/$pageCount',
            color: theme.colorScheme.primaryContainer,
            textColor: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          _MiniNavButton(
            icon: Icons.arrow_forward_ios_rounded,
            enabled: state.currentPage < pageCount - 1,
            onTap: () => context.read<PdfBloc>().add(
              ChangePageEvent(state.currentPage + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityBar(BuildContext context, PdfLoaded state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _DockActionButton(
            icon: Icons.menu_open_rounded,
            label: 'Pages',
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 8),
          _DockActionButton(
            icon: state.isEditMode
                ? Icons.edit_off_rounded
                : Icons.edit_rounded,
            label: state.isEditMode ? 'Done' : 'Edit',
            emphasized: state.isEditMode,
            onTap: () {
              setState(() {
                _showUI = true;
              });
              context.read<PdfBloc>().add(const ToggleEditModeEvent());
            },
          ),
          const SizedBox(width: 8),
          _DockActionButton(
            icon: Icons.auto_fix_high_rounded,
            label: 'Toolkit',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PdfToolsHubScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          _DockActionButton(
            icon: Icons.zoom_in_rounded,
            label: 'Zoom +',
            onTap: () => context.read<PdfBloc>().add(const ZoomInEvent()),
          ),
          const SizedBox(width: 8),
          _DockActionButton(
            icon: Icons.zoom_out_rounded,
            label: 'Zoom -',
            onTap: () => context.read<PdfBloc>().add(const ZoomOutEvent()),
          ),
          const SizedBox(width: 8),
          _DockActionButton(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () {
              unawaited(
                SharePlus.instance.share(
                  ShareParams(files: [XFile(state.document.filePath)]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _toolModeLabel(PdfLoaded state) {
    if (!state.isEditMode) {
      return 'Viewer ready';
    }
    switch (state.selectedTool) {
      case ToolType.none:
        return 'Pan mode';
      case ToolType.pen:
        return 'Pen tool';
      case ToolType.highlight:
        return 'Highlight';
      case ToolType.underline:
        return 'Underline';
      case ToolType.strikethrough:
        return 'Strike';
      case ToolType.text:
        return 'Text note';
      case ToolType.image:
        return 'Image insert';
      case ToolType.table:
        return 'Table insert';
      case ToolType.shape:
        return '${state.selectedShape.name} shape';
      case ToolType.signature:
        return 'Signature';
    }
  }

  Future<void> _openDocument(String path) async {
    _openedPath = path;
    _lastSavedPath = null;
    _lastAppliedZoom = 1.0;
    _pageCache.clear();
    _transformationController.value = Matrix4.identity();
    final doc = await pdfx.PdfDocument.openFile(path);
    if (mounted) {
      setState(() {
        _document = doc;
      });
    }
  }

  void _syncZoom(double zoomLevel) {
    if ((_lastAppliedZoom - zoomLevel).abs() < 0.001) {
      return;
    }
    _lastAppliedZoom = zoomLevel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _isSyncingTransform = true;
      _transformationController.value = Matrix4.identity()
        ..scaleByDouble(zoomLevel, zoomLevel, 1.0, 1.0);
      _isSyncingTransform = false;
    });
  }

  void _handleTransformChanged() {
    if (_isSyncingTransform) {
      return;
    }
    final currentState = context.read<PdfBloc>().state;
    if (currentState is! PdfLoaded) {
      return;
    }
    final zoomLevel = _transformationController.value.getMaxScaleOnAxis().clamp(
      1.0,
      5.0,
    );
    if ((currentState.zoomLevel - zoomLevel).abs() > 0.05) {
      context.read<PdfBloc>().add(SetZoomLevelEvent(zoomLevel));
    }
  }

  Future<_RenderedPage> _renderPage(int index, {double scale = 1.0}) async {
    return _serializeRender<_RenderedPage>(() async {
      final page = await _document!.getPage(index + 1);
      try {
        final rendered = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: pdfx.PdfPageImageFormat.jpeg,
          backgroundColor: '#FFFFFF',
        );
        if (rendered == null || rendered.bytes.isEmpty) {
          throw StateError('The PDF renderer returned an empty page preview.');
        }
        return _RenderedPage(
          bytes: rendered.bytes,
          width: rendered.width?.toDouble() ?? page.width * scale,
          height: rendered.height?.toDouble() ?? page.height * scale,
        );
      } finally {
        await page.close();
      }
    });
  }

  Future<T> _serializeRender<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _renderQueue = _renderQueue.catchError((_) {}).then<void>((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        debugPrint('PDF render error: $error');
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

class _RenderedPage {
  const _RenderedPage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final double width;
  final double height;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MiniNavButton extends StatelessWidget {
  const _MiniNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: enabled ? onTap : null,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

class _MiniObjectButton extends StatelessWidget {
  const _MiniObjectButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _DockActionButton extends StatelessWidget {
  const _DockActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = emphasized
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerLow;
    final foregroundColor = emphasized
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageInsertDraft {
  const _ImageInsertDraft({
    required this.bytes,
    required this.name,
    required this.width,
    required this.height,
    required this.zoom,
    required this.focusX,
    required this.focusY,
  });

  final Uint8List bytes;
  final String name;
  final double width;
  final double height;
  final double zoom;
  final double focusX;
  final double focusY;
}

enum _EditorImageSource { camera, gallery }

class _PickedEditorImage {
  const _PickedEditorImage({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

class _TextInsertDraft {
  const _TextInsertDraft({
    required this.text,
    required this.textColor,
    required this.fontSize,
    required this.width,
    required this.height,
    required this.boxStyle,
    required this.alignment,
    required this.fillColor,
    required this.borderColor,
    required this.borderWidth,
    required this.bold,
    required this.italic,
    required this.underline,
  });

  final String text;
  final Color textColor;
  final double fontSize;
  final double width;
  final double height;
  final PdfTextBoxStyle boxStyle;
  final PdfTextAlignment alignment;
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final bool bold;
  final bool italic;
  final bool underline;
}

class _TableInsertDraft {
  const _TableInsertDraft({
    required this.rows,
    required this.columns,
    required this.width,
    required this.height,
    required this.borderWidth,
    required this.cells,
  });

  final int rows;
  final int columns;
  final double width;
  final double height;
  final double borderWidth;
  final List<String> cells;
}
