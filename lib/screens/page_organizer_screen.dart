import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../blocs/pdf_state.dart';
import '../services/ads_service.dart';
import '../services/pdf_toolkit_service.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';

class PageOrganizerScreen extends StatefulWidget {
  const PageOrganizerScreen({super.key});

  @override
  State<PageOrganizerScreen> createState() => _PageOrganizerScreenState();
}

class _PageOrganizerScreenState extends State<PageOrganizerScreen> {
  late List<int> _pageOrder;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    final state = context.read<PdfBloc>().state as PdfLoaded;
    _pageOrder = List.generate(state.document.pageCount, (index) => index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organize Pages'),
        actions: [
          if (!_isSaving)
            TextButton(
              onPressed: _saveNewOrder,
              child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pageOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final int item = _pageOrder.removeAt(oldIndex);
                      _pageOrder.insert(newIndex, item);
                    });
                    Vibration.vibrate(duration: 50);
                  },
                  itemBuilder: (context, index) {
                    final pageNum = _pageOrder[index];
                    return Card(
                      key: ValueKey(pageNum),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text('$pageNum', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                        title: Text('Page $pageNum'),
                        trailing: const Icon(Icons.drag_handle_rounded),
                      ),
                    );
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SmartNativeAd(isSmall: true),
              ),
              const SmartBannerAd(),
            ],
          ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Saving New Order...', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveNewOrder() async {
    setState(() => _isSaving = true);
    final state = context.read<PdfBloc>().state as PdfLoaded;
    final service = PdfToolkitService();
    
    try {
      final result = await service.reorderPdfPages(
        state.document.filePath,
        newOrder: _pageOrder,
      );
      
      if (mounted) {
        context.read<PdfBloc>().add(LoadPdfEvent(result.outputPaths.first));
        Navigator.pop(context);
        AppFeedback.showSuccess(
          context,
          'Your new page order has been applied.',
        );
      }
    } catch (error) {
      if (mounted) {
        AppFeedback.showError(
          context,
          error,
          fallback: 'The page order could not be saved.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
