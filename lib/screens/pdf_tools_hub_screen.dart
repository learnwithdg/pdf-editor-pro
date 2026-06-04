import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';
import 'pdf_to_image_studio_screen.dart';
import 'text_to_pdf_studio_screen.dart';

class PdfToolsHubScreen extends StatefulWidget {
  const PdfToolsHubScreen({super.key});

  @override
  State<PdfToolsHubScreen> createState() => _PdfToolsHubScreenState();
}

class _PdfToolsHubScreenState extends State<PdfToolsHubScreen> {
  final PdfToolkitService _toolkitService = PdfToolkitService();
  final List<PdfToolkitResult> _results = <PdfToolkitResult>[];

  bool _isBusy = false;
  bool _isAdGateRunning = false;
  String? _activeToolLabel;
  _ToolSuiteCategory _selectedCategory = _ToolSuiteCategory.all;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    AdsService().warmUpPremiumAds();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'PDF Tool Suite',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              if (_isBusy)
                SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    backgroundColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.1),
                  ),
                ),
              SliverToBoxAdapter(child: _buildHeroCard(context)),
              SliverToBoxAdapter(child: _buildWorkflowBar(context)),
              SliverToBoxAdapter(child: _buildCategoryTabs(context)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _buildCategoryContent(context),
                    ),
                    if (_results.isNotEmpty) ...[
                      const SizedBox(height: 32),
                      _buildSectionHeader(
                        context,
                        'Recent Outputs',
                        'Your latest generated files are ready below.',
                      ),
                      ..._results.map(
                        (result) => _ResultCard(
                          result: result,
                          onShare: () => _shareResult(result),
                          onOpen: result.hasSinglePdfOutput
                              ? () =>
                                    _openGeneratedPdf(result.outputPaths.first)
                              : null,
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          if (_isBusy)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _activeToolLabel ?? 'Processing...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const SmartBannerAd(),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF1D3F4D), Color(0xFF0D2027)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.18),
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
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tune_rounded, color: Colors.amberAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'SMART PDF SUITE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Icon(
              Icons.auto_fix_high_rounded,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 14),
            const Text(
              'Premium tools to create, edit, and deliver PDFs beautifully.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Run conversions, organize pages, secure documents, and keep every output mobile-ready.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: const Row(
          children: [
            Expanded(
              child: _WorkflowChip(
                icon: Icons.draw_rounded,
                title: 'Create',
                subtitle: 'Text, images, office',
              ),
            ),
            Expanded(
              child: _WorkflowChip(
                icon: Icons.layers_rounded,
                title: 'Organize',
                subtitle: 'Split, merge, rotate',
              ),
            ),
            Expanded(
              child: _WorkflowChip(
                icon: Icons.shield_rounded,
                title: 'Protect',
                subtitle: 'Password, OCR, compress',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  List<_ToolData> get _createTools => <_ToolData>[
    _ToolData(
      Icons.image_outlined,
      'Image to PDF',
      'Turn photos and scanned snapshots into a polished PDF document.',
      const Color(0xFFD65A43),
      _handleImageToPdf,
      badge: 'Studio',
    ),
    _ToolData(
      Icons.photo_camera_rounded,
      'Camera Scan to PDF',
      'Capture pages with the camera and convert them into a ready PDF.',
      const Color(0xFFBC503C),
      _handleCameraScanToPdf,
      badge: 'Camera',
    ),
    _ToolData(
      Icons.photo_library_outlined,
      'PDF to Images',
      'Export only the pages you select and save them as sharp image files.',
      const Color(0xFFDB8A43),
      _handlePdfToImages,
      badge: 'Selectable',
    ),
    _ToolData(
      Icons.edit_note_rounded,
      'Text to PDF',
      'Build clean PDF pages from rich text blocks, titles, and notes.',
      const Color(0xFF3F8C8D),
      _handleTextToPdf,
      badge: 'Editor',
    ),
    _ToolData(
      Icons.description_outlined,
      'Office to PDF',
      'Convert Word, PowerPoint, Excel, and text files into PDFs.',
      const Color(0xFF4771D8),
      _handleOfficeConvert,
      badge: 'Convert',
    ),
    _ToolData(
      Icons.edit_rounded,
      'Open PDF Editor',
      'Open any PDF directly in the mobile editor for text, image, table, and signature work.',
      const Color(0xFF8A64D6),
      _handleOpenInEditor,
      badge: 'Edit',
    ),
  ];

  List<_ToolData> get _organizeTools => <_ToolData>[
    _ToolData(
      Icons.merge_type_rounded,
      'Merge PDFs',
      'Combine multiple PDF files into one clean share-ready document.',
      const Color(0xFFB14F6E),
      _handleMergePdfs,
      badge: 'Popular',
    ),
    _ToolData(
      Icons.content_cut_rounded,
      'Extract Pages',
      'Pick a page range and create a focused PDF from the selection.',
      const Color(0xFF6A7DE8),
      _handleExtractPages,
      badge: 'Range',
    ),
    _ToolData(
      Icons.call_split_rounded,
      'Split PDF',
      'Break a document into single-page PDFs for quick sharing.',
      const Color(0xFF4D8A8C),
      _handleSplitPdf,
      badge: 'Pages',
    ),
    _ToolData(
      Icons.view_carousel_rounded,
      'Reorder Pages',
      'Change document flow by rearranging pages in the order you want.',
      const Color(0xFF8B62D6),
      _handleReorderPages,
      badge: 'Arrange',
    ),
    _ToolData(
      Icons.screen_rotation_alt_rounded,
      'Rotate Pages',
      'Rotate chosen pages by 90, 180, or 270 degrees.',
      const Color(0xFF377A96),
      _handleRotatePages,
      badge: 'Fix Layout',
    ),
    _ToolData(
      Icons.copy_all_rounded,
      'Duplicate PDF',
      'Create a clean backup copy before editing, sharing, or protecting the file.',
      const Color(0xFF6C7A4C),
      _handleDuplicatePdf,
      badge: 'Backup',
    ),
    _ToolData(
      Icons.fit_screen_rounded,
      'Fit to A4',
      'Rebuild pages into a standard A4 layout for printing and office sharing.',
      const Color(0xFF4F7BA8),
      _handleFitToA4,
      badge: 'Print Ready',
    ),
  ];

  List<_ToolData> get _secureTools => <_ToolData>[
    _ToolData(
      Icons.branding_watermark_rounded,
      'Watermark PDF',
      'Stamp a document with custom text for review, draft, or branding.',
      const Color(0xFFB25148),
      _handleWatermarkPdf,
      badge: 'Brand',
    ),
    _ToolData(
      Icons.compress_rounded,
      'Compress PDF',
      'Reduce file size and keep documents easier to send and upload.',
      const Color(0xFF3B8A7E),
      _handleCompressPdf,
      badge: 'Optimize',
    ),
    _ToolData(
      Icons.layers_clear_rounded,
      'Flatten PDF',
      'Lock visual content into a simplified printable PDF version.',
      const Color(0xFF747F9F),
      _handleFlattenPdf,
      badge: 'Finalize',
    ),
    _ToolData(
      Icons.lock_outline_rounded,
      'Protect PDF',
      'Add a password so the document stays private and controlled.',
      const Color(0xFFB25C52),
      _handleProtectPdf,
      badge: 'Password',
    ),
    _ToolData(
      Icons.lock_open_rounded,
      'Unlock PDF',
      'Remove the password from a PDF you already have permission to use.',
      const Color(0xFFB18345),
      _handleUnlockPdf,
      badge: 'Access',
    ),
    _ToolData(
      Icons.document_scanner_outlined,
      'OCR PDF',
      'Read scanned PDFs and extract searchable text from page images.',
      const Color(0xFF4E79C9),
      _handleOcrPdf,
      badge: 'AI Read',
    ),
    _ToolData(
      Icons.confirmation_number_outlined,
      'Bates Numbering',
      'Apply sequential page numbering for legal and case workflows.',
      const Color(0xFF8A5C50),
      _handleBatesNumbering,
      badge: 'Legal',
    ),
    _ToolData(
      Icons.format_list_numbered_rounded,
      'Page Numbers',
      'Add simple footer page numbers across the full document.',
      const Color(0xFFAF6B38),
      _handlePageNumbers,
      badge: 'Footer',
    ),
    _ToolData(
      Icons.info_outline_rounded,
      'PDF Info Report',
      'Generate a quick report with page count, size, encryption, and file details.',
      const Color(0xFF4B83A8),
      _handlePdfInfoReport,
      badge: 'Report',
    ),
    _ToolData(
      Icons.print_rounded,
      'Print PDF',
      'Send a selected PDF to the device print/share printer flow.',
      const Color(0xFF65717D),
      _handlePrintPdf,
      badge: 'Output',
    ),
  ];

  Widget _buildCategoryTabs(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _ToolSuiteCategory.values
              .map((category) {
                final selected = category == _selectedCategory;
                final count = _toolCountForCategory(category);
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      gradient: selected
                          ? const LinearGradient(
                              colors: <Color>[
                                Color(0xFFCB5B45),
                                Color(0xFF8E2B30),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: selected
                          ? null
                          : theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : theme.colorScheme.outlineVariant,
                      ),
                      boxShadow: selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: const Color(
                                  0xFF8E2B30,
                                ).withValues(alpha: 0.22),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ]
                          : null,
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                category.icon,
                                color: selected
                                    ? Colors.white
                                    : theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$count tools',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white.withValues(alpha: 0.72)
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildCategoryContent(BuildContext context) {
    final sections = _sectionsForCategory();
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: ValueKey<_ToolSuiteCategory>(_selectedCategory),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[Color(0xFFCB5B45), Color(0xFF8E2B30)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _selectedCategory.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCategory.headline,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedCategory.description,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ToolCountBadge(
                      count: sections.fold<int>(
                        0,
                        (sum, section) => sum + section.tools.length,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 240.ms)
              .moveY(begin: 10, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 22),
          for (var index = 0; index < sections.length; index++) ...[
            Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      context,
                      sections[index].title,
                      sections[index].subtitle,
                    ),
                    _buildToolsGrid(context, sections[index].tools),
                  ],
                )
                .animate(delay: (60 * index).ms)
                .fadeIn(duration: 260.ms)
                .moveY(begin: 12, end: 0),
            if (index != sections.length - 1) const SizedBox(height: 28),
          ],
        ],
      ),
    );
  }

  List<_ToolSectionData> _sectionsForCategory() {
    return switch (_selectedCategory) {
      _ToolSuiteCategory.all => <_ToolSectionData>[
        _ToolSectionData(
          title: 'Create & Convert',
          subtitle:
              'Build polished PDFs from images, office files, and flexible text workflows.',
          tools: _createTools,
        ),
        _ToolSectionData(
          title: 'Organize & Arrange',
          subtitle:
              'Reshape document flow with page controls, extraction, and layout fixes.',
          tools: _organizeTools,
        ),
        _ToolSectionData(
          title: 'Protect & Finalize',
          subtitle:
              'Secure files, add review marks, optimize exports, and prepare final delivery.',
          tools: _secureTools,
        ),
      ],
      _ToolSuiteCategory.create => <_ToolSectionData>[
        _ToolSectionData(
          title: 'Creation Studio',
          subtitle:
              'Everything you need to build or convert fresh PDF outputs.',
          tools: _createTools,
        ),
      ],
      _ToolSuiteCategory.organize => <_ToolSectionData>[
        _ToolSectionData(
          title: 'Page Control',
          subtitle:
              'Clean document structure with merging, reordering, splitting, and rotation.',
          tools: _organizeTools,
        ),
      ],
      _ToolSuiteCategory.secure => <_ToolSectionData>[
        _ToolSectionData(
          title: 'Protection Stack',
          subtitle:
              'Lock, brand, optimize, and make scanned content more usable.',
          tools: _secureTools,
        ),
      ],
    };
  }

  int _toolCountForCategory(_ToolSuiteCategory category) {
    return switch (category) {
      _ToolSuiteCategory.all =>
        _createTools.length + _organizeTools.length + _secureTools.length,
      _ToolSuiteCategory.create => _createTools.length,
      _ToolSuiteCategory.organize => _organizeTools.length,
      _ToolSuiteCategory.secure => _secureTools.length,
    };
  }

  Widget _buildToolsGrid(BuildContext context, List<_ToolData> tools) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 980
            ? 3
            : width >= 640
            ? 2
            : 1;

        if (crossAxisCount == 1) {
          return Column(children: _buildMobileToolCardsWithAds(context, tools));
        }

        final childAspectRatio = width >= 980 ? 1.12 : 1.02;
        final chunks = _chunkTools(tools);

        return Column(
          children: List<Widget>.generate(
            chunks.length,
            (chunkIndex) => Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: chunks[chunkIndex].length,
                  itemBuilder: (context, index) {
                    final globalIndex = (chunkIndex * 3) + index;
                    return _buildToolGridCard(
                          context,
                          chunks[chunkIndex][index],
                        )
                        .animate(delay: (55 * globalIndex).ms)
                        .fadeIn(duration: 260.ms)
                        .moveY(begin: 10, end: 0);
                  },
                ),
                if (chunkIndex != chunks.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(top: 12, bottom: 16),
                    child: SmartNativeAd(isSmall: true),
                  ),
              ],
            ),
            growable: false,
          ),
        );
      },
    );
  }

  List<Widget> _buildMobileToolCardsWithAds(
    BuildContext context,
    List<_ToolData> tools,
  ) {
    final widgets = <Widget>[];
    for (var index = 0; index < tools.length; index++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildToolListCard(context, tools[index])
              .animate(delay: (55 * index).ms)
              .fadeIn(duration: 260.ms)
              .moveY(begin: 10, end: 0),
        ),
      );
      final shouldInsertAd = (index + 1) % 3 == 0 && index != tools.length - 1;
      if (shouldInsertAd) {
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

  List<List<_ToolData>> _chunkTools(List<_ToolData> tools) {
    final chunks = <List<_ToolData>>[];
    for (var start = 0; start < tools.length; start += 3) {
      final end = (start + 3) > tools.length ? tools.length : start + 3;
      chunks.add(tools.sublist(start, end));
    }
    return chunks;
  }

  Widget _buildToolGridCard(BuildContext context, _ToolData tool) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: _isBusy ? null : () => _launchTool(tool),
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          tool.color.withValues(alpha: 0.22),
                          tool.color.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 26),
                  ),
                  const Spacer(),
                  _ToolPill(label: tool.badge, color: tool.color),
                ],
              ),
              const Spacer(),
              Text(
                tool.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tool.subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Launch tool',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolListCard(BuildContext context, _ToolData tool) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _isBusy ? null : () => _launchTool(tool),
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(18),
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
                  colors: [
                    tool.color.withValues(alpha: 0.2),
                    tool.color.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(tool.icon, color: tool.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ToolPill(label: tool.badge, color: tool.color),
                  const SizedBox(height: 8),
                  Text(
                    tool.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tool.subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTool(_ToolData tool) async {
    if (_isBusy || _isAdGateRunning) {
      return;
    }

    setState(() {
      _isAdGateRunning = true;
    });

    try {
      await AdsService().showToolGateAds(context);
      if (!mounted) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await Future<void>.sync(tool.onTap);
    } finally {
      if (mounted) {
        setState(() {
          _isAdGateRunning = false;
        });
      }
    }
  }

  Future<void> _handleImageToPdf() async {
    final paths = await _toolkitService.pickImages();
    if (paths.isEmpty) {
      return;
    }
    await _runTool(
      'Creating PDF...',
      () => _toolkitService.createPdfFromImages(paths),
    );
  }

  Future<void> _handleCameraScanToPdf() async {
    final paths = <String>[];

    while (mounted) {
      final path = await _toolkitService.captureImageFromCamera();
      if (path == null) {
        break;
      }
      paths.add(path);
      if (!mounted) {
        return;
      }
      final captureMore = await _showCaptureAnotherPageSheet(paths.length);
      if (!captureMore) {
        break;
      }
    }

    if (paths.isEmpty) {
      return;
    }

    await _runTool(
      'Creating camera PDF...',
      () => _toolkitService.createPdfFromImages(paths),
    );
  }

  Future<void> _handlePdfToImages() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfToImageStudioScreen(pdfPath: path)),
    );
  }

  Future<void> _handleTextToPdf() async {
    final result = await Navigator.push<PdfToolkitResult>(
      context,
      MaterialPageRoute(builder: (_) => const TextToPdfStudioScreen()),
    );
    if (!mounted || result == null) {
      return;
    }
    setState(() {
      _results.insert(0, result);
    });
    AppFeedback.showSuccess(context, result.message);
  }

  Future<void> _handleOfficeConvert() async {
    final paths = await _toolkitService.pickOfficeFiles();
    if (paths.isEmpty) {
      return;
    }
    final path = paths.first;
    await _runTool(
      'Converting office file...',
      () => _toolkitService.convertOfficeToPdf(path, _officeLabelFor(path)),
    );
  }

  Future<void> _handleOpenInEditor() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.read<PdfBloc>().add(LoadPdfEvent(path));
    Navigator.pop(context);
  }

  Future<void> _handleMergePdfs() async {
    final paths = await _toolkitService.pickPdfs(allowMultiple: true);
    if (paths.length < 2) {
      return;
    }
    await _runTool('Merging PDFs...', () => _toolkitService.mergePdfs(paths));
  }

  Future<void> _handleExtractPages() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final info = await _toolkitService.inspectPdf(path);
    final range = await _showPageRangeSheet(info);
    if (range == null) {
      return;
    }
    await _runTool(
      'Extracting pages...',
      () => _toolkitService.extractPageRange(
        path,
        startPage: range.startPage,
        endPage: range.endPage,
      ),
    );
  }

  Future<void> _handleSplitPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool(
      'Splitting PDF...',
      () => _toolkitService.splitIntoSinglePagePdfs(path),
    );
  }

  Future<void> _handleReorderPages() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final info = await _toolkitService.inspectPdf(path);
    final order = await _showPageOrderSheet(info);
    if (order == null) {
      return;
    }
    await _runTool(
      'Reordering pages...',
      () => _toolkitService.reorderPdfPages(path, newOrder: order),
    );
  }

  Future<void> _handleRotatePages() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final info = await _toolkitService.inspectPdf(path);
    final config = await _showRotateSheet(info);
    if (config == null) {
      return;
    }
    await _runTool(
      'Rotating pages...',
      () => _toolkitService.rotatePdfPages(
        path,
        pageNumbers: config.pages,
        quarterTurns: config.quarterTurns,
      ),
    );
  }

  Future<void> _handleDuplicatePdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool(
      'Duplicating PDF...',
      () => _toolkitService.duplicatePdf(path),
    );
  }

  Future<void> _handleFitToA4() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool(
      'Fitting pages to A4...',
      () => _toolkitService.fitPdfToA4(path),
    );
  }

  Future<void> _handleWatermarkPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final watermark = await _showTextInputSheet(
      title: 'Watermark PDF',
      label: 'Watermark text',
      hintText: 'CONFIDENTIAL',
      submitLabel: 'Apply Watermark',
    );
    if (watermark == null || watermark.isEmpty) {
      return;
    }
    await _runTool(
      'Applying watermark...',
      () => _toolkitService.watermarkPdf(path, watermarkText: watermark),
    );
  }

  Future<void> _handleCompressPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool(
      'Compressing PDF...',
      () => _toolkitService.compressPdf(path),
    );
  }

  Future<void> _handleFlattenPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool('Flattening PDF...', () => _toolkitService.flattenPdf(path));
  }

  Future<void> _handleProtectPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final password = await _showTextInputSheet(
      title: 'Protect PDF',
      label: 'Password',
      hintText: 'Enter password',
      submitLabel: 'Protect PDF',
      obscureText: true,
    );
    if (password == null || password.isEmpty) {
      return;
    }
    await _runTool(
      'Protecting PDF...',
      () => _toolkitService.protectPdf(path, password),
    );
  }

  Future<void> _handleUnlockPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final password = await _showTextInputSheet(
      title: 'Unlock PDF',
      label: 'Password',
      hintText: 'Enter current password',
      submitLabel: 'Unlock PDF',
      obscureText: true,
    );
    if (password == null || password.isEmpty) {
      return;
    }
    await _runTool(
      'Unlocking PDF...',
      () => _toolkitService.unlockPdfWithPassword(path, password: password),
    );
  }

  Future<void> _handleOcrPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final script = await _showOcrScriptSheet();
    if (script == null) {
      return;
    }
    await _runTool(
      'Running OCR...',
      () => _toolkitService.ocrPdf(path, script: script),
    );
  }

  Future<void> _handleBatesNumbering() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final prefix = await _showTextInputSheet(
      title: 'Bates Numbering',
      label: 'Prefix',
      hintText: 'CASE-2026',
      submitLabel: 'Apply Numbering',
    );
    if (prefix == null || prefix.isEmpty) {
      return;
    }
    await _runTool(
      'Applying numbering...',
      () => _toolkitService.applyBatesNumbering(path, prefix: prefix),
    );
  }

  Future<void> _handlePageNumbers() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    final prefix = await _showTextInputSheet(
      title: 'Page Numbers',
      label: 'Optional prefix',
      hintText: 'Page',
      submitLabel: 'Add Page Numbers',
    );
    if (prefix == null) {
      return;
    }
    await _runTool(
      'Adding page numbers...',
      () => _toolkitService.addPageNumbers(path, prefix: prefix),
    );
  }

  Future<void> _handlePdfInfoReport() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    await _runTool(
      'Building PDF info report...',
      () => _toolkitService.createPdfInfoReport(path),
    );
  }

  Future<void> _handlePrintPdf() async {
    final path = await _pickSinglePdf();
    if (path == null) {
      return;
    }
    setState(() {
      _isBusy = true;
      _activeToolLabel = 'Opening print flow...';
    });
    try {
      await _toolkitService.printPdf(path);
      if (mounted) {
        AppFeedback.showSuccess(
          context,
          'Print flow opened for the selected PDF.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'The print flow could not open for this PDF.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _activeToolLabel = null;
        });
      }
    }
  }

  Future<bool> _showCaptureAnotherPageSheet(int pageCount) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.document_scanner_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$pageCount camera page${pageCount == 1 ? '' : 's'} captured',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Capture another page or create the PDF now. You can merge more pages later from the toolkit too.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.add_a_photo_rounded),
                        label: const Text('Add Page'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Create PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _pickSinglePdf() async {
    final paths = await _toolkitService.pickPdfs();
    return paths.isEmpty ? null : paths.first;
  }

  Future<void> _runTool(
    String label,
    Future<PdfToolkitResult> Function() action,
  ) async {
    setState(() {
      _isBusy = true;
      _activeToolLabel = label;
    });
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _results.insert(0, result);
      });
      AppFeedback.showSuccess(context, result.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'This PDF tool could not finish the requested action.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _activeToolLabel = null;
        });
      }
    }
  }

  Future<String?> _showTextInputSheet({
    required String title,
    required String label,
    required String hintText,
    required String submitLabel,
    bool obscureText = false,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscureText,
                maxLines: maxLines,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hintText,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, controller.text.trim()),
                  child: Text(submitLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<_PageRangeInput?> _showPageRangeSheet(PdfDocumentInfo info) async {
    final startController = TextEditingController(text: '1');
    final endController = TextEditingController(
      text: info.pageCount.toString(),
    );
    final result = await showModalBottomSheet<_PageRangeInput>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Extract Pages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Document: ${info.fileName} (${info.pageCount} pages)'),
              const SizedBox(height: 16),
              TextField(
                controller: startController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Start page',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: endController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'End page',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final startPage = int.tryParse(startController.text.trim());
                    final endPage = int.tryParse(endController.text.trim());
                    if (startPage == null || endPage == null) {
                      return;
                    }
                    Navigator.pop(
                      sheetContext,
                      _PageRangeInput(startPage: startPage, endPage: endPage),
                    );
                  },
                  child: const Text('Extract Pages'),
                ),
              ),
            ],
          ),
        );
      },
    );
    startController.dispose();
    endController.dispose();
    return result;
  }

  Future<List<int>?> _showPageOrderSheet(PdfDocumentInfo info) async {
    final initialOrder = List<int>.generate(
      info.pageCount,
      (index) => index + 1,
    ).join(',');
    final controller = TextEditingController(text: initialOrder);
    final result = await showModalBottomSheet<List<int>>(
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reorder Pages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('Enter all page numbers once. Example: $initialOrder'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Page order',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final order = _parsePageList(controller.text);
                    Navigator.pop(sheetContext, order);
                  },
                  child: const Text('Apply Order'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();

    if (result == null || !_isFullPageOrder(result, info.pageCount)) {
      return null;
    }
    return result;
  }

  Future<_RotateInput?> _showRotateSheet(PdfDocumentInfo info) async {
    final pagesController = TextEditingController();
    var quarterTurns = 1;
    final result = await showModalBottomSheet<_RotateInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rotate Pages',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Leave pages empty to rotate all ${info.pageCount} pages.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pagesController,
                    decoration: const InputDecoration(
                      labelText: 'Pages (optional)',
                      hintText: '1,3,5',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    segments: const <ButtonSegment<int>>[
                      ButtonSegment(value: 1, label: Text('90°')),
                      ButtonSegment(value: 2, label: Text('180°')),
                      ButtonSegment(value: 3, label: Text('270°')),
                    ],
                    selected: <int>{quarterTurns},
                    onSelectionChanged: (selection) {
                      setSheetState(() {
                        quarterTurns = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          sheetContext,
                          _RotateInput(
                            pages: _parsePageList(pagesController.text),
                            quarterTurns: quarterTurns,
                          ),
                        );
                      },
                      child: const Text('Rotate PDF'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    pagesController.dispose();
    return result;
  }

  Future<PdfOcrScript?> _showOcrScriptSheet() async {
    var selected = PdfOcrScript.latin;
    return showModalBottomSheet<PdfOcrScript>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return RadioGroup<PdfOcrScript>(
              groupValue: selected,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setSheetState(() {
                  selected = value;
                });
              },
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'OCR Language',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          'Choose the script that best matches the scanned PDF',
                        ),
                      ),
                      ...PdfOcrScript.values.map(
                        (script) => RadioListTile<PdfOcrScript>(
                          value: script,
                          title: Text(script.label),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, selected),
                          child: const Text('Run OCR'),
                        ),
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

  List<int> _parsePageList(String input) {
    return input
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  bool _isFullPageOrder(List<int> order, int pageCount) {
    final expected = List<int>.generate(
      pageCount,
      (index) => index + 1,
    ).toSet();
    return order.length == pageCount && order.toSet().containsAll(expected);
  }

  String _officeLabelFor(String path) {
    switch (p.extension(path).toLowerCase()) {
      case '.docx':
        return 'Word';
      case '.pptx':
        return 'PowerPoint';
      case '.xlsx':
        return 'Excel';
      case '.txt':
        return 'Text';
      default:
        return 'Office';
    }
  }

  Future<void> _shareResult(PdfToolkitResult result) async {
    await SharePlus.instance.share(
      ShareParams(
        files: result.outputPaths
            .map((path) => XFile(path))
            .toList(growable: false),
      ),
    );
  }

  void _openGeneratedPdf(String path) {
    context.read<PdfBloc>().add(LoadPdfEvent(path));
    Navigator.pop(context);
  }
}

enum _ToolSuiteCategory {
  all(
    label: 'All Tools',
    headline: 'Everything in one premium document suite.',
    description:
        'Browse the full toolkit and move between creation, organization, and final delivery workflows.',
    icon: Icons.dashboard_customize_rounded,
  ),
  create(
    label: 'Create',
    headline: 'Create polished PDF outputs faster.',
    description:
        'Start from text, images, or office files and shape fresh documents for mobile work.',
    icon: Icons.auto_awesome_rounded,
  ),
  organize(
    label: 'Organize',
    headline: 'Control page flow with precision.',
    description:
        'Merge, split, reorder, and repair page layout before sharing or exporting.',
    icon: Icons.layers_rounded,
  ),
  secure(
    label: 'Secure',
    headline: 'Finalize, protect, and optimize delivery.',
    description:
        'Add passwords, OCR, watermarks, and lighter export files for dependable sharing.',
    icon: Icons.shield_rounded,
  );

  const _ToolSuiteCategory({
    required this.label,
    required this.headline,
    required this.description,
    required this.icon,
  });

  final String label;
  final String headline;
  final String description;
  final IconData icon;
}

class _ToolData {
  const _ToolData(
    this.icon,
    this.title,
    this.subtitle,
    this.color,
    this.onTap, {
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final FutureOr<void> Function() onTap;
  final String badge;
}

class _ToolSectionData {
  const _ToolSectionData({
    required this.title,
    required this.subtitle,
    required this.tools,
  });

  final String title;
  final String subtitle;
  final List<_ToolData> tools;
}

class _ToolCountBadge extends StatelessWidget {
  const _ToolCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tools',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  const _ToolPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(
                subtitle,
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
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onShare, this.onOpen});

  final PdfToolkitResult result;
  final VoidCallback onShare;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.check, size: 16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, size: 20),
                  onPressed: onShare,
                ),
                if (onOpen != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 20),
                    onPressed: onOpen,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(result.message),
            if (result.previewText != null &&
                result.previewText!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                result.previewText!.trim(),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PageRangeInput {
  const _PageRangeInput({required this.startPage, required this.endPage});

  final int startPage;
  final int endPage;
}

class _RotateInput {
  const _RotateInput({required this.pages, required this.quarterTurns});

  final List<int> pages;
  final int quarterTurns;
}
