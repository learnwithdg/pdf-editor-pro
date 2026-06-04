import 'package:flutter/foundation.dart';

import '../models/cloud_storage_models.dart';

class CloudEnvironment {
  static const String appAuthRedirectScheme = 'com.pdfediter.pro.auth';
  static const String appAuthRedirectHost = 'oauth';
  static const String appAuthRedirectUri = 'com.pdfediter.pro.auth://oauth/callback';
  static const String boxLoopbackRedirectBase = 'http://127.0.0.1/callback';
  static const String appFolderName = 'PDF Editor Pro';

  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static const String microsoftClientId = String.fromEnvironment('MICROSOFT_CLIENT_ID');
  static const String microsoftTenantId = String.fromEnvironment(
    'MICROSOFT_TENANT_ID',
    defaultValue: 'common',
  );

  static const String dropboxClientId = String.fromEnvironment('DROPBOX_CLIENT_ID');

  static const String boxClientId = String.fromEnvironment('BOX_CLIENT_ID');
  static const String boxClientSecret = String.fromEnvironment('BOX_CLIENT_SECRET');

  static bool get hasGoogleClient =>
      googleClientId.isNotEmpty || googleServerClientId.isNotEmpty;

  static bool get hasPartialGoogleDriveConfiguration =>
      googleClientId.isNotEmpty && googleServerClientId.isEmpty;

  static bool get requiresGoogleServerClientId =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get hasGoogleDriveConfiguration =>
      requiresGoogleServerClientId
          ? googleServerClientId.isNotEmpty
          : hasGoogleClient;

  static bool isConfigured(CloudProvider provider) {
    return switch (provider) {
      CloudProvider.googleDrive => hasGoogleDriveConfiguration,
      CloudProvider.oneDrive => microsoftClientId.isNotEmpty,
      CloudProvider.dropbox => dropboxClientId.isNotEmpty,
      CloudProvider.box => boxClientId.isNotEmpty && boxClientSecret.isNotEmpty,
    };
  }

  static String missingConfigurationMessage(CloudProvider provider) {
    return switch (provider) {
      CloudProvider.googleDrive => requiresGoogleServerClientId
          ? 'Add GOOGLE_SERVER_CLIENT_ID with your Google Web OAuth client ID and register the Android package plus signing SHA values in Google Cloud.'
          : 'Add GOOGLE_CLIENT_ID or GOOGLE_SERVER_CLIENT_ID and register the Android package plus signing SHA values in Google Cloud.',
      CloudProvider.oneDrive => 'Add MICROSOFT_CLIENT_ID and register the redirect URI com.pdfediter.pro.auth://oauth/callback in Azure.',
      CloudProvider.dropbox => 'Add DROPBOX_CLIENT_ID and register the redirect URI com.pdfediter.pro.auth://oauth/callback in Dropbox.',
      CloudProvider.box => 'Add BOX_CLIENT_ID and BOX_CLIENT_SECRET, then register a loopback redirect such as http://127.0.0.1/callback in Box.',
    };
  }
}
