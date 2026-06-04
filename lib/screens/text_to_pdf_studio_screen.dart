import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/text_pdf_document.dart';
import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';

class TextToPdfStudioScreen extends StatefulWidget {
  const TextToPdfStudioScreen({super.key});

  @override
  State<TextToPdfStudioScreen> createState() => _TextToPdfStudioScreenState();
}

class _TextToPdfStudioScreenState extends State<TextToPdfStudioScreen> {
  final PdfToolkitService _toolkitService = PdfToolkitService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _titleController = TextEditingController(
    text: 'Styled Note',
  );
  final List<Color> _palette = const <Color>[
    Color(0x00000000),
    Color(0xFF1C1917),
    Color(0xFFD63A2F),
    Color(0xFF2563EB),
    Color(0xFF15803D),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFFFFFFF),
    Color(0xFFFFF4E8),
    Color(0xFFFFE1DB),
    Color(0xFFE0F2FE),
    Color(0xFFDCFCE7),
    Color(0xFFF5F3FF),
  ];

  late TextPdfDocumentModel _document;
  int _currentPageIndex = 0;
  String? _selectedElementId;
  bool _isExporting = false;
  bool _imageCropDragMode = false;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    _document = TextPdfDocumentModel(
      title: _titleController.text,
      pages: <TextPdfPage>[
        TextPdfPage(
          id: _uuid.v4(),
          preset: TextPdfPagePreset.a4,
          backgroundColor: Colors.white,
          elements: const <TextPdfElement>[],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  TextPdfPage get _currentPage => _document.pages[_currentPageIndex];

  TextPdfElement? get _selectedElement {
    final selectedId = _selectedElementId;
    if (selectedId == null) {
      return null;
    }
    for (final element in _currentPage.elements) {
      if (element.id == selectedId) {
        return element;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedElement;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Text to PDF Studio',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isExporting ? null : _exportDocument,
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Export'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _buildHeroCard(context),
                    const SizedBox(height: 16),
                    _buildPageToolbar(context),
                    const SizedBox(height: 12),
                    _buildPagePreview(context),
                    const SizedBox(height: 16),
                    const SmartNativeAd(),
                    const SizedBox(height: 16),
                    _buildComposerActions(selected),
                    const SizedBox(height: 16),
                    _buildInspectorCard(selected),
                  ],
                ),
              ),
              const SmartBannerAd(),
            ],
          ),
          if (_isExporting) _buildExportOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[theme.colorScheme.primary, const Color(0xFF7A0F23)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: 'Document title',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
              border: InputBorder.none,
            ),
            onChanged: (value) {
              setState(() {
                _document = _document.copyWith(
                  title: value.trim().isEmpty ? 'Styled Note' : value.trim(),
                );
              });
            },
          ),
          Text(
            'Build a styled PDF page with movable text boxes, tables, custom colors, and layout controls.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildPageToolbar(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pages & Layout',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...List<Widget>.generate(_document.pages.length, (index) {
                  return ChoiceChip(
                    label: Text('Page ${index + 1}'),
                    selected: _currentPageIndex == index,
                    onSelected: (_) {
                      setState(() {
                        _currentPageIndex = index;
                        _selectedElementId = null;
                      });
                    },
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Page'),
                  onPressed: _addPage,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<TextPdfPagePreset>(
              segments: const <ButtonSegment<TextPdfPagePreset>>[
                ButtonSegment(value: TextPdfPagePreset.a4, label: Text('A4')),
                ButtonSegment(
                  value: TextPdfPagePreset.letter,
                  label: Text('Letter'),
                ),
              ],
              selected: <TextPdfPagePreset>{_currentPage.preset},
              onSelectionChanged: (selection) {
                _updateCurrentPage(
                  _currentPage.copyWith(preset: selection.first),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Page Background',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: _currentPage.backgroundColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateCurrentPage(_currentPage.copyWith(backgroundColor: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagePreview(BuildContext context) {
    final page = _currentPage;
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = math.min(constraints.maxWidth, 420.0);
        final scale = previewWidth / page.pageWidth;
        final previewHeight = page.pageHeight * scale;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.all(14),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.35),
            child: Center(
              child: Container(
                width: previewWidth,
                height: previewHeight,
                decoration: BoxDecoration(
                  color: page.backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: page.elements
                      .map((element) => _buildInteractiveElement(element, scale))
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInteractiveElement(TextPdfElement element, double scale) {
    final isSelected = element.id == _selectedElementId;

    return Positioned(
      left: element.left * scale,
      top: element.top * scale,
      width: element.width * scale,
      height: element.height * scale,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedElementId = element.id;
          });
        },
        onPanUpdate: (details) {
          if (element is TextPdfImageBlock && isSelected && _imageCropDragMode) {
            _dragImageCrop(element, details.delta, scale);
            return;
          }
          _moveElement(element, details.delta, scale);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: switch (element) {
            TextPdfTextBlock block => _buildTextBlockPreview(block),
            TextPdfImageBlock block => _buildImageBlockPreview(block),
            TextPdfTableBlock block => _buildTableBlockPreview(block),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }

  Widget _buildTextBlockPreview(TextPdfTextBlock block) {
    final text = block.text.isEmpty ? 'Empty text box' : block.text;
    final baseStyle = _textBlockPreviewStyle(block);
    final effectiveText = Text(
      text,
      textAlign: _toFlutterTextAlign(block.alignment),
      style: baseStyle,
      maxLines: 12,
      overflow: TextOverflow.fade,
    );

    return Container(
      padding: EdgeInsets.all(block.padding),
      decoration: BoxDecoration(
        color: block.fillColor,
        borderRadius: BorderRadius.circular(block.cornerRadius),
        border: block.boxBorderWidth > 0
            ? Border.all(color: block.boxBorderColor, width: block.boxBorderWidth)
            : null,
      ),
      child: _buildTextEffectPreview(block, text, baseStyle, effectiveText),
    );
  }

  TextStyle _textBlockPreviewStyle(TextPdfTextBlock block) {
    return TextStyle(
      fontSize: block.fontSize,
      color: block.textColor,
      fontFamily: _flutterFontFamily(block.fontFamily),
      fontWeight: block.bold ? FontWeight.w800 : FontWeight.w500,
      fontStyle: block.italic ? FontStyle.italic : FontStyle.normal,
      decoration: _textDecoration(block),
      height: 1.0 + (block.lineSpacing / 18),
      letterSpacing: block.letterSpacing,
      shadows: block.textEffect == TextPdfTextEffect.shadow
          ? <Shadow>[
              Shadow(
                color: block.shadowColor,
                offset: Offset(block.shadowOffsetX, block.shadowOffsetY),
                blurRadius: 2,
              ),
            ]
          : null,
    );
  }

  Widget _buildTextEffectPreview(
    TextPdfTextBlock block,
    String text,
    TextStyle baseStyle,
    Widget effectiveText,
  ) {
    if (block.textEffect == TextPdfTextEffect.none ||
        block.textEffect == TextPdfTextEffect.shadow) {
      return effectiveText;
    }

    final strokeWidth = block.textEffect == TextPdfTextEffect.raised3d
        ? math.max(1.0, block.textBorderWidth)
        : block.textBorderWidth;
    final strokeStyle = baseStyle.copyWith(
      color: block.textBorderColor,
      shadows: null,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = block.textBorderColor,
    );

    return Stack(
      children: [
        if (block.textEffect == TextPdfTextEffect.raised3d)
          Transform.translate(
            offset: Offset(block.shadowOffsetX, block.shadowOffsetY),
            child: Text(
              text,
              textAlign: _toFlutterTextAlign(block.alignment),
              style: baseStyle.copyWith(color: block.shadowColor, shadows: null),
              maxLines: 12,
              overflow: TextOverflow.fade,
            ),
          ),
        Text(
          text,
          textAlign: _toFlutterTextAlign(block.alignment),
          style: strokeStyle,
          maxLines: 12,
          overflow: TextOverflow.fade,
        ),
        effectiveText,
      ],
    );
  }

  Widget _buildTableBlockPreview(TextPdfTableBlock table) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = math.max(
          34.0,
          (constraints.maxHeight / table.rows) - 1,
        );
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(table.cornerRadius),
            border: table.borderWidth > 0
                ? Border.all(color: table.borderColor, width: table.borderWidth)
                : null,
          ),
          child: Table(
            border: table.borderWidth > 0
                ? TableBorder.all(color: table.borderColor, width: table.borderWidth)
                : null,
            children: List<TableRow>.generate(table.rows, (rowIndex) {
              return TableRow(
                children: List<Widget>.generate(table.columns, (columnIndex) {
                  final cellIndex = (rowIndex * table.columns) + columnIndex;
                  final cell = table.cells[cellIndex];
                  return Container(
                    height: rowHeight,
                    padding: const EdgeInsets.all(6),
                    color: rowIndex == 0
                        ? table.headerFillColor
                        : cell.backgroundColor,
                    child: Text(
                      cell.text.isEmpty ? ' ' : cell.text,
                      style: TextStyle(
                        fontSize: table.fontSize,
                        color: table.textColor,
                        fontWeight: rowIndex == 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildImageBlockPreview(TextPdfImageBlock block) {
    final alignment = Alignment((block.focusX * 2) - 1, (block.focusY * 2) - 1);
    final fit = block.fit == TextPdfImageFit.cover ? BoxFit.cover : BoxFit.contain;

    return ClipRRect(
      borderRadius: BorderRadius.circular(block.borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: block.borderWidth > 0
              ? Border.all(color: block.borderColor, width: block.borderWidth)
              : null,
        ),
        child: Transform.scale(
          scale: block.zoom,
          alignment: alignment,
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: FileImage(File(block.imagePath)),
                fit: fit,
                alignment: alignment,
                opacity: block.opacity.clamp(0.1, 1.0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposerActions(TextPdfElement? selected) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Composer Tools',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _addTextBlock,
                  icon: const Icon(Icons.text_fields_rounded),
                  label: const Text('Add Text Box'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickAndAddImageBlock,
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: const Text('Add Image'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _addTableBlock,
                  icon: const Icon(Icons.table_chart_rounded),
                  label: const Text('Add Table'),
                ),
                if (selected != null)
                  OutlinedButton.icon(
                    onPressed: _duplicateSelectedElement,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Duplicate'),
                  ),
                if (selected != null)
                  OutlinedButton.icon(
                    onPressed: _removeSelectedElement,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorCard(TextPdfElement? selected) {
    if (selected == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Inspector',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Tap a text box or table on the page to edit content, colors, size, alignment, and layout.',
              ),
            ],
          ),
        ),
      );
    }

    if (selected is TextPdfTextBlock) {
      return _buildTextInspector(selected);
    }
    if (selected is TextPdfImageBlock) {
      return _buildImageInspector(selected);
    }
    return _buildTableInspector(selected as TextPdfTableBlock);
  }

  Widget _buildTextInspector(TextPdfTextBlock block) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Text Box Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: block.text,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Text content',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _updateSelectedTextBlock(
                block.copyWith(text: value),
              ),
            ),
            const SizedBox(height: 16),
            _buildSliderRow(
              label: 'Font size',
              value: block.fontSize,
              min: 12,
              max: 42,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(fontSize: value)),
            ),
            _buildSliderRow(
              label: 'Line spacing',
              value: block.lineSpacing,
              min: 0,
              max: 18,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(lineSpacing: value)),
            ),
            _buildSliderRow(
              label: 'Letter spacing',
              value: block.letterSpacing,
              min: 0,
              max: 8,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(letterSpacing: value)),
            ),
            _buildSliderRow(
              label: 'Box width',
              value: block.width,
              min: 120,
              max: _currentPage.pageWidth - 40,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(width: value)),
            ),
            _buildSliderRow(
              label: 'Box height',
              value: block.height,
              min: 50,
              max: 260,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(height: value)),
            ),
            _buildSliderRow(
              label: 'Padding',
              value: block.padding,
              min: 0,
              max: 28,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(padding: value)),
            ),
            _buildSliderRow(
              label: 'Box radius',
              value: block.cornerRadius,
              min: 0,
              max: 32,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(cornerRadius: value)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text('Bold'),
                  selected: block.bold,
                  onSelected: (value) =>
                      _updateSelectedTextBlock(block.copyWith(bold: value)),
                ),
                FilterChip(
                  label: const Text('Italic'),
                  selected: block.italic,
                  onSelected: (value) =>
                      _updateSelectedTextBlock(block.copyWith(italic: value)),
                ),
                FilterChip(
                  label: const Text('Underline'),
                  selected: block.underline,
                  onSelected: (value) => _updateSelectedTextBlock(
                    block.copyWith(underline: value),
                  ),
                ),
                FilterChip(
                  label: const Text('Strike'),
                  selected: block.strikethrough,
                  onSelected: (value) => _updateSelectedTextBlock(
                    block.copyWith(strikethrough: value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<TextPdfFontFamily>(
              segments: TextPdfFontFamily.values
                  .map(
                    (font) => ButtonSegment<TextPdfFontFamily>(
                      value: font,
                      label: Text(_fontFamilyLabel(font)),
                    ),
                  )
                  .toList(growable: false),
              selected: <TextPdfFontFamily>{block.fontFamily},
              onSelectionChanged: (selection) => _updateSelectedTextBlock(
                block.copyWith(fontFamily: selection.first),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<TextPdfAlignment>(
              segments: const <ButtonSegment<TextPdfAlignment>>[
                ButtonSegment(value: TextPdfAlignment.left, label: Text('Left')),
                ButtonSegment(
                  value: TextPdfAlignment.center,
                  label: Text('Center'),
                ),
                ButtonSegment(
                  value: TextPdfAlignment.right,
                  label: Text('Right'),
                ),
                ButtonSegment(
                  value: TextPdfAlignment.justify,
                  label: Text('Justify'),
                ),
              ],
              selected: <TextPdfAlignment>{block.alignment},
              onSelectionChanged: (selection) => _updateSelectedTextBlock(
                block.copyWith(alignment: selection.first),
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<TextPdfTextEffect>(
              segments: TextPdfTextEffect.values
                  .map(
                    (effect) => ButtonSegment<TextPdfTextEffect>(
                      value: effect,
                      label: Text(_textEffectLabel(effect)),
                    ),
                  )
                  .toList(growable: false),
              selected: <TextPdfTextEffect>{block.textEffect},
              onSelectionChanged: (selection) => _updateSelectedTextBlock(
                block.copyWith(textEffect: selection.first),
              ),
            ),
            if (block.textEffect != TextPdfTextEffect.none) ...[
              const SizedBox(height: 12),
              _buildSliderRow(
                label: 'Text border',
                value: block.textBorderWidth,
                min: 1,
                max: 5,
                onChanged: (value) => _updateSelectedTextBlock(
                  block.copyWith(textBorderWidth: value),
                ),
              ),
              Text(
                'Text Border / 3D Color',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildColorStrip(
                selectedColor: block.textBorderColor,
                colors: _palette,
                onColorSelected: (color) => _updateSelectedTextBlock(
                  block.copyWith(textBorderColor: color),
                ),
              ),
            ],
            if (block.textEffect == TextPdfTextEffect.shadow ||
                block.textEffect == TextPdfTextEffect.raised3d) ...[
              const SizedBox(height: 12),
              _buildSliderRow(
                label: 'Shadow X',
                value: block.shadowOffsetX,
                min: 0,
                max: 12,
                onChanged: (value) => _updateSelectedTextBlock(
                  block.copyWith(shadowOffsetX: value),
                ),
              ),
              _buildSliderRow(
                label: 'Shadow Y',
                value: block.shadowOffsetY,
                min: 0,
                max: 12,
                onChanged: (value) => _updateSelectedTextBlock(
                  block.copyWith(shadowOffsetY: value),
                ),
              ),
              Text(
                'Shadow Color',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildColorStrip(
                selectedColor: block.shadowColor,
                colors: _palette,
                onColorSelected: (color) => _updateSelectedTextBlock(
                  block.copyWith(shadowColor: color),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Text Color',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: block.textColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedTextBlock(block.copyWith(textColor: color)),
            ),
            const SizedBox(height: 12),
            Text(
              'Text Box Fill',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: block.fillColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedTextBlock(block.copyWith(fillColor: color)),
            ),
            const SizedBox(height: 12),
            _buildSliderRow(
              label: 'Box border',
              value: block.boxBorderWidth,
              min: 0,
              max: 6,
              onChanged: (value) =>
                  _updateSelectedTextBlock(block.copyWith(boxBorderWidth: value)),
            ),
            Text(
              'Box Border Color',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: block.boxBorderColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedTextBlock(block.copyWith(boxBorderColor: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableInspector(TextPdfTableBlock table) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Table Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCounterTile(
                    label: 'Rows',
                    value: table.rows,
                    onDecrement: table.rows > 2
                        ? () => _resizeTable(
                              table,
                              rows: table.rows - 1,
                              columns: table.columns,
                            )
                        : null,
                    onIncrement: () => _resizeTable(
                      table,
                      rows: table.rows + 1,
                      columns: table.columns,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCounterTile(
                    label: 'Columns',
                    value: table.columns,
                    onDecrement: table.columns > 2
                        ? () => _resizeTable(
                              table,
                              rows: table.rows,
                              columns: table.columns - 1,
                            )
                        : null,
                    onIncrement: () => _resizeTable(
                      table,
                      rows: table.rows,
                      columns: table.columns + 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildSliderRow(
              label: 'Font size',
              value: table.fontSize,
              min: 10,
              max: 24,
              onChanged: (value) =>
                  _updateSelectedTableBlock(table.copyWith(fontSize: value)),
            ),
            _buildSliderRow(
              label: 'Table width',
              value: table.width,
              min: 180,
              max: _currentPage.pageWidth - 40,
              onChanged: (value) =>
                  _updateSelectedTableBlock(table.copyWith(width: value)),
            ),
            _buildSliderRow(
              label: 'Table height',
              value: table.height,
              min: 100,
              max: 360,
              onChanged: (value) =>
                  _updateSelectedTableBlock(table.copyWith(height: value)),
            ),
            _buildSliderRow(
              label: 'Border width',
              value: table.borderWidth,
              min: 0,
              max: 4,
              onChanged: (value) =>
                  _updateSelectedTableBlock(table.copyWith(borderWidth: value)),
            ),
            _buildSliderRow(
              label: 'Corner radius',
              value: table.cornerRadius,
              min: 0,
              max: 28,
              onChanged: (value) =>
                  _updateSelectedTableBlock(table.copyWith(cornerRadius: value)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ActionChip(
                  label: const Text('No Border'),
                  onPressed: () => _updateSelectedTableBlock(
                    table.copyWith(borderWidth: 0),
                  ),
                ),
                ActionChip(
                  label: const Text('Thin Border'),
                  onPressed: () => _updateSelectedTableBlock(
                    table.copyWith(
                      borderWidth: 1,
                      borderColor: table.borderColor.a == 0
                          ? const Color(0xFF1C1917)
                          : table.borderColor,
                    ),
                  ),
                ),
                ActionChip(
                  label: const Text('Bold Border'),
                  onPressed: () => _updateSelectedTableBlock(
                    table.copyWith(
                      borderWidth: 3,
                      borderColor: table.borderColor.a == 0
                          ? const Color(0xFF1C1917)
                          : table.borderColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _editTableCells(table),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit Cells'),
            ),
            const SizedBox(height: 14),
            Text(
              'Header Fill',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: table.headerFillColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedTableBlock(table.copyWith(headerFillColor: color)),
            ),
            const SizedBox(height: 12),
            Text(
              'Cell Fill',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: table.cellFillColor,
              colors: _palette,
              onColorSelected: (color) => _applyCellFill(table, color),
            ),
            const SizedBox(height: 12),
            Text(
              'Border Color',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: table.borderColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedTableBlock(table.copyWith(borderColor: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageInspector(TextPdfImageBlock block) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Image Settings',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _replaceImageBlock(block),
              icon: const Icon(Icons.image_search_rounded),
              label: const Text('Replace Image'),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Crop drag mode'),
              subtitle: const Text('Turn on, then drag the image preview to adjust crop focus.'),
              value: _imageCropDragMode,
              onChanged: (value) => setState(() => _imageCropDragMode = value),
            ),
            const SizedBox(height: 10),
            SegmentedButton<TextPdfImageFit>(
              segments: const <ButtonSegment<TextPdfImageFit>>[
                ButtonSegment(value: TextPdfImageFit.cover, label: Text('Crop Fill')),
                ButtonSegment(value: TextPdfImageFit.contain, label: Text('Contain')),
              ],
              selected: <TextPdfImageFit>{block.fit},
              onSelectionChanged: (selection) {
                _updateSelectedImageBlock(block.copyWith(fit: selection.first));
              },
            ),
            const SizedBox(height: 14),
            _buildSliderRow(
              label: 'Image width',
              value: block.width,
              min: 120,
              max: _currentPage.pageWidth - 40,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(width: value)),
            ),
            _buildSliderRow(
              label: 'Image height',
              value: block.height,
              min: 90,
              max: 420,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(height: value)),
            ),
            _buildSliderRow(
              label: 'Crop zoom',
              value: block.zoom,
              min: 1,
              max: 3,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(zoom: value)),
            ),
            _buildSliderRow(
              label: 'Horizontal crop',
              value: block.focusX,
              min: 0,
              max: 1,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(focusX: value)),
            ),
            _buildSliderRow(
              label: 'Vertical crop',
              value: block.focusY,
              min: 0,
              max: 1,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(focusY: value)),
            ),
            _buildSliderRow(
              label: 'Opacity',
              value: block.opacity,
              min: 0.2,
              max: 1,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(opacity: value)),
            ),
            _buildSliderRow(
              label: 'Corner radius',
              value: block.borderRadius,
              min: 0,
              max: 28,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(borderRadius: value)),
            ),
            _buildSliderRow(
              label: 'Image border',
              value: block.borderWidth,
              min: 0,
              max: 8,
              onChanged: (value) => _updateSelectedImageBlock(block.copyWith(borderWidth: value)),
            ),
            const SizedBox(height: 12),
            Text(
              'Image Border Color',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildColorStrip(
              selectedColor: block.borderColor,
              colors: _palette,
              onColorSelected: (color) =>
                  _updateSelectedImageBlock(block.copyWith(borderColor: color)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterTile({
    required String label,
    required int value,
    required VoidCallback? onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              Text(
                '$value',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ${value.toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildColorStrip({
    required Color selectedColor,
    required List<Color> colors,
    required ValueChanged<Color> onColorSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors
          .map(
            (color) => InkWell(
              onTap: () => onColorSelected(color),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.a == 0 ? Colors.white : color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor.toARGB32() == color.toARGB32()
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black12,
                    width: selectedColor.toARGB32() == color.toARGB32() ? 3 : 1,
                  ),
                ),
                child: color.a == 0
                    ? const Icon(Icons.block_rounded, size: 16, color: Colors.black54)
                    : null,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildExportOverlay() {
    return Container(
      color: Colors.black45,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text(
                  'Exporting styled PDF...',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addPage() {
    final nextPage = TextPdfPage(
      id: _uuid.v4(),
      preset: _currentPage.preset,
      backgroundColor: _currentPage.backgroundColor,
      elements: const <TextPdfElement>[],
    );
    setState(() {
      final updatedPages = <TextPdfPage>[..._document.pages, nextPage];
      _document = _document.copyWith(pages: updatedPages);
      _currentPageIndex = updatedPages.length - 1;
      _selectedElementId = null;
    });
  }

  void _addTextBlock() {
    _appendElement(
      TextPdfTextBlock(
        id: _uuid.v4(),
        left: 44,
        top: 48,
        width: 260,
        height: 120,
        text: 'Start typing here. Drag this box anywhere on the page.',
        fillColor: Colors.transparent,
        textColor: const Color(0xFF1C1917),
      ),
    );
  }

  Future<void> _pickAndAddImageBlock() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
    );
    final imagePath = result?.files.single.path;
    if (imagePath == null) {
      return;
    }
    _appendElement(
      TextPdfImageBlock(
        id: _uuid.v4(),
        left: 44,
        top: 120,
        width: 240,
        height: 180,
        imagePath: imagePath,
        fit: TextPdfImageFit.cover,
        borderRadius: 0,
        zoom: 1,
      ),
    );
  }

  void _addTableBlock() {
    _appendElement(
      TextPdfTableBlock(
        id: _uuid.v4(),
        left: 44,
        top: 220,
        width: 420,
        height: 180,
        rows: 3,
        columns: 3,
        cells: List<TextPdfTableCell>.generate(
          9,
          (index) => const TextPdfTableCell(text: ''),
        ),
        borderWidth: 0,
      ),
    );
  }

  void _appendElement(TextPdfElement element) {
    final updatedPage = _currentPage.copyWith(
      elements: <TextPdfElement>[..._currentPage.elements, element],
    );
    setState(() {
      _replaceCurrentPage(updatedPage);
      _selectedElementId = element.id;
    });
  }

  void _moveElement(TextPdfElement element, Offset delta, double scale) {
    final nextLeft = (element.left + (delta.dx / scale))
        .clamp(0.0, _currentPage.pageWidth - element.width);
    final nextTop = (element.top + (delta.dy / scale))
        .clamp(0.0, _currentPage.pageHeight - element.height);

    if (element is TextPdfTextBlock) {
      _updateSelectedTextBlock(element.copyWith(left: nextLeft, top: nextTop));
      return;
    }
    if (element is TextPdfImageBlock) {
      _updateSelectedImageBlock(element.copyWith(left: nextLeft, top: nextTop));
      return;
    }
    _updateSelectedTableBlock(
      (element as TextPdfTableBlock).copyWith(left: nextLeft, top: nextTop),
    );
  }

  void _dragImageCrop(TextPdfImageBlock block, Offset delta, double scale) {
    final nextFocusX = (block.focusX - (delta.dx / (block.width * scale))).clamp(0.0, 1.0);
    final nextFocusY = (block.focusY - (delta.dy / (block.height * scale))).clamp(0.0, 1.0);
    _updateSelectedImageBlock(
      block.copyWith(
        focusX: nextFocusX,
        focusY: nextFocusY,
      ),
    );
  }

  void _duplicateSelectedElement() {
    final selected = _selectedElement;
    if (selected == null) {
      return;
    }

    if (selected is TextPdfTextBlock) {
      _appendElement(
        TextPdfTextBlock(
          id: _uuid.v4(),
          left: math.min(
            selected.left + 24,
            _currentPage.pageWidth - selected.width,
          ),
          top: math.min(
            selected.top + 24,
            _currentPage.pageHeight - selected.height,
          ),
          width: selected.width,
          height: selected.height,
          text: selected.text,
          fontSize: selected.fontSize,
          textColor: selected.textColor,
          fillColor: selected.fillColor,
          bold: selected.bold,
          italic: selected.italic,
          underline: selected.underline,
          strikethrough: selected.strikethrough,
          alignment: selected.alignment,
          fontFamily: selected.fontFamily,
          textEffect: selected.textEffect,
          padding: selected.padding,
          lineSpacing: selected.lineSpacing,
          letterSpacing: selected.letterSpacing,
          boxBorderColor: selected.boxBorderColor,
          boxBorderWidth: selected.boxBorderWidth,
          cornerRadius: selected.cornerRadius,
          textBorderColor: selected.textBorderColor,
          textBorderWidth: selected.textBorderWidth,
          shadowColor: selected.shadowColor,
          shadowOffsetX: selected.shadowOffsetX,
          shadowOffsetY: selected.shadowOffsetY,
        ),
      );
      return;
    }

    if (selected is TextPdfImageBlock) {
      _appendElement(
        TextPdfImageBlock(
          id: _uuid.v4(),
          left: math.min(selected.left + 24, _currentPage.pageWidth - selected.width),
          top: math.min(selected.top + 24, _currentPage.pageHeight - selected.height),
          width: selected.width,
          height: selected.height,
          imagePath: selected.imagePath,
          fit: selected.fit,
          filter: selected.filter,
          opacity: selected.opacity,
          borderRadius: selected.borderRadius,
          borderColor: selected.borderColor,
          borderWidth: selected.borderWidth,
          zoom: selected.zoom,
          focusX: selected.focusX,
          focusY: selected.focusY,
        ),
      );
      return;
    }

    final table = selected as TextPdfTableBlock;
    _appendElement(
      TextPdfTableBlock(
        id: _uuid.v4(),
        left: math.min(table.left + 24, _currentPage.pageWidth - table.width),
        top: math.min(table.top + 24, _currentPage.pageHeight - table.height),
        width: table.width,
        height: table.height,
        rows: table.rows,
        columns: table.columns,
        cells: table.cells,
        fontSize: table.fontSize,
        textColor: table.textColor,
        borderColor: table.borderColor,
        headerFillColor: table.headerFillColor,
        cellFillColor: table.cellFillColor,
        borderWidth: table.borderWidth,
        cornerRadius: table.cornerRadius,
      ),
    );
  }

  void _removeSelectedElement() {
    final selectedId = _selectedElementId;
    if (selectedId == null) {
      return;
    }
    setState(() {
      _replaceCurrentPage(
        _currentPage.copyWith(
          elements: _currentPage.elements
              .where((element) => element.id != selectedId)
              .toList(growable: false),
        ),
      );
      _selectedElementId = null;
    });
  }

  void _updateSelectedTextBlock(TextPdfTextBlock updatedBlock) {
    setState(() {
      _replaceCurrentPage(
        _currentPage.copyWith(
          elements: _currentPage.elements.map((element) {
            return element.id == updatedBlock.id ? updatedBlock : element;
          }).toList(growable: false),
        ),
      );
    });
  }

  void _updateSelectedTableBlock(TextPdfTableBlock updatedTable) {
    setState(() {
      _replaceCurrentPage(
        _currentPage.copyWith(
          elements: _currentPage.elements.map((element) {
            return element.id == updatedTable.id ? updatedTable : element;
          }).toList(growable: false),
        ),
      );
    });
  }

  void _updateSelectedImageBlock(TextPdfImageBlock updatedBlock) {
    setState(() {
      _replaceCurrentPage(
        _currentPage.copyWith(
          elements: _currentPage.elements.map((element) {
            return element.id == updatedBlock.id ? updatedBlock : element;
          }).toList(growable: false),
        ),
      );
    });
  }

  void _updateCurrentPage(TextPdfPage page) {
    setState(() {
      _replaceCurrentPage(page);
    });
  }

  void _replaceCurrentPage(TextPdfPage page) {
    final updatedPages = <TextPdfPage>[..._document.pages];
    updatedPages[_currentPageIndex] = page;
    _document = _document.copyWith(pages: updatedPages);
  }

  Future<void> _editTableCells(TextPdfTableBlock table) async {
    final controllers = table.cells
        .map((cell) => TextEditingController(text: cell.text))
        .toList(growable: false);

    final updatedCells = await showModalBottomSheet<List<TextPdfTableCell>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Table Cells',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: controllers.length,
                    itemBuilder: (context, index) {
                      final row = (index ~/ table.columns) + 1;
                      final column = (index % table.columns) + 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: controllers[index],
                          decoration: InputDecoration(
                            labelText: 'R$row C$column',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(
                        sheetContext,
                        List<TextPdfTableCell>.generate(
                          controllers.length,
                          (index) => table.cells[index].copyWith(
                            text: controllers[index].text,
                          ),
                        ),
                      );
                    },
                    child: const Text('Apply Table Text'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    for (final controller in controllers) {
      controller.dispose();
    }

    if (updatedCells != null) {
      _updateSelectedTableBlock(table.copyWith(cells: updatedCells));
    }
  }

  void _resizeTable(
    TextPdfTableBlock table, {
    required int rows,
    required int columns,
  }) {
    final nextCount = rows * columns;
    final nextCells = List<TextPdfTableCell>.generate(nextCount, (index) {
      if (index < table.cells.length) {
        return table.cells[index];
      }
      return TextPdfTableCell(
        text: index < columns ? 'Header ${index + 1}' : 'Cell ${index - columns + 1}',
      );
    });

    _updateSelectedTableBlock(
      table.copyWith(rows: rows, columns: columns, cells: nextCells),
    );
  }

  void _applyCellFill(TextPdfTableBlock table, Color color) {
    _updateSelectedTableBlock(
      table.copyWith(
        cells: table.cells
            .map((cell) => cell.copyWith(backgroundColor: color))
            .toList(growable: false),
        cellFillColor: color,
      ),
    );
  }

  Future<void> _replaceImageBlock(TextPdfImageBlock block) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    final imagePath = result?.files.single.path;
    if (imagePath == null) {
      return;
    }
    _updateSelectedImageBlock(block.copyWith(imagePath: imagePath));
  }

  Future<void> _exportDocument() async {
    setState(() {
      _isExporting = true;
    });
    try {
      final result = await _toolkitService.exportStyledDocumentToPdf(
        _document.copyWith(
          title: _titleController.text.trim().isEmpty
              ? 'Styled Note'
              : _titleController.text.trim(),
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'The styled text document could not be exported to PDF.',
        behavior: SnackBarBehavior.floating,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  String _fontFamilyLabel(TextPdfFontFamily fontFamily) {
    return switch (fontFamily) {
      TextPdfFontFamily.sans => 'Sans',
      TextPdfFontFamily.serif => 'Serif',
      TextPdfFontFamily.mono => 'Mono',
      TextPdfFontFamily.display => 'Display',
    };
  }

  String _textEffectLabel(TextPdfTextEffect effect) {
    return switch (effect) {
      TextPdfTextEffect.none => 'Normal',
      TextPdfTextEffect.shadow => 'Shadow',
      TextPdfTextEffect.outline => 'Border',
      TextPdfTextEffect.raised3d => '3D',
    };
  }

  String? _flutterFontFamily(TextPdfFontFamily fontFamily) {
    return switch (fontFamily) {
      TextPdfFontFamily.sans => null,
      TextPdfFontFamily.serif => 'serif',
      TextPdfFontFamily.mono => 'monospace',
      TextPdfFontFamily.display => 'Sora',
    };
  }

  TextDecoration _textDecoration(TextPdfTextBlock block) {
    final decorations = <TextDecoration>[];
    if (block.underline) {
      decorations.add(TextDecoration.underline);
    }
    if (block.strikethrough) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) {
      return TextDecoration.none;
    }
    return TextDecoration.combine(decorations);
  }

  TextAlign _toFlutterTextAlign(TextPdfAlignment alignment) {
    switch (alignment) {
      case TextPdfAlignment.center:
        return TextAlign.center;
      case TextPdfAlignment.right:
        return TextAlign.right;
      case TextPdfAlignment.justify:
        return TextAlign.justify;
      case TextPdfAlignment.left:
        return TextAlign.left;
    }
  }
}
