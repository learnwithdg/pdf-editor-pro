import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';

class PdfToImageStudioScreen extends StatefulWidget {
  const PdfToImageStudioScreen({
    super.key,
    required this.pdfPath,
  });

  final String pdfPath;

  @override
  State<PdfToImageStudioScreen> createState() => _PdfToImageStudioScreenState();
}

class _PdfToImageStudioScreenState extends State<PdfToImageStudioScreen> {
  final PdfToolkitService _toolkitService = PdfToolkitService();
  final Map<int, Future<Uint8List>> _thumbnailCache = <int, Future<Uint8List>>{};

  pdfx.PdfDocument? _document;
  PdfDocumentInfo? _info;
  final Set<int> _selectedPages = <int>{};
  List<String> _lastExportedPaths = <String>[];
  bool _isLoading = true;
  bool _isWorking = false;
  String _workingLabel = 'Preparing pages...';

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    _openDocument();
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  Future<void> _openDocument() async {
    final info = await _toolkitService.inspectPdf(widget.pdfPath);
    final document = await pdfx.PdfDocument.openFile(widget.pdfPath);
    if (!mounted) {
      await document.close();
      return;
    }

    setState(() {
      _document = document;
      _info = info;
      _selectedPages
        ..clear()
        ..addAll(List<int>.generate(info.pageCount, (index) => index + 1));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Images Studio', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_lastExportedPaths.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share images',
              onPressed: _shareExportedImages,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroCard(context)),
                    SliverToBoxAdapter(child: _buildSelectionBar(context)),
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: <Widget>[
                            SmartNativeAd(isSmall: true),
                            SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPageTile(index + 1),
                          childCount: _info!.pageCount,
                        ),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isWorking) _buildWorkingOverlay(),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectedPages.isEmpty ? null : () => _exportSelectedPages(saveToGallery: false),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Export JPG'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _selectedPages.isEmpty ? null : () => _exportSelectedPages(saveToGallery: true),
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Auto Save JPG'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SmartBannerAd(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selectedPages.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        width: double.infinity,
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
            const Icon(Icons.collections_rounded, color: Colors.white, size: 34),
            const SizedBox(height: 14),
            Text(
              _info!.fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose only the pages you want. Export them as JPG images or save them straight to the gallery automatically.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.88), height: 1.35),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildHeroChip('${_info!.pageCount} pages'),
                _buildHeroChip('$selectedCount selected'),
                _buildHeroChip(_formatSize(_info!.fileSize)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildSelectionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: _selectAllPages,
              icon: const Icon(Icons.done_all_rounded),
              label: const Text('Select All'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _clearSelection,
              icon: const Icon(Icons.deselect_rounded),
              label: const Text('Clear'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTile(int pageNumber) {
    final isSelected = _selectedPages.contains(pageNumber);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _togglePage(pageNumber),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: Colors.white,
                child: FutureBuilder<Uint8List>(
                  future: _thumbnailCache.putIfAbsent(pageNumber, () => _renderThumbnail(pageNumber)),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    return Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Page $pageNumber',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      isSelected ? 'Selected' : 'Tap to add',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingOverlay() {
    return Container(
      color: Colors.black45,
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                Text(_workingLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _renderThumbnail(int pageNumber) async {
    final page = await _document!.getPage(pageNumber);
    final rendered = await page.render(
      width: 360,
      height: 480,
      format: pdfx.PdfPageImageFormat.png,
    );
    await page.close();
    return rendered!.bytes;
  }

  void _togglePage(int pageNumber) {
    setState(() {
      if (_selectedPages.contains(pageNumber)) {
        _selectedPages.remove(pageNumber);
      } else {
        _selectedPages.add(pageNumber);
      }
    });
  }

  void _selectAllPages() {
    setState(() {
      _selectedPages
        ..clear()
        ..addAll(List<int>.generate(_info!.pageCount, (index) => index + 1));
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPages.clear();
    });
  }

  Future<void> _exportSelectedPages({required bool saveToGallery}) async {
    setState(() {
      _isWorking = true;
      _workingLabel = saveToGallery ? 'Saving selected JPG pages to gallery...' : 'Exporting selected JPG pages...';
    });

    try {
      final result = await _toolkitService.exportSelectedPdfPagesToImages(
        widget.pdfPath,
        pageNumbers: _selectedPages.toList(growable: false),
      );
      var message = result.message;
      if (saveToGallery) {
        final saved = await _toolkitService.saveImagesToGallery(result.outputPaths);
        message = saved
            ? 'Saved ${result.outputPaths.length} image(s) to your gallery.'
            : 'JPG files were exported, but gallery save could not be completed.';
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _lastExportedPaths = result.outputPaths;
      });
      AppFeedback.showSuccess(
        context,
        message,
        behavior: SnackBarBehavior.floating,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'The selected PDF pages could not be exported as JPG images.',
        behavior: SnackBarBehavior.floating,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _shareExportedImages() async {
    if (_lastExportedPaths.isEmpty) {
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: _lastExportedPaths.map((path) => XFile(path)).toList(growable: false)),
    );
  }

  String _formatSize(int bytes) {
    final sizeMb = bytes / (1024 * 1024);
    return '${sizeMb.toStringAsFixed(2)} MB';
  }
}
