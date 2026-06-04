import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../widgets/ad_widgets.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  static const List<_FaqSection> _sections = <_FaqSection>[
    _FaqSection(
      title: 'Getting Started',
      subtitle: 'Core things users ask right after installing the app.',
      items: <_FaqItem>[
        _FaqItem(
          question: 'How do I open a PDF?',
          answer:
              'Use Open PDF on the home screen, then choose any PDF file from your device storage. The file opens in the reader workspace immediately.',
        ),
        _FaqItem(
          question: 'Can I edit or annotate a PDF?',
          answer:
              'Yes. Open a PDF, switch into edit mode, then use highlight, pen, note, signature, or shape tools from the toolbar.',
        ),
        _FaqItem(
          question: 'Where are my edited PDFs saved?',
          answer:
              'When you save an edited PDF, the app creates a new saved copy and keeps the original file untouched unless you choose to replace it elsewhere.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Tools & Export',
      subtitle: 'Image conversion, page tools, and export behavior.',
      items: <_FaqItem>[
        _FaqItem(
          question: 'Can I export only selected PDF pages as images?',
          answer:
              'Yes. Open PDF to Images, select the pages you want, then export only those pages or save them directly to the gallery.',
        ),
        _FaqItem(
          question: 'Does Text to PDF support styled layouts?',
          answer:
              'Yes. The Text to PDF studio supports text blocks, headings, colors, tables, page styling, and richer layout controls for custom documents.',
        ),
        _FaqItem(
          question: 'Which PDF tools are included?',
          answer:
              'The app includes image to PDF, PDF to images, merge, split, extract pages, reorder, rotate, watermark, compress, flatten, OCR, password tools, and more.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Cloud & Sync',
      subtitle: 'Google Drive and Dropbox setup guidance.',
      items: <_FaqItem>[
        _FaqItem(
          question: 'Can I connect my own cloud account?',
          answer:
              'Yes. Each user connects their own Google Drive or Dropbox account. The app does not connect to a shared developer storage account.',
        ),
        _FaqItem(
          question: 'Why is Google Drive showing setup required?',
          answer:
              'On Android, Google Drive needs a proper GOOGLE_SERVER_CLIENT_ID from a Google Web OAuth client. Without that production setup, the app will show setup guidance instead of a broken sign-in flow.',
        ),
        _FaqItem(
          question: 'What can I do after connecting cloud storage?',
          answer:
              'You can browse remote PDFs, upload a PDF to your app folder, download synced documents, and open them directly inside PDF Editor Pro.',
        ),
      ],
    ),
    _FaqSection(
      title: 'Privacy, Ads & Support',
      subtitle: 'How files, ads, and help work inside the app.',
      items: <_FaqItem>[
        _FaqItem(
          question: 'Are my files uploaded to your servers?',
          answer:
              'No. Most PDF work stays on your device. Files go to Google Drive or Dropbox only when you explicitly connect your own account and choose to sync or upload.',
        ),
        _FaqItem(
          question: 'Why do I sometimes see ads before a tool runs?',
          answer:
              'Some advanced actions use rewarded ads to unlock the feature flow. The app now shows a clear waiting message if an ad is still loading so the experience feels less abrupt.',
        ),
        _FaqItem(
          question: 'How can I contact support?',
          answer:
              'You can reach support at learnwithdg1@gmail.com for setup questions, cloud issues, or general feedback about the app.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ & Help', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF1D3F4D), Color(0xFF0D2027)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
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
                            Icon(Icons.help_outline_rounded, color: Colors.amberAccent, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'SMART SUPPORT',
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
                      const Text(
                        'Helpful answers for editing, exporting, syncing, and sharing PDFs.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use this page when you want quick help without digging through settings or trial and error.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.76), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _sections.length; i++) ...[
                  _FaqSectionCard(section: _sections[i]),
                  if (i == 1) const SmartNativeAd(isSmall: false),
                  if (i != _sections.length - 1) const SizedBox(height: 18),
                ],
              ],
            ),
          ),
          const SmartBannerAd(),
        ],
      ),
    );
  }
}

class _FaqSectionCard extends StatelessWidget {
  const _FaqSectionCard({required this.section});

  final _FaqSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.subtitle,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            ...section.items.map(
              (item) => Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 12),
                  title: Text(
                    item.question,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.answer,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
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
}

class _FaqSection {
  const _FaqSection({
    required this.title,
    required this.subtitle,
    required this.items,
  });

  final String title;
  final String subtitle;
  final List<_FaqItem> items;
}

class _FaqItem {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
