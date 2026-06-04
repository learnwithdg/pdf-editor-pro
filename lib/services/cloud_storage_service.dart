import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/cloud_storage_models.dart';
import 'cloud_environment.dart';

class CloudStorageException implements Exception {
  const CloudStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudStorageService {
  CloudStorageService._();

  static final CloudStorageService instance = CloudStorageService._();

  static const List<String> _googleDriveScopes = <String>[
    'https://www.googleapis.com/auth/drive.file',
  ];
  static const List<String> _oneDriveScopes = <String>[
    'openid',
    'profile',
    'offline_access',
    'User.Read',
    'Files.ReadWrite.AppFolder',
  ];
  static const List<String> _dropboxScopes = <String>[
    'account_info.read',
    'files.metadata.read',
    'files.content.read',
    'files.content.write',
  ];

  static const AuthorizationServiceConfiguration _dropboxServiceConfiguration =
      AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://www.dropbox.com/oauth2/authorize',
    tokenEndpoint: 'https://api.dropboxapi.com/oauth2/token',
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final http.Client _httpClient = http.Client();

  final Map<CloudProvider, CloudSession?> _sessions =
      <CloudProvider, CloudSession?>{};

  bool _initialized = false;
  bool _googleInitialized = false;
  GoogleSignInAccount? _googleUser;

  Map<CloudProvider, CloudSession?> get sessions =>
      Map<CloudProvider, CloudSession?>.unmodifiable(_sessions);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    for (final provider in CloudProvider.values) {
      final raw = await _secureStorage.read(key: _storageKeyFor(provider));
      _sessions[provider] = raw == null ? null : CloudSession.fromJson(raw);
    }

    if (CloudEnvironment.hasGoogleDriveConfiguration) {
      await _ensureGoogleInitialized();
      await _restoreGoogleSession();
    }

    _initialized = true;
  }

  CloudProviderStatus statusFor(CloudProvider provider) {
    final warning = switch (provider) {
      CloudProvider.googleDrive when CloudEnvironment.hasPartialGoogleDriveConfiguration =>
        'Android Google Drive sign-in still needs GOOGLE_SERVER_CLIENT_ID from a Google Web OAuth client. GOOGLE_CLIENT_ID alone is not enough for a live Android login.',
      CloudProvider.box =>
        'Box mobile OAuth needs a client secret. For production, move Box token exchange to your backend.',
      _ => null,
    };
    return CloudProviderStatus(
      provider: provider,
      isConfigured: CloudEnvironment.isConfigured(provider),
      session: _sessions[provider],
      warning: warning,
    );
  }

  Future<CloudSession> connect(CloudProvider provider) async {
    await initialize();
    if (!CloudEnvironment.isConfigured(provider)) {
      throw CloudStorageException(
        CloudEnvironment.missingConfigurationMessage(provider),
      );
    }

    return switch (provider) {
      CloudProvider.googleDrive => _connectGoogleDrive(),
      CloudProvider.oneDrive => _connectOneDrive(),
      CloudProvider.dropbox => _connectDropbox(),
      CloudProvider.box => _connectBox(),
    };
  }

  Future<void> disconnect(CloudProvider provider) async {
    await initialize();
    if (provider == CloudProvider.googleDrive) {
      try {
        await _googleSignIn.disconnect();
      } catch (_) {
        await _googleSignIn.signOut();
      }
      _googleUser = null;
    }
    _sessions[provider] = null;
    await _secureStorage.delete(key: _storageKeyFor(provider));
  }

  Future<List<CloudRemoteFile>> listPdfFiles(CloudProvider provider) async {
    await initialize();
    return switch (provider) {
      CloudProvider.googleDrive => _listGoogleDriveFiles(),
      CloudProvider.oneDrive => _listOneDriveFiles(),
      CloudProvider.dropbox => _listDropboxFiles(),
      CloudProvider.box => _listBoxFiles(),
    };
  }

  Future<CloudRemoteFile> uploadPdf(
    CloudProvider provider,
    String filePath,
  ) async {
    await initialize();
    final file = File(filePath);
    if (!await file.exists()) {
      throw const CloudStorageException('Selected PDF file was not found.');
    }
    if (p.extension(filePath).toLowerCase() != '.pdf') {
      throw const CloudStorageException('Please choose a PDF file.');
    }

    return switch (provider) {
      CloudProvider.googleDrive => _uploadGoogleDriveFile(file),
      CloudProvider.oneDrive => _uploadOneDriveFile(file),
      CloudProvider.dropbox => _uploadDropboxFile(file),
      CloudProvider.box => _uploadBoxFile(file),
    };
  }

  Future<String> downloadPdf(CloudRemoteFile file) async {
    await initialize();
    return switch (file.provider) {
      CloudProvider.googleDrive => _downloadGoogleDriveFile(file),
      CloudProvider.oneDrive => _downloadOneDriveFile(file),
      CloudProvider.dropbox => _downloadDropboxFile(file),
      CloudProvider.box => _downloadBoxFile(file),
    };
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }
    if (!CloudEnvironment.hasGoogleDriveConfiguration) {
      throw CloudStorageException(
        CloudEnvironment.missingConfigurationMessage(CloudProvider.googleDrive),
      );
    }
    final googleClientId = CloudEnvironment.googleClientId.isEmpty
        ? null
        : CloudEnvironment.googleClientId;
    final googleServerClientId = CloudEnvironment.googleServerClientId.isNotEmpty
        ? CloudEnvironment.googleServerClientId
        : googleClientId;
    await _googleSignIn.initialize(
      clientId: googleClientId,
      serverClientId: googleServerClientId,
    );
    _googleInitialized = true;
  }

  Future<void> _restoreGoogleSession() async {
    final Future<GoogleSignInAccount?>? attempt =
        _googleSignIn.attemptLightweightAuthentication();
    if (attempt == null) {
      return;
    }
    try {
      final account = await attempt;
      if (account == null) {
        _googleUser = null;
        _sessions[CloudProvider.googleDrive] = null;
        await _secureStorage.delete(
          key: _storageKeyFor(CloudProvider.googleDrive),
        );
        return;
      }
      _googleUser = account;
      final existing = _sessions[CloudProvider.googleDrive];
      final session = CloudSession(
        provider: CloudProvider.googleDrive,
        accountName: account.displayName ?? account.email,
        accountEmail: account.email,
        metadata: existing?.metadata ?? const <String, String>{},
      );
      _sessions[CloudProvider.googleDrive] = session;
      await _persistSession(session);
    } catch (_) {
      _googleUser = null;
    }
  }

  Future<CloudSession> _connectGoogleDrive() async {
    await _ensureGoogleInitialized();
    try {
      final account = await _googleSignIn.authenticate(
        scopeHint: _googleDriveScopes,
      );
      await account.authorizationClient.authorizeScopes(_googleDriveScopes);
      _googleUser = account;
      final headers = await _googleHeaders(promptIfNecessary: true);
      final folderId = await _ensureGoogleDriveFolder(headers);
      final session = CloudSession(
        provider: CloudProvider.googleDrive,
        accountName: account.displayName ?? account.email,
        accountEmail: account.email,
        metadata: <String, String>{'folderId': folderId},
      );
      _sessions[CloudProvider.googleDrive] = session;
      await _persistSession(session);
      return session;
    } on GoogleSignInException catch (error) {
      throw CloudStorageException(_googleSignInMessage(error));
    }
  }

  Future<CloudSession> _connectOneDrive() async {
    final discoveryUrl =
        'https://login.microsoftonline.com/${CloudEnvironment.microsoftTenantId}/v2.0/.well-known/openid-configuration';
    final AuthorizationTokenResponse response =
        await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        CloudEnvironment.microsoftClientId,
        CloudEnvironment.appAuthRedirectUri,
        discoveryUrl: discoveryUrl,
        scopes: _oneDriveScopes,
        promptValues: const <String>['select_account'],
      ),
    );
    final profile = await _fetchOneDriveProfile(response.accessToken!);
    final session = CloudSession(
      provider: CloudProvider.oneDrive,
      accountName: profile['displayName'] as String? ?? 'OneDrive user',
      accountEmail: (profile['mail'] as String?) ??
          (profile['userPrincipalName'] as String?) ??
          'OneDrive account',
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
    _sessions[CloudProvider.oneDrive] = session;
    await _persistSession(session);
    return session;
  }

  Future<CloudSession> _connectDropbox() async {
    final AuthorizationTokenResponse response =
        await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        CloudEnvironment.dropboxClientId,
        CloudEnvironment.appAuthRedirectUri,
        serviceConfiguration: _dropboxServiceConfiguration,
        scopes: _dropboxScopes,
        additionalParameters: const <String, String>{
          'token_access_type': 'offline',
        },
      ),
    );
    final profile = await _fetchDropboxProfile(response.accessToken!);
    final session = CloudSession(
      provider: CloudProvider.dropbox,
      accountName: ((profile['name'] as Map<String, dynamic>?)?['display_name']
              as String?) ??
          'Dropbox user',
      accountEmail: profile['email'] as String? ?? 'Dropbox account',
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
    _sessions[CloudProvider.dropbox] = session;
    await _persistSession(session);
    return session;
  }

  Future<CloudSession> _connectBox() async {
    final authResult = await _authorizeBoxWithLoopback();
    final profile = await _fetchBoxProfile(authResult.accessToken);
    final session = CloudSession(
      provider: CloudProvider.box,
      accountName: profile['name'] as String? ?? 'Box user',
      accountEmail: profile['login'] as String? ?? 'Box account',
      accessToken: authResult.accessToken,
      refreshToken: authResult.refreshToken,
      expiresAt: authResult.expiresAt,
    );
    _sessions[CloudProvider.box] = session;
    await _persistSession(session);
    return session;
  }

  Future<List<CloudRemoteFile>> _listGoogleDriveFiles() async {
    final session = _requireSession(CloudProvider.googleDrive);
    final headers = await _googleHeaders(promptIfNecessary: true);
    final folderId = await _ensureGoogleDriveFolder(
      headers,
      currentSession: session,
    );
    final query = Uri.encodeQueryComponent(
      "'$folderId' in parents and mimeType='application/pdf' and trashed=false",
    );
    final response = await _httpClient.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&orderBy=modifiedTime desc&fields=files(id,name,size,modifiedTime,webViewLink)',
      ),
      headers: headers,
    );
    final json = _decodeJsonResponse(
      response,
      provider: CloudProvider.googleDrive,
    );
    return (json['files'] as List<dynamic>? ?? <dynamic>[])
        .map(
          (item) => CloudRemoteFile(
            provider: CloudProvider.googleDrive,
            id: item['id'] as String,
            name: item['name'] as String? ?? 'Untitled.pdf',
            size: int.tryParse(item['size']?.toString() ?? '') ?? 0,
            modifiedAt:
                DateTime.tryParse(item['modifiedTime']?.toString() ?? ''),
            webUrl: item['webViewLink'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<List<CloudRemoteFile>> _listOneDriveFiles() async {
    final session = await _ensureFreshSession(CloudProvider.oneDrive);
    final response = await _httpClient.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot/children?\$select=id,name,size,lastModifiedDateTime,webUrl,file',
      ),
      headers: _bearerHeaders(session.accessToken!),
    );
    final json = _decodeJsonResponse(
      response,
      provider: CloudProvider.oneDrive,
    );
    return (json['value'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where((item) => (item['name'] as String? ?? '').toLowerCase().endsWith('.pdf'))
        .map(
          (item) => CloudRemoteFile(
            provider: CloudProvider.oneDrive,
            id: item['id'] as String,
            name: item['name'] as String? ?? 'Untitled.pdf',
            size: (item['size'] as num?)?.toInt() ?? 0,
            modifiedAt: DateTime.tryParse(
              item['lastModifiedDateTime']?.toString() ?? '',
            ),
            webUrl: item['webUrl'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<List<CloudRemoteFile>> _listDropboxFiles() async {
    final session = await _ensureFreshSession(CloudProvider.dropbox);
    final response = await _httpClient.post(
      Uri.parse('https://api.dropboxapi.com/2/files/list_folder'),
      headers: <String, String>{
        ..._bearerHeaders(session.accessToken!),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'path': ''}),
    );
    final json = _decodeJsonResponse(
      response,
      provider: CloudProvider.dropbox,
    );
    return (json['entries'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where(
          (item) =>
              item['.tag'] == 'file' &&
              (item['name'] as String? ?? '').toLowerCase().endsWith('.pdf'),
        )
        .map(
          (item) => CloudRemoteFile(
            provider: CloudProvider.dropbox,
            id: item['path_lower'] as String? ?? item['id'] as String? ?? '',
            name: item['name'] as String? ?? 'Untitled.pdf',
            size: (item['size'] as num?)?.toInt() ?? 0,
            modifiedAt:
                DateTime.tryParse(item['client_modified']?.toString() ?? ''),
          ),
        )
        .toList(growable: false);
  }

  Future<List<CloudRemoteFile>> _listBoxFiles() async {
    final session = await _ensureFreshSession(CloudProvider.box);
    final folderId = await _ensureBoxFolderId(session);
    final response = await _httpClient.get(
      Uri.parse(
        'https://api.box.com/2.0/folders/$folderId/items?limit=1000&fields=id,name,size,modified_at,type,shared_link',
      ),
      headers: _bearerHeaders(session.accessToken!),
    );
    final json = _decodeJsonResponse(response, provider: CloudProvider.box);
    return (json['entries'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .where(
          (item) =>
              item['type'] == 'file' &&
              (item['name'] as String? ?? '').toLowerCase().endsWith('.pdf'),
        )
        .map(
          (item) => CloudRemoteFile(
            provider: CloudProvider.box,
            id: item['id'] as String,
            name: item['name'] as String? ?? 'Untitled.pdf',
            size: (item['size'] as num?)?.toInt() ?? 0,
            modifiedAt: DateTime.tryParse(
              item['modified_at']?.toString() ?? '',
            ),
            webUrl: ((item['shared_link'] as Map<String, dynamic>?)?['url']
                as String?),
          ),
        )
        .toList(growable: false);
  }

  Future<CloudRemoteFile> _uploadGoogleDriveFile(File file) async {
    final session = _requireSession(CloudProvider.googleDrive);
    final headers = await _googleHeaders(promptIfNecessary: true);
    final folderId = await _ensureGoogleDriveFolder(
      headers,
      currentSession: session,
    );
    final existingId = await _findGoogleDriveFileId(
      headers,
      folderId,
      p.basename(file.path),
    );
    final bytes = await file.readAsBytes();

    final metadata = <String, dynamic>{
      'name': p.basename(file.path),
      'mimeType': 'application/pdf',
      if (existingId == null) 'parents': <String>[folderId],
    };

    final startRequest = http.Request(
      existingId == null ? 'POST' : 'PATCH',
      Uri.parse(
        existingId == null
            ? 'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable'
            : 'https://www.googleapis.com/upload/drive/v3/files/$existingId?uploadType=resumable',
      ),
    )
      ..headers.addAll(<String, String>{
        ...headers,
        'Content-Type': 'application/json; charset=utf-8',
        'X-Upload-Content-Type': 'application/pdf',
        'X-Upload-Content-Length': bytes.length.toString(),
      })
      ..body = jsonEncode(metadata);

    final startResponse = await _httpClient.send(startRequest);
    final uploadLocation = startResponse.headers['location'];
    if (startResponse.statusCode >= 300 ||
        uploadLocation == null ||
        uploadLocation.isEmpty) {
      final body = await startResponse.stream.bytesToString();
      throw CloudStorageException(
        'Google Drive upload session could not be created (${startResponse.statusCode}). ${_extractErrorMessage(body)}',
      );
    }

    final uploadResponse = await _httpClient.put(
      Uri.parse(uploadLocation),
      headers: <String, String>{
        ...headers,
        'Content-Type': 'application/pdf',
        'Content-Length': bytes.length.toString(),
      },
      body: bytes,
    );
    final json = _decodeJsonResponse(
      uploadResponse,
      provider: CloudProvider.googleDrive,
    );
    return CloudRemoteFile(
      provider: CloudProvider.googleDrive,
      id: json['id'] as String? ?? existingId ?? '',
      name: json['name'] as String? ?? p.basename(file.path),
      size: bytes.length,
      modifiedAt: DateTime.tryParse(json['modifiedTime']?.toString() ?? ''),
      webUrl: json['webViewLink'] as String?,
    );
  }

  Future<CloudRemoteFile> _uploadOneDriveFile(File file) async {
    final session = await _ensureFreshSession(CloudProvider.oneDrive);
    final fileName = p.basename(file.path);
    final createSessionResponse = await _httpClient.post(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me/drive/special/approot:/$fileName:/createUploadSession',
      ),
      headers: <String, String>{
        ..._bearerHeaders(session.accessToken!),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'item': <String, dynamic>{
          '@microsoft.graph.conflictBehavior': 'replace',
          'name': fileName,
        },
      }),
    );
    final uploadSessionJson = _decodeJsonResponse(
      createSessionResponse,
      provider: CloudProvider.oneDrive,
    );
    final uploadUrl = uploadSessionJson['uploadUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw const CloudStorageException(
        'OneDrive did not return an upload session URL.',
      );
    }

    final bytes = await file.readAsBytes();
    const chunkSize = 320 * 1024 * 10;
    var start = 0;
    http.Response? lastResponse;

    while (start < bytes.length) {
      final end = min(start + chunkSize, bytes.length);
      final chunk = bytes.sublist(start, end);
      lastResponse = await _httpClient.put(
        Uri.parse(uploadUrl),
        headers: <String, String>{
          'Content-Length': chunk.length.toString(),
          'Content-Range': 'bytes $start-${end - 1}/${bytes.length}',
        },
        body: chunk,
      );
      if (lastResponse.statusCode >= 400) {
        throw CloudStorageException(
          'OneDrive upload failed (${lastResponse.statusCode}). ${_extractErrorMessage(lastResponse.body)}',
        );
      }
      start = end;
    }

    final json = _decodeJsonResponse(
      lastResponse!,
      provider: CloudProvider.oneDrive,
    );
    return CloudRemoteFile(
      provider: CloudProvider.oneDrive,
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? fileName,
      size: (json['size'] as num?)?.toInt() ?? bytes.length,
      modifiedAt: DateTime.tryParse(
        json['lastModifiedDateTime']?.toString() ?? '',
      ),
      webUrl: json['webUrl'] as String?,
    );
  }

  Future<CloudRemoteFile> _uploadDropboxFile(File file) async {
    final session = await _ensureFreshSession(CloudProvider.dropbox);
    final bytes = await file.readAsBytes();
    final response = await _httpClient.post(
      Uri.parse('https://content.dropboxapi.com/2/files/upload'),
      headers: <String, String>{
        ..._bearerHeaders(session.accessToken!),
        'Content-Type': 'application/octet-stream',
        'Dropbox-API-Arg': jsonEncode(<String, dynamic>{
          'path': '/${p.basename(file.path)}',
          'mode': 'overwrite',
          'autorename': false,
          'mute': false,
          'strict_conflict': false,
        }),
      },
      body: bytes,
    );
    final json = _decodeJsonResponse(
      response,
      provider: CloudProvider.dropbox,
    );
    return CloudRemoteFile(
      provider: CloudProvider.dropbox,
      id: json['path_lower'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? p.basename(file.path),
      size: (json['size'] as num?)?.toInt() ?? bytes.length,
      modifiedAt:
          DateTime.tryParse(json['client_modified']?.toString() ?? ''),
    );
  }

  Future<CloudRemoteFile> _uploadBoxFile(File file) async {
    final session = await _ensureFreshSession(CloudProvider.box);
    final folderId = await _ensureBoxFolderId(session);
    final existing = await _findBoxFileId(
      session.accessToken!,
      folderId,
      p.basename(file.path),
    );

    final uri = Uri.parse(
      existing == null
          ? 'https://upload.box.com/api/2.0/files/content'
          : 'https://upload.box.com/api/2.0/files/$existing/content',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_bearerHeaders(session.accessToken!))
      ..fields['attributes'] = jsonEncode(<String, dynamic>{
        'name': p.basename(file.path),
        if (existing == null) 'parent': <String, dynamic>{'id': folderId},
      })
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode >= 300) {
      throw CloudStorageException(
        'Box upload failed (${streamed.statusCode}). ${_extractErrorMessage(body)}',
      );
    }
    final Map<String, dynamic> json = body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(body) as Map<String, dynamic>;
    final entries = (json['entries'] as List<dynamic>? ?? <dynamic>[]);
    final item = entries.isEmpty
        ? <String, dynamic>{}
        : entries.first as Map<String, dynamic>;
    return CloudRemoteFile(
      provider: CloudProvider.box,
      id: item['id'] as String? ?? existing ?? '',
      name: item['name'] as String? ?? p.basename(file.path),
      size: (item['size'] as num?)?.toInt() ?? await file.length(),
      modifiedAt: DateTime.tryParse(item['modified_at']?.toString() ?? ''),
    );
  }

  Future<String> _downloadGoogleDriveFile(CloudRemoteFile file) async {
    final headers = await _googleHeaders(promptIfNecessary: true);
    final response = await _httpClient.get(
      Uri.parse('https://www.googleapis.com/drive/v3/files/${file.id}?alt=media'),
      headers: headers,
    );
    if (response.statusCode >= 300) {
      throw CloudStorageException(
        'Google Drive download failed (${response.statusCode}). ${_extractErrorMessage(response.body)}',
      );
    }
    return _writeDownloadedFile(file.provider, file.name, response.bodyBytes);
  }

  Future<String> _downloadOneDriveFile(CloudRemoteFile file) async {
    final session = await _ensureFreshSession(CloudProvider.oneDrive);
    final response = await _httpClient.get(
      Uri.parse('https://graph.microsoft.com/v1.0/me/drive/items/${file.id}/content'),
      headers: _bearerHeaders(session.accessToken!),
    );
    if (response.statusCode >= 300) {
      throw CloudStorageException(
        'OneDrive download failed (${response.statusCode}). ${_extractErrorMessage(response.body)}',
      );
    }
    return _writeDownloadedFile(file.provider, file.name, response.bodyBytes);
  }

  Future<String> _downloadDropboxFile(CloudRemoteFile file) async {
    final session = await _ensureFreshSession(CloudProvider.dropbox);
    final response = await _httpClient.post(
      Uri.parse('https://content.dropboxapi.com/2/files/download'),
      headers: <String, String>{
        ..._bearerHeaders(session.accessToken!),
        'Dropbox-API-Arg': jsonEncode(<String, dynamic>{'path': file.id}),
      },
    );
    if (response.statusCode >= 300) {
      throw CloudStorageException(
        'Dropbox download failed (${response.statusCode}). ${_extractErrorMessage(response.body)}',
      );
    }
    return _writeDownloadedFile(file.provider, file.name, response.bodyBytes);
  }

  Future<String> _downloadBoxFile(CloudRemoteFile file) async {
    final session = await _ensureFreshSession(CloudProvider.box);
    final response = await _httpClient.get(
      Uri.parse('https://api.box.com/2.0/files/${file.id}/content'),
      headers: _bearerHeaders(session.accessToken!),
    );
    if (response.statusCode >= 300) {
      throw CloudStorageException(
        'Box download failed (${response.statusCode}). ${_extractErrorMessage(response.body)}',
      );
    }
    return _writeDownloadedFile(file.provider, file.name, response.bodyBytes);
  }

  Future<Map<String, dynamic>> _fetchOneDriveProfile(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse(
        'https://graph.microsoft.com/v1.0/me?\$select=displayName,mail,userPrincipalName',
      ),
      headers: _bearerHeaders(accessToken),
    );
    return _decodeJsonResponse(response, provider: CloudProvider.oneDrive);
  }

  Future<Map<String, dynamic>> _fetchDropboxProfile(String accessToken) async {
    final response = await _httpClient.post(
      Uri.parse('https://api.dropboxapi.com/2/users/get_current_account'),
      headers: <String, String>{
        ..._bearerHeaders(accessToken),
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    return _decodeJsonResponse(response, provider: CloudProvider.dropbox);
  }

  Future<Map<String, dynamic>> _fetchBoxProfile(String accessToken) async {
    final response = await _httpClient.get(
      Uri.parse('https://api.box.com/2.0/users/me'),
      headers: _bearerHeaders(accessToken),
    );
    return _decodeJsonResponse(response, provider: CloudProvider.box);
  }

  Future<CloudSession> _ensureFreshSession(CloudProvider provider) async {
    final current = _requireSession(provider);
    if (!current.isExpired || !current.hasRefreshToken) {
      return current;
    }

    return switch (provider) {
      CloudProvider.oneDrive => _refreshOneDriveSession(current),
      CloudProvider.dropbox => _refreshDropboxSession(current),
      CloudProvider.box => _refreshBoxSession(current),
      CloudProvider.googleDrive => current,
    };
  }

  Future<CloudSession> _refreshOneDriveSession(CloudSession session) async {
    final discoveryUrl =
        'https://login.microsoftonline.com/${CloudEnvironment.microsoftTenantId}/v2.0/.well-known/openid-configuration';
    final TokenResponse response = await _appAuth.token(
      TokenRequest(
        CloudEnvironment.microsoftClientId,
        CloudEnvironment.appAuthRedirectUri,
        discoveryUrl: discoveryUrl,
        scopes: _oneDriveScopes,
        refreshToken: session.refreshToken,
      ),
    );
    final refreshed = session.copyWith(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken ?? session.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
    _sessions[CloudProvider.oneDrive] = refreshed;
    await _persistSession(refreshed);
    return refreshed;
  }

  Future<CloudSession> _refreshDropboxSession(CloudSession session) async {
    final TokenResponse response = await _appAuth.token(
      TokenRequest(
        CloudEnvironment.dropboxClientId,
        CloudEnvironment.appAuthRedirectUri,
        serviceConfiguration: _dropboxServiceConfiguration,
        refreshToken: session.refreshToken,
        scopes: _dropboxScopes,
      ),
    );
    final refreshed = session.copyWith(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken ?? session.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
    _sessions[CloudProvider.dropbox] = refreshed;
    await _persistSession(refreshed);
    return refreshed;
  }

  Future<CloudSession> _refreshBoxSession(CloudSession session) async {
    final response = await _httpClient.post(
      Uri.parse('https://api.box.com/oauth2/token'),
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': session.refreshToken ?? '',
        'client_id': CloudEnvironment.boxClientId,
        'client_secret': CloudEnvironment.boxClientSecret,
      },
    );
    final json = _decodeJsonResponse(response, provider: CloudProvider.box);
    final refreshed = session.copyWith(
      accessToken: json['access_token'] as String?,
      refreshToken: json['refresh_token'] as String? ?? session.refreshToken,
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
      ),
    );
    _sessions[CloudProvider.box] = refreshed;
    await _persistSession(refreshed);
    return refreshed;
  }

  Future<_LoopbackTokenResult> _authorizeBoxWithLoopback() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: server.port,
      path: '/callback',
    );
    final state = _randomUrlSafeString(24);
    final authUri = Uri.parse(
      'https://account.box.com/api/oauth2/authorize',
    ).replace(
      queryParameters: <String, String>{
        'response_type': 'code',
        'client_id': CloudEnvironment.boxClientId,
        'redirect_uri': redirectUri.toString(),
        'state': state,
      },
    );

    if (!await launchUrl(authUri, mode: LaunchMode.externalApplication)) {
      await server.close(force: true);
      throw const CloudStorageException(
        'Could not open the browser for Box sign-in.',
      );
    }

    try {
      final HttpRequest request = await server.first.timeout(
        const Duration(minutes: 3),
      );
      final code = request.uri.queryParameters['code'];
      final returnedState = request.uri.queryParameters['state'];
      final error = request.uri.queryParameters['error'];
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<html><body><h2>PDF Editor Pro</h2><p>You can return to the app now.</p></body></html>',
      );
      await request.response.close();

      if (error != null && error.isNotEmpty) {
        throw CloudStorageException('Box sign-in failed: $error');
      }
      if (code == null || code.isEmpty || returnedState != state) {
        throw const CloudStorageException(
          'Box sign-in could not be completed safely.',
        );
      }

      final tokenResponse = await _httpClient.post(
        Uri.parse('https://api.box.com/oauth2/token'),
        headers: const <String, String>{
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: <String, String>{
          'grant_type': 'authorization_code',
          'code': code,
          'client_id': CloudEnvironment.boxClientId,
          'client_secret': CloudEnvironment.boxClientSecret,
          'redirect_uri': redirectUri.toString(),
        },
      );
      final json = _decodeJsonResponse(tokenResponse, provider: CloudProvider.box);
      return _LoopbackTokenResult(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String?,
        expiresAt: DateTime.now().add(
          Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
        ),
      );
    } on TimeoutException {
      throw const CloudStorageException('Box sign-in timed out. Please try again.');
    } finally {
      await server.close(force: true);
    }
  }

  Future<String> _ensureGoogleDriveFolder(
    Map<String, String> headers, {
    CloudSession? currentSession,
  }) async {
    final current = currentSession ?? _sessions[CloudProvider.googleDrive];
    final cachedFolderId = current?.metadata['folderId'];
    if (cachedFolderId != null && cachedFolderId.isNotEmpty) {
      return cachedFolderId;
    }

    final escapedName = CloudEnvironment.appFolderName.replaceAll("'", "\\'");
    final query = Uri.encodeQueryComponent(
      "name='$escapedName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
    );
    final searchResponse = await _httpClient.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)&spaces=drive',
      ),
      headers: headers,
    );
    final searchJson = _decodeJsonResponse(
      searchResponse,
      provider: CloudProvider.googleDrive,
    );
    final files = (searchJson['files'] as List<dynamic>? ?? <dynamic>[]);
    if (files.isNotEmpty) {
      final folderId = (files.first as Map<String, dynamic>)['id'] as String;
      await _updateGoogleFolderId(folderId);
      return folderId;
    }

    final createResponse = await _httpClient.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: <String, String>{
        ...headers,
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(<String, dynamic>{
        'name': CloudEnvironment.appFolderName,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    final createJson = _decodeJsonResponse(
      createResponse,
      provider: CloudProvider.googleDrive,
    );
    final folderId = createJson['id'] as String?;
    if (folderId == null || folderId.isEmpty) {
      throw const CloudStorageException(
        'Google Drive folder could not be created.',
      );
    }
    await _updateGoogleFolderId(folderId);
    return folderId;
  }

  Future<String?> _findGoogleDriveFileId(
    Map<String, String> headers,
    String folderId,
    String fileName,
  ) async {
    final escapedName = fileName.replaceAll("'", "\\'");
    final query = Uri.encodeQueryComponent(
      "'$folderId' in parents and name='$escapedName' and trashed=false",
    );
    final response = await _httpClient.get(
      Uri.parse(
        'https://www.googleapis.com/drive/v3/files?q=$query&fields=files(id,name)',
      ),
      headers: headers,
    );
    final json = _decodeJsonResponse(response, provider: CloudProvider.googleDrive);
    final files = (json['files'] as List<dynamic>? ?? <dynamic>[]);
    if (files.isEmpty) {
      return null;
    }
    return (files.first as Map<String, dynamic>)['id'] as String?;
  }

  Future<void> _updateGoogleFolderId(String folderId) async {
    final current = _sessions[CloudProvider.googleDrive];
    if (current == null) {
      return;
    }
    final updated = current.copyWith(
      metadata: <String, String>{...current.metadata, 'folderId': folderId},
    );
    _sessions[CloudProvider.googleDrive] = updated;
    await _persistSession(updated);
  }

  Future<String> _ensureBoxFolderId(CloudSession session) async {
    final existing = session.metadata['folderId'];
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final response = await _httpClient.get(
      Uri.parse(
        'https://api.box.com/2.0/folders/0/items?limit=1000&fields=id,name,type',
      ),
      headers: _bearerHeaders(session.accessToken!),
    );
    final json = _decodeJsonResponse(response, provider: CloudProvider.box);
    final entries =
        (json['entries'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>();
    for (final item in entries) {
      if (item['type'] == 'folder' &&
          item['name'] == CloudEnvironment.appFolderName) {
        final folderId = item['id'] as String;
        final updated = session.copyWith(
          metadata: <String, String>{...session.metadata, 'folderId': folderId},
        );
        _sessions[CloudProvider.box] = updated;
        await _persistSession(updated);
        return folderId;
      }
    }

    final createResponse = await _httpClient.post(
      Uri.parse('https://api.box.com/2.0/folders'),
      headers: <String, String>{
        ..._bearerHeaders(session.accessToken!),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'name': CloudEnvironment.appFolderName,
        'parent': <String, String>{'id': '0'},
      }),
    );
    final createJson = _decodeJsonResponse(
      createResponse,
      provider: CloudProvider.box,
    );
    final folderId = createJson['id'] as String?;
    if (folderId == null || folderId.isEmpty) {
      throw const CloudStorageException('Box app folder could not be created.');
    }
    final updated = session.copyWith(
      metadata: <String, String>{...session.metadata, 'folderId': folderId},
    );
    _sessions[CloudProvider.box] = updated;
    await _persistSession(updated);
    return folderId;
  }

  Future<String?> _findBoxFileId(
    String accessToken,
    String folderId,
    String fileName,
  ) async {
    final response = await _httpClient.get(
      Uri.parse(
        'https://api.box.com/2.0/folders/$folderId/items?limit=1000&fields=id,name,type',
      ),
      headers: _bearerHeaders(accessToken),
    );
    final json = _decodeJsonResponse(response, provider: CloudProvider.box);
    final entries =
        (json['entries'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>();
    for (final item in entries) {
      if (item['type'] == 'file' && item['name'] == fileName) {
        return item['id'] as String?;
      }
    }
    return null;
  }

  Future<Map<String, String>> _googleHeaders({
    required bool promptIfNecessary,
  }) async {
    final account = _googleUser;
    if (account == null) {
      throw const CloudStorageException('Google account is not connected.');
    }
    final headers = await account.authorizationClient.authorizationHeaders(
      _googleDriveScopes,
      promptIfNecessary: promptIfNecessary,
    );
    if (headers == null) {
      throw const CloudStorageException(
        'Google Drive permission was not granted.',
      );
    }
    return headers;
  }

  CloudSession _requireSession(CloudProvider provider) {
    final session = _sessions[provider];
    if (session == null) {
      throw CloudStorageException(
        '${provider.displayName} is not connected yet.',
      );
    }
    return session;
  }

  Future<void> _persistSession(CloudSession session) {
    return _secureStorage.write(
      key: _storageKeyFor(session.provider),
      value: jsonEncode(session.toJson()),
    );
  }

  String _storageKeyFor(CloudProvider provider) =>
      'cloud_session_${provider.storageKey}';

  Map<String, String> _bearerHeaders(String accessToken) {
    return <String, String>{'Authorization': 'Bearer $accessToken'};
  }

  Map<String, dynamic> _decodeJsonResponse(
    http.Response response, {
    required CloudProvider provider,
  }) {
    final body = response.body;
    if (response.statusCode >= 300) {
      throw CloudStorageException(
        '${provider.displayName} request failed (${response.statusCode}). ${_extractErrorMessage(body)}',
      );
    }
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{'value': decoded};
  }

  String _extractErrorMessage(String body) {
    if (body.isEmpty) {
      return 'No additional details were returned.';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error_description'] != null) {
          return decoded['error_description'].toString();
        }
        final error = decoded['error'];
        if (error is Map<String, dynamic> && error['message'] != null) {
          return error['message'].toString();
        }
        if (error != null) {
          return error.toString();
        }
        if (decoded['message'] != null) {
          return decoded['message'].toString();
        }
      }
    } catch (_) {
      // Fall back to the raw body.
    }
    return body;
  }

  Future<String> _writeDownloadedFile(
    CloudProvider provider,
    String fileName,
    List<int> bytes,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final providerDir = Directory(
      p.join(docsDir.path, 'cloud_downloads', provider.storageKey),
    );
    await providerDir.create(recursive: true);
    final file = File(p.join(providerDir.path, _safePdfFileName(fileName)));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  String _safePdfFileName(String input) {
    final sanitized =
        input.replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'document.pdf';
    }
    return sanitized.toLowerCase().endsWith('.pdf')
        ? sanitized
        : '$sanitized.pdf';
  }

  String _randomUrlSafeString(int length) {
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  @visibleForTesting
  String generateCodeChallenge(String verifier) {
    final bytes = sha256.convert(ascii.encode(verifier)).bytes;
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _googleSignInMessage(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Google sign-in was canceled before the account connection finished.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google Drive setup is incomplete for Android. Add GOOGLE_SERVER_CLIENT_ID using your Google Web OAuth client and make sure package name plus signing SHA values are registered in Google Cloud.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Play Services or the Google Sign-In provider is not configured correctly on this device.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in UI could not be opened on this device right now. Try again after reopening the screen.',
      GoogleSignInExceptionCode.interrupted =>
        'Google sign-in was interrupted. Please try again.',
      GoogleSignInExceptionCode.userMismatch =>
        'Google sign-in returned a different account state than expected. Disconnect and try again.',
      GoogleSignInExceptionCode.unknownError =>
        error.description?.trim().isNotEmpty == true
            ? 'Google sign-in failed: ${error.description}'
            : 'Google sign-in failed for an unknown reason.',
    };
  }
}

class _LoopbackTokenResult {
  const _LoopbackTokenResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;
}
