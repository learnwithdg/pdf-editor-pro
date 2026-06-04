import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../widgets/ad_widgets.dart';
import 'faq_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('About PDF Editor Pro')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset(
                      'assets/branding/pdf_editer_pro_logo.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'PDF Editor Pro',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text('Version 1.2.6'),
                  const SizedBox(height: 32),
                  const _InfoTile(
                    icon: Icons.check_circle_outline,
                    title: 'Professional Annotations',
                    subtitle:
                        'Highlight, pen, signature, and text note support.',
                  ),
                  const _InfoTile(
                    icon: Icons.construction_rounded,
                    title: 'Powerful Toolkit',
                    subtitle:
                        'Merge, split, compress, OCR, and password tools built in.',
                  ),
                  const _InfoTile(
                    icon: Icons.security_rounded,
                    title: 'Secure and Private',
                    subtitle:
                        'Files stay on your device unless you choose to share or sync them.',
                  ),
                  const _InfoTile(
                    icon: Icons.folder_special_rounded,
                    title: 'Output Library',
                    subtitle:
                        'Find generated PDFs, images, reports, and backups in one place.',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FaqScreen()),
                    ),
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Open FAQ & Help'),
                  ),
                  const SizedBox(height: 24),
                  const SmartNativeAd(),
                  const SizedBox(height: 24),
                  Text(
                    'Built for fast PDF workflows',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '(c) 2024 PDF Editor Pro Team',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange, size: 30),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
