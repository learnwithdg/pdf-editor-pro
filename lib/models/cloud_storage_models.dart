import 'dart:convert';

import 'package:equatable/equatable.dart';

enum CloudProvider { googleDrive, oneDrive, dropbox, box }

extension CloudProviderX on CloudProvider {
  String get storageKey => switch (this) {
        CloudProvider.googleDrive => 'google_drive',
        CloudProvider.oneDrive => 'onedrive',
        CloudProvider.dropbox => 'dropbox',
        CloudProvider.box => 'box',
      };

  String get displayName => switch (this) {
        CloudProvider.googleDrive => 'Google Drive',
        CloudProvider.oneDrive => 'OneDrive',
        CloudProvider.dropbox => 'Dropbox',
        CloudProvider.box => 'Box',
      };

  String get shortDescription => switch (this) {
        CloudProvider.googleDrive => 'Sync PDFs to your Google Drive app folder.',
        CloudProvider.oneDrive => 'Keep PDFs in your OneDrive app storage.',
        CloudProvider.dropbox => 'Upload and open PDFs from your Dropbox app folder.',
        CloudProvider.box => 'Connect Box for upload and download workflows.',
      };
}

class CloudSession extends Equatable {
  const CloudSession({
    required this.provider,
    required this.accountName,
    required this.accountEmail,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.metadata = const <String, String>{},
  });

  final CloudProvider provider;
  final String accountName;
  final String accountEmail;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final Map<String, String> metadata;

  bool get hasRefreshToken => (refreshToken ?? '').isNotEmpty;

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) {
      return false;
    }
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 2)));
  }

  CloudSession copyWith({
    String? accountName,
    String? accountEmail,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, String>? metadata,
    bool clearAccessToken = false,
    bool clearRefreshToken = false,
    bool clearExpiry = false,
  }) {
    return CloudSession(
      provider: provider,
      accountName: accountName ?? this.accountName,
      accountEmail: accountEmail ?? this.accountEmail,
      accessToken: clearAccessToken ? null : accessToken ?? this.accessToken,
      refreshToken: clearRefreshToken ? null : refreshToken ?? this.refreshToken,
      expiresAt: clearExpiry ? null : expiresAt ?? this.expiresAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'provider': provider.storageKey,
      'accountName': accountName,
      'accountEmail': accountEmail,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  static CloudSession fromJson(String rawJson) {
    final Map<String, dynamic> json = jsonDecode(rawJson) as Map<String, dynamic>;
    return CloudSession(
      provider: CloudProvider.values.firstWhere(
        (provider) => provider.storageKey == json['provider'],
      ),
      accountName: json['accountName'] as String? ?? '',
      accountEmail: json['accountEmail'] as String? ?? '',
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'] as String),
      metadata: (json['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{})
          .map((key, value) => MapEntry(key, value.toString())),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        provider,
        accountName,
        accountEmail,
        accessToken,
        refreshToken,
        expiresAt,
        metadata,
      ];
}

class CloudRemoteFile extends Equatable {
  const CloudRemoteFile({
    required this.provider,
    required this.id,
    required this.name,
    required this.size,
    this.modifiedAt,
    this.webUrl,
  });

  final CloudProvider provider;
  final String id;
  final String name;
  final int size;
  final DateTime? modifiedAt;
  final String? webUrl;

  @override
  List<Object?> get props => <Object?>[provider, id, name, size, modifiedAt, webUrl];
}

class CloudProviderStatus extends Equatable {
  const CloudProviderStatus({
    required this.provider,
    required this.isConfigured,
    required this.session,
    this.warning,
  });

  final CloudProvider provider;
  final bool isConfigured;
  final CloudSession? session;
  final String? warning;

  bool get isConnected => session != null;

  @override
  List<Object?> get props => <Object?>[provider, isConfigured, session, warning];
}
