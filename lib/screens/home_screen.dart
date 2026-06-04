import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../blocs/pdf_state.dart';
import '../blocs/theme_bloc.dart';
import '../services/ads_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';
import 'about_screen.dart';
import 'cloud_storage_screen.dart';
import 'output_library_screen.dart';
import 'pdf_tools_hub_screen.dart';
import 'pdf_viewer_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _smokePdfPath = String.fromEnvironment('SMOKE_PDF_PATH');
  List<String> _recentPaths = <String>[];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isPromptingForPassword = false;
  bool _smokeLaunchTriggered = false;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    AdsService().warmUpPremiumAds();
    _loadRecentFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoOpenSmokePdf());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentFiles() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentPaths = prefs.getStringList('recent_pdf_files') ?? <String>[];
    });
  }

  void _maybeAutoOpenSmokePdf() {
    if (_smokeLaunchTriggered || _smokePdfPath.isEmpty || !mounted) {
      return;
    }
    final smokeFile = File(_smokePdfPath);
    if (!smokeFile.existsSync()) {
      return;
    }
    _smokeLaunchTriggered = true;
    context.read<PdfBloc>().add(const LoadPdfEvent(_smokePdfPath));
  }

  Future<void> _removeFromRecent(String path) async {
    final prefs = await SharedPreferences.getInstance();
    _recentPaths.remove(path);
    await prefs.setStringList('recent_pdf_files', _recentPaths);
    setState(() {});
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('recent_pdf_files');
    await _loadRecentFiles();
  }

  Future<void> _protectedAction(VoidCallback action) async {
    final success = await AdsService().showRewardedAd(context);
    if (success) {
      action();
    }
  }

  void _openToolkit() {
    AdsService().registerToolLaunch();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PdfToolsHubScreen()),
    );
  }

  void _openOutputLibrary() {
    AdsService().registerToolLaunch();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OutputLibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocConsumer<PdfBloc, PdfState>(
        listener: (context, state) {
          if (state is PdfError) {
            AppFeedback.showError(context, state.message, fallback: state.message);
          }
          if (state is PdfPasswordRequired) {
            unawaited(_promptForPdfPassword(state));
          }
          if (state is PdfLoaded) {
            _loadRecentFiles();
          }
        },
        builder: (context, state) {
          if (state is PdfLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is PdfLoaded) {
            return const PdfViewerScreen();
          }
          return _buildDashboard(context);
        },
      ),
      bottomNavigationBar: const SmartBannerAd(),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    final filteredPaths = _recentPaths
        .where((path) => path.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList(growable: false);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final compact = width < 420;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context).animate().fade(duration: 350.ms),
                      const SizedBox(height: 18),
                      _buildCommandBar(context, compact)
                          .animate()
                          .fade(delay: 80.ms, duration: 350.ms)
                          .slideY(begin: 0.08, end: 0),
                      const SizedBox(height: 18),
                      _buildMainCard(context, compact)
                          .animate()
                          .fade(delay: 120.ms, duration: 400.ms)
                          .scale(begin: const Offset(0.98, 0.98), end: const Offset(1, 1)),
                      const SizedBox(height: 18),
                      _buildSignalBar(context)
                          .animate()
                          .fade(delay: 170.ms, duration: 380.ms)
                          .slideY(begin: 0.08, end: 0),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        'Quick Start',
                        'Jump into the most-used mobile workflows.',
                      ),
                      const SizedBox(height: 14),
                      _buildQuickToolsSection(context, width),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        context,
                        'Feature Highlights',
                        'Premium tools with cleaner, faster actions.',
                        trailing: TextButton(
                          onPressed: () => _protectedAction(_openToolkit),
                          child: const Text('Open Suite'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildToolsGrid(context, width),
                      const SizedBox(height: 24),
                      const SmartNativeAd(),
                      const SizedBox(height: 28),
                      _buildSectionHeader(
                        context,
                        'Recent Workspace',
                        'Pick up from your last edited files.',
                        trailing: _recentPaths.isNotEmpty
                            ? TextButton(
                                onPressed: _clearHistory,
                                child: const Text('Clear'),
                              )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      if (_recentPaths.isNotEmpty) _buildSearchBar(),
                      _recentPaths.isEmpty
                          ? _buildRecentPlaceholder(context)
                          : _buildRecentList(context, filteredPaths),
                      const SizedBox(height: 100),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.watch<ThemeBloc>().state == ThemeMode.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PDF Editor Pro',
                  style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Document Studio',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create, edit, convert, and manage files in one polished workspace.',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderActionButton(
                icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                onTap: () => context.read<ThemeBloc>().add(ToggleThemeEvent()),
              ),
              _HeaderActionButton(
                icon: Icons.settings_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _HeaderActionButton(
                icon: Icons.info_outline_rounded,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommandBar(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _CommandBarButton(
              icon: Icons.file_open_rounded,
              label: 'Open PDF',
              color: theme.colorScheme.primary,
              onTap: () => _protectedAction(() => _pickPdf(context)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CommandBarButton(
              icon: Icons.auto_awesome_mosaic_rounded,
              label: 'Tool Suite',
              color: theme.colorScheme.tertiary,
              onTap: () => _protectedAction(_openToolkit),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CommandBarButton(
              icon: Icons.folder_special_rounded,
              label: 'Library',
              color: const Color(0xFF3F8C8D),
              onTap: () => _protectedAction(_openOutputLibrary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _CommandBarButton(
              icon: Icons.cloud_sync_rounded,
              label: 'Cloud Sync',
              color: theme.colorScheme.secondary,
              onTap: () => _protectedAction(
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CloudStorageScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainCard(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 24 : 30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE34D2F), Color(0xFF8B1F1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -26,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -34,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'PREMIUM MOBILE WORKSPACE',
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
              const SizedBox(height: 20),
              Text(
                'Edit, convert, sign, and organize PDFs with a smoother premium flow.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 24 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Open files, add notes, run OCR, compress documents, and keep everything ready for mobile sharing.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  height: 1.45,
                  fontSize: compact ? 14 : 15,
                ),
              ),
              const SizedBox(height: 22),
              const Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _GlassInfoChip(label: '20+ smart tools'),
                  _GlassInfoChip(label: 'OCR + cloud ready'),
                  _GlassInfoChip(label: 'Fast export flow'),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Vibration.vibrate(duration: 50);
                      _protectedAction(() => _pickPdf(context));
                    },
                    icon: const Icon(Icons.file_open_rounded),
                    label: const Text('Open PDF File'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8B1F1A),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _protectedAction(_openToolkit),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Explore Tool Suite'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.38)),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _SignalMetric(
              label: 'Create',
              value: 'Image to PDF',
              icon: Icons.auto_fix_high_rounded,
            ),
          ),
          Expanded(
            child: _SignalMetric(
              label: 'Edit',
              value: 'Notes & Sign',
              icon: Icons.draw_rounded,
            ),
          ),
          Expanded(
            child: _SignalMetric(
              label: 'Share',
              value: 'Export Fast',
              icon: Icons.file_upload_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
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
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildQuickToolsSection(BuildContext context, double width) {
    final tools = <_QuickToolConfig>[
      _QuickToolConfig(
        icon: Icons.auto_fix_high_rounded,
        label: 'Toolkit',
        subtitle: 'All PDF utilities',
        accent: const Color(0xFF1F6FEB),
        onTap: () => _protectedAction(_openToolkit),
      ),
      _QuickToolConfig(
        icon: Icons.image_rounded,
        label: 'Image Tools',
        subtitle: 'Convert and export',
        accent: const Color(0xFF5B8C5A),
        onTap: () => _protectedAction(_openToolkit),
      ),
      _QuickToolConfig(
        icon: Icons.border_color_rounded,
        label: 'Open & Sign',
        subtitle: 'Review and annotate',
        accent: const Color(0xFFC84D31),
        onTap: () => _protectedAction(() => _pickPdf(context)),
      ),
      _QuickToolConfig(
        icon: Icons.folder_special_rounded,
        label: 'Output Library',
        subtitle: 'Browse saved exports',
        accent: const Color(0xFF3F8C8D),
        onTap: () => _protectedAction(_openOutputLibrary),
      ),
      _QuickToolConfig(
        icon: Icons.cloud_outlined,
        label: 'Cloud Drive',
        subtitle: 'Google Drive / Dropbox',
        accent: const Color(0xFFAA7B27),
        onTap: () => _protectedAction(
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CloudStorageScreen()),
          ),
        ),
      ),
    ];

    final columns = width > 980
        ? 4
        : width > 680
            ? 2
            : 1;

    if (columns == 1) {
      return Column(
        children: tools
            .map(
              (tool) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuickToolBtn(config: tool),
              ),
            )
            .toList(growable: false),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: columns == 2 ? 1.8 : 1.2,
      ),
      itemBuilder: (context, index) => _QuickToolBtn(config: tools[index]),
    );
  }

  Widget _buildToolsGrid(BuildContext context, double width) {
    final tools = <_ToolConfig>[
      const _ToolConfig(
        icon: Icons.merge_type_rounded,
        title: 'Merge PDFs',
        subtitle: 'Combine multiple documents into one clean file.',
        color: Color(0xFF1F6FEB),
      ),
      const _ToolConfig(
        icon: Icons.compress_rounded,
        title: 'Compress PDF',
        subtitle: 'Reduce file size for faster mobile sharing.',
        color: Color(0xFF198754),
      ),
      const _ToolConfig(
        icon: Icons.lock_person_rounded,
        title: 'Protect PDF',
        subtitle: 'Add password protection and control access.',
        color: Color(0xFFB63E2F),
      ),
      const _ToolConfig(
        icon: Icons.spellcheck_rounded,
        title: 'OCR Reader',
        subtitle: 'Extract text from scanned files and snapshots.',
        color: Color(0xFFC88719),
      ),
    ];

    if (width < 560) {
      return Column(
        children: tools
            .map(
              (tool) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ToolCard(
                  tool: tool,
                  compact: true,
                  onTap: () => _protectedAction(_openToolkit),
                ),
              ),
            )
            .toList(growable: false),
      );
    }

    final crossAxisCount = width >= 1080 ? 4 : 2;
    final childAspectRatio = width >= 1080 ? 1.02 : 1.28;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) => _ToolCard(
        tool: tools[index],
        compact: false,
        onTap: () => _protectedAction(_openToolkit),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: const InputDecoration(
          hintText: 'Search recent files...',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ).animate().fade().slideY(begin: 0.08, end: 0),
    );
  }

  Widget _buildRecentList(BuildContext context, List<String> paths) {
    final theme = Theme.of(context);
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: paths.length,
      itemBuilder: (context, index) {
        final path = paths[index];
        final file = File(path);
        final fileName = path.split(Platform.pathSeparator).last;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            leading: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.18),
                    theme.colorScheme.tertiary.withValues(alpha: 0.14),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
            ),
            title: Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: file.existsSync()
                  ? Text(_formatRecentSubtitle(file))
                  : const Text('File not found', style: TextStyle(color: Colors.red)),
            ),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 18),
            ),
            onTap: () {
              Vibration.vibrate(duration: 40);
              if (file.existsSync()) {
                context.read<PdfBloc>().add(LoadPdfEvent(path));
              } else {
                _removeFromRecent(path);
                AppFeedback.showInfo(
                  context,
                  'This recent PDF is no longer available on the device.',
                );
              }
            },
          ),
        ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.06, end: 0);
      },
    );
  }

  Widget _buildRecentPlaceholder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.primaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 42,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Recent Files',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a PDF or launch the premium tool suite to start your next document workflow.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () => _protectedAction(_openToolkit),
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Open PDF Toolkit'),
          ),
        ],
      ),
    );
  }

  String _formatRecentSubtitle(File file) {
    final sizeMb = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(2);
    final date = DateFormat('dd MMM').format(file.lastModifiedSync());
    return '$sizeMb MB | $date';
  }

  Future<void> _pickPdf(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (result != null && result.files.single.path != null && context.mounted) {
      context.read<PdfBloc>().add(LoadPdfEvent(result.files.single.path!));
    }
  }

  Future<void> _promptForPdfPassword(PdfPasswordRequired state) async {
    if (_isPromptingForPassword || !mounted) {
      return;
    }

    _isPromptingForPassword = true;
    final controller = TextEditingController();
    final password = await showModalBottomSheet<String>(
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
                'Open Protected PDF',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                state.message ?? 'Enter the PDF password to continue.',
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter PDF password',
                  suffixIcon: Icon(Icons.lock_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) => Navigator.pop(sheetContext, value.trim()),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, controller.text.trim()),
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text('Open ${state.fileName}'),
                ),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    _isPromptingForPassword = false;

    if (!mounted) {
      return;
    }
    if (password == null || password.trim().isEmpty) {
      context.read<PdfBloc>().add(const ClosePdfEvent());
      return;
    }
    context.read<PdfBloc>().add(
          LoadPdfEvent(
            state.filePath,
            password: password.trim(),
          ),
        );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: () {
        Vibration.vibrate(duration: 20);
        onTap();
      },
      style: IconButton.styleFrom(
        minimumSize: const Size(42, 42),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _CommandBarButton extends StatelessWidget {
  const _CommandBarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Vibration.vibrate(duration: 20);
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.16),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassInfoChip extends StatelessWidget {
  const _GlassInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _SignalMetric extends StatelessWidget {
  const _SignalMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

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
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickToolBtn extends StatelessWidget {
  const _QuickToolBtn({required this.config});

  final _QuickToolConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        Vibration.vibrate(duration: 20);
        config.onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    config.accent.withValues(alpha: 0.2),
                    config.accent.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(config.icon, color: config.accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.label,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    config.subtitle,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.north_east_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.tool,
    required this.compact,
    required this.onTap,
  });

  final _ToolConfig tool;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (compact) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      tool.color.withValues(alpha: 0.2),
                      tool.color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(tool.icon, color: tool.color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tool.subtitle,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
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
                      colors: [
                        tool.color.withValues(alpha: 0.18),
                        tool.color.withValues(alpha: 0.06),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(tool.icon, color: tool.color, size: 26),
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
            const Spacer(),
            Text(
              tool.title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              tool.subtitle,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickToolConfig {
  const _QuickToolConfig({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;
}

class _ToolConfig {
  const _ToolConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}
