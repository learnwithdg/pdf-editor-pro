import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';

class OutputLibraryScreen extends StatefulWidget {
  const OutputLibraryScreen({super.key});

  @override
  State<OutputLibraryScreen> createState() => _OutputLibraryScreenState();
}

class _OutputLibraryScreenState extends State<OutputLibraryScreen> {
  final PdfToolkitService _toolkitService = PdfToolkitService();
  final TextEditingController _searchController = TextEditingController();
  List<ToolkitOutputFile> _outputs = <ToolkitOutputFile>[];
  _OutputFilter _filter = _OutputFilter.all;
  String _query = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    AdsService().warmUpPremiumAds();
    unawaited(_loadOutputs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOutputs() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final outputs = await _toolkitService.listToolkitOutputs();
      if (!mounted) {
        return;
      }
      setState(() {
        _outputs = outputs;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
      AppFeedback.showError(
        context,
        error,
        fallback: 'Output library could not be loaded.',
      );
    }
  }

  List<ToolkitOutputFile> get _filteredOutputs {
    final cleanQuery = _query.trim().toLowerCase();
    return _outputs.where((output) {
      final matchesFilter = switch (_filter) {
        _OutputFilter.all => true,
        _OutputFilter.pdfs => output.isPdf,
        _OutputFilter.images => output.isImage,
        _OutputFilter.reports => output.isReport,
      };
      final matchesQuery = cleanQuery.isEmpty ||
          output.fileName.toLowerCase().contains(cleanQuery) ||
          output.toolLabel.toLowerCase().contains(cleanQuery);
      return matchesFilter && matchesQuery;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOutputs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Output Library'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadOutputs,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadOutputs,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate(
                        [
                          _buildHero(context),
                          const SizedBox(height: 16),
                          _buildSearchAndFilters(context),
                          const SizedBox(height: 16),
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.only(top: 60),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else if (filtered.isEmpty)
                            _buildEmptyState(context)
                          else
                            ..._buildOutputCards(context, filtered),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SmartBannerAd(),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final pdfCount = _outputs.where((output) => output.isPdf).length;
    final imageCount = _outputs.where((output) => output.isImage).length;
    final reportCount = _outputs.where((output) => output.isReport).length;
    final totalSize = _outputs.fold<int>(0, (sum, output) => sum + output.sizeBytes);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF15313B), Color(0xFF0D1D23)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_special_rounded, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'OUTPUT VAULT',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'All generated files in one polished workspace.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.12,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse PDFs, JPG exports, OCR reports, backups, and generated documents without hunting through folders.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.76), height: 1.4),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatChip(label: 'PDFs', value: '$pdfCount'),
              _StatChip(label: 'Images', value: '$imageCount'),
              _StatChip(label: 'Reports', value: '$reportCount'),
              _StatChip(label: 'Storage', value: _formatBytes(totalSize)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search generated files...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _OutputFilter.values.map((filter) {
                final selected = filter == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = filter),
                    label: Text(filter.label),
                    avatar: Icon(filter.icon, size: 18),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOutputCards(BuildContext context, List<ToolkitOutputFile> outputs) {
    final widgets = <Widget>[];
    for (var index = 0; index < outputs.length; index++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _OutputCard(
            output: outputs[index],
            onOpen: () => _openOutput(outputs[index]),
            onShare: () => _shareOutput(outputs[index]),
            onDelete: () => _confirmDelete(outputs[index]),
          ),
        ),
      );
      if ((index + 1) % 4 == 0 && index != outputs.length - 1) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: SmartNativeAd(isSmall: true),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: theme.colorScheme.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No outputs yet',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the PDF Tool Suite to create PDFs, export images, run OCR, or generate reports. They will appear here automatically.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _openOutput(ToolkitOutputFile output) {
    AdsService().registerToolLaunch();
    if (output.isPdf) {
      context.read<PdfBloc>().add(LoadPdfEvent(output.path));
      Navigator.pop(context);
      return;
    }
    if (output.isReport) {
      unawaited(_previewReport(output));
      return;
    }
    unawaited(_shareOutput(output));
  }

  Future<void> _previewReport(ToolkitOutputFile output) async {
    try {
      final text = await File(output.path).readAsString();
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    output.fileName,
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.58,
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        text,
                        style: const TextStyle(fontFamily: 'monospace', height: 1.35),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        unawaited(_shareOutput(output));
                      },
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Report'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'This report could not be opened.',
      );
    }
  }

  Future<void> _shareOutput(ToolkitOutputFile output) async {
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(output.path)]),
    );
  }

  Future<void> _confirmDelete(ToolkitOutputFile output) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete output?'),
        content: Text('Remove "${output.fileName}" from the app output library?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) {
      return;
    }

    try {
      await _toolkitService.deleteToolkitOutput(output.path);
      await _loadOutputs();
      if (mounted) {
        AppFeedback.showSuccess(context, 'Output removed from the library.');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'This output could not be deleted.',
      );
    }
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
}

class _OutputCard extends StatelessWidget {
  const _OutputCard({
    required this.output,
    required this.onOpen,
    required this.onShare,
    required this.onDelete,
  });

  final ToolkitOutputFile output;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = output.isPdf
        ? theme.colorScheme.primary
        : output.isImage
            ? const Color(0xFF3F8C8D)
            : const Color(0xFFB18345);
    final icon = output.isPdf
        ? Icons.picture_as_pdf_rounded
        : output.isImage
            ? Icons.image_rounded
            : Icons.article_outlined;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.22),
                  accent.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      output.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${output.toolLabel} | ${_formatCardBytes(output.sizeBytes)} | ${DateFormat('dd MMM, hh:mm a').format(output.modifiedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  static String _formatCardBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(kb >= 10 ? 1 : 2)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 10 ? 1 : 2)} MB';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

enum _OutputFilter {
  all('All', Icons.dashboard_customize_rounded),
  pdfs('PDFs', Icons.picture_as_pdf_rounded),
  images('Images', Icons.image_rounded),
  reports('Reports', Icons.article_outlined);

  const _OutputFilter(this.label, this.icon);

  final String label;
  final IconData icon;
}
