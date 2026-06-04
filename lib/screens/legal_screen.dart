import 'package:flutter/material.dart';

import '../services/ads_service.dart';
import '../widgets/ad_widgets.dart';

class LegalScreen extends StatefulWidget {
  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  static const String privacyPolicy = '''
Privacy Policy for PDF Editor Pro

Last updated: May 8, 2026

PDF Editor Pro is a mobile app for viewing, editing, annotating, converting, organizing, and sharing PDF files. This Privacy Policy explains what information the app handles, how it is used, and what choices users have.

1. Information the App Handles
- PDF files, images, and other documents that you choose to open, convert, edit, merge, split, extract, watermark, compress, OCR-scan, export, print, or share.
- Basic app settings and usage preferences stored on your device, such as theme mode and recent file history.
- Cloud connection details if you choose to connect Google Drive or Dropbox. These details may include your account display name, email address, access tokens, refresh tokens, expiry times, and provider-specific folder metadata.
- Advertising-related device or network data collected by Google Mobile Ads and its partners when ads are shown in the app.

2. How Information Is Used
- To open, render, edit, save, export, print, and share PDF files.
- To run optional OCR and document conversion features that you start inside the app.
- To remember your preferences and recent files on your device.
- To connect to your own cloud storage account only when you request it, and to upload, list, download, or open your PDF files from that account.
- To show ads, rewarded ads, banner ads, interstitial ads, and native ads that support the app.

3. Local Processing
Most PDF editing and toolkit operations run locally on your device. Files are not uploaded to the developer's servers by default.

4. Cloud Storage Features
If you choose to connect Google Drive or Dropbox:
- the app accesses only the account that you sign in with;
- the app uses the permissions requested during sign-in to upload, list, download, and open your files;
- cloud tokens and session details are stored locally on your device using secure storage where supported;
- your files are transferred directly between your device and the selected cloud provider;
- the developer does not use your cloud files for advertising, profiling, or sale.

PDF Editor Pro's use and transfer of information received from Google APIs will adhere to the Google API Services User Data Policy, including the Limited Use requirements.

5. Advertising
The app uses Google Mobile Ads (AdMob). AdMob may collect or receive information such as device identifiers, IP address, approximate location, app interactions, and diagnostic data in accordance with Google's own policies. Ad serving and related data handling are controlled by Google and its partners.

6. Data Sharing
The app does not sell your personal information. Information may be shared only:
- with cloud providers that you choose to connect;
- with Google AdMob and related advertising partners for ad delivery;
- when you explicitly share or export files using your device's share or print features;
- when required by law or to protect rights, safety, or the integrity of the app.

7. Data Retention
- Recent file paths and app preferences remain on your device until you clear app data, remove them inside the app, or uninstall the app.
- Cloud session data remains on your device until you disconnect the provider, clear app data, or uninstall the app.
- Files created or exported by the app remain where you save them unless you delete them.

8. Security
The app uses reasonable measures to protect locally stored session data and app state. However, no method of electronic storage or transmission is completely secure, and users should protect their devices and cloud accounts with appropriate security controls.

9. Children's Privacy
PDF Editor Pro is not directed to children under 13, and the app is not intended to knowingly collect personal information from children.

10. Your Choices
- You may use many app features without connecting a cloud account.
- You may disconnect cloud providers at any time from the app.
- You may remove recent files, clear app data, revoke provider access from your cloud account, or uninstall the app.
- You may review privacy controls offered by Google and other third-party providers for ads and account permissions.

11. Third-Party Services
This app may rely on third-party services and SDKs, including:
- Google Mobile Ads (AdMob)
- Google Sign-In and Google Drive API
- Dropbox OAuth and Dropbox API
- Google ML Kit text recognition libraries

These third parties operate under their own terms and privacy policies.

12. Changes to This Policy
This Privacy Policy may be updated from time to time. Updated versions will be reflected in the app or in the published policy with a revised effective date.

13. Contact
For privacy questions or requests, contact: learnwithdg1@gmail.com
''';

  static const String termsAndConditions = '''
Terms and Conditions for PDF Editor Pro

1. Acceptance of Terms
By downloading or using the app, these terms will automatically apply to you - you should make sure therefore that you read them carefully before using the app.

2. Use of the App
You are not allowed to copy, or modify the app, any part of the app, or our trademarks in any way.

3. Changes to the Service
We are committed to ensuring that the app is as useful and efficient as possible. For that reason, we reserve the right to make changes to the app or to charge for its services, at any time and for any reason.

4. Ads and Subscriptions
The app displays advertisements. Some features may require watching a rewarded advertisement before use.

5. Limitation of Liability
We will not be liable for any loss of data or damage to your device resulting from the use of this application.
''';

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.content,
                    style: const TextStyle(fontSize: 14, height: 1.6),
                  ),
                  const SizedBox(height: 20),
                  const SmartNativeAd(),
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
