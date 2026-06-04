import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../blocs/pdf_state.dart';
import '../models/pdf_document.dart';

class EditorToolbar extends StatelessWidget {
  const EditorToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PdfBloc, PdfState>(
      builder: (context, state) {
        if (state is! PdfLoaded || !state.isEditMode) {
          return const SizedBox.shrink();
        }

        final pageAnnotations = state.document.annotations
            .where((annotation) => annotation.pageIndex == state.currentPage)
            .toList(growable: false);
        final lastAnnotation = pageAnnotations.isEmpty ? null : pageAnnotations.last;

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Markup Tools',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Pick color',
                      onPressed: () => _showColorPicker(context),
                      icon: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: state.selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Undo last mark',
                      onPressed: lastAnnotation == null
                          ? null
                          : () => context.read<PdfBloc>().add(RemoveAnnotationEvent(lastAnnotation.id)),
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => context.read<PdfBloc>().add(const SavePdfEvent()),
                      icon: const Icon(Icons.save_alt_rounded),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ToolIcon(
                      icon: Icons.pan_tool_outlined,
                      activeIcon: Icons.pan_tool_rounded,
                      label: 'Pan',
                      isActive: state.selectedTool == ToolType.none,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.none)),
                    ),
                    _buildDivider(),
                    _ToolIcon(
                      icon: Icons.border_color_outlined,
                      activeIcon: Icons.border_color_rounded,
                      label: 'Pen',
                      isActive: state.selectedTool == ToolType.pen,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.pen)),
                    ),
                    _ToolIcon(
                      icon: Icons.highlight_alt_outlined,
                      activeIcon: Icons.highlight_alt_rounded,
                      label: 'Highlight',
                      isActive: state.selectedTool == ToolType.highlight,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.highlight)),
                    ),
                    _ToolIcon(
                      icon: Icons.format_underline_outlined,
                      activeIcon: Icons.format_underline_rounded,
                      label: 'Underline',
                      isActive: state.selectedTool == ToolType.underline,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.underline)),
                    ),
                    _ToolIcon(
                      icon: Icons.format_strikethrough_outlined,
                      activeIcon: Icons.format_strikethrough_rounded,
                      label: 'Strike',
                      isActive: state.selectedTool == ToolType.strikethrough,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.strikethrough)),
                    ),
                    _ToolIcon(
                      icon: Icons.text_fields_outlined,
                      activeIcon: Icons.text_fields_rounded,
                      label: 'Text',
                      isActive: state.selectedTool == ToolType.text,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.text)),
                    ),
                    _ToolIcon(
                      icon: Icons.add_photo_alternate_outlined,
                      activeIcon: Icons.add_photo_alternate_rounded,
                      label: 'Image',
                      isActive: state.selectedTool == ToolType.image,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.image)),
                    ),
                    _ToolIcon(
                      icon: Icons.table_rows_outlined,
                      activeIcon: Icons.table_rows_rounded,
                      label: 'Table',
                      isActive: state.selectedTool == ToolType.table,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.table)),
                    ),
                    _ShapePicker(activeTool: state.selectedTool, activeShape: state.selectedShape),
                    _ToolIcon(
                      icon: Icons.draw_outlined,
                      activeIcon: Icons.draw_rounded,
                      label: 'Sign',
                      isActive: state.selectedTool == ToolType.signature,
                      onTap: () => context.read<PdfBloc>().add(const SelectToolEvent(ToolType.signature)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDivider() => const SizedBox(width: 8);

  void _showColorPicker(BuildContext context) {
    final colors = <Color>[
      const Color(0xFFFFEB3B),
      const Color(0xFF0E6B5C),
      const Color(0xFF1976D2),
      const Color(0xFFD32F2F),
      const Color(0xFFFF9800),
      const Color(0xFF8E24AA),
      Colors.black,
      Colors.white,
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors
                  .map(
                    (color) => GestureDetector(
                      onTap: () {
                        context.read<PdfBloc>().add(ChangeColorEvent(color));
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        );
      },
    );
  }
}

class _ShapePicker extends StatelessWidget {
  const _ShapePicker({
    required this.activeTool,
    required this.activeShape,
  });

  final ToolType activeTool;
  final ShapeType activeShape;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Shape tools',
      icon: Icon(activeTool == ToolType.shape ? _activeShapeIcon(activeShape) : Icons.interests_outlined),
      color: activeTool == ToolType.shape ? Theme.of(context).colorScheme.primary : null,
      onPressed: () => _showShapeSheet(context),
    );
  }

  IconData _activeShapeIcon(ShapeType type) {
    switch (type) {
      case ShapeType.line:
        return Icons.show_chart_rounded;
      case ShapeType.arrow:
        return Icons.arrow_right_alt_rounded;
      case ShapeType.rectangle:
        return Icons.crop_square_rounded;
      case ShapeType.circle:
        return Icons.circle_outlined;
    }
  }

  void _showShapeSheet(BuildContext context) {
    final options = <({IconData icon, String label, ShapeType shape})>[
      (icon: Icons.show_chart_rounded, label: 'Line', shape: ShapeType.line),
      (icon: Icons.arrow_right_alt_rounded, label: 'Arrow', shape: ShapeType.arrow),
      (icon: Icons.crop_square_rounded, label: 'Rectangle', shape: ShapeType.rectangle),
      (icon: Icons.circle_outlined, label: 'Circle', shape: ShapeType.circle),
    ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Choose Shape', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              ...options.map(
                (option) => ListTile(
                  leading: Icon(option.icon),
                  title: Text(option.label),
                  onTap: () {
                    context.read<PdfBloc>().add(
                          SelectToolEvent(ToolType.shape, shapeType: option.shape),
                        );
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: label,
      icon: Icon(isActive ? activeIcon : icon),
      onPressed: onTap,
      color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
      ),
    );
  }
}
