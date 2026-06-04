import 'package:flutter/material.dart';
import '../services/ads_service.dart';
import 'output_library_screen.dart';
import 'legal_screen.dart';
import 'faq_screen.dart';
import '../widgets/ad_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSave = true;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSection('General'),
                SwitchListTile(
                  title: const Text('Auto-save Annotations'),
                  subtitle: const Text(
                    'Saves changes automatically when closing',
                  ),
                  value: _autoSave,
                  onChanged: (v) => setState(() => _autoSave = v),
                ),
                _buildSection('Legal & Privacy'),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(
                        title: 'Privacy Policy',
                        content: LegalScreen.privacyPolicy,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms & Conditions'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(
                        title: 'Terms & Conditions',
                        content: LegalScreen.termsAndConditions,
                      ),
                    ),
                  ),
                ),
                _buildSection('Help & Support'),
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined),
                  title: const Text('Output Library'),
                  subtitle: const Text(
                    'Browse generated PDFs, images, OCR reports, and backups',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OutputLibraryScreen(),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.quiz_outlined),
                  title: const Text('FAQ & Help'),
                  subtitle: const Text(
                    'Quick answers for editing, exports, cloud sync, and ads',
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FaqScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.query_stats_outlined),
                  title: const Text('AdMob Diagnostics'),
                  subtitle: const Text(
                    'Check no-fill, request, and network status on this device',
                  ),
                  onTap: () => AdsService().openAdInspector(context),
                ),
                _buildSection('App Info'),
                const ListTile(title: Text('Version'), trailing: Text('1.2.6')),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: SmartNativeAd(),
                ),
              ],
            ),
          ),
          const SmartBannerAd(),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
