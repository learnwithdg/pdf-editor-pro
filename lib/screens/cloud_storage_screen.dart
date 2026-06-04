import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../blocs/pdf_bloc.dart';
import '../blocs/pdf_event.dart';
import '../models/cloud_storage_models.dart';
import '../services/ads_service.dart';
import '../services/cloud_environment.dart';
import '../services/cloud_storage_service.dart';
import '../utils/app_error_formatter.dart';
import '../utils/app_feedback.dart';
import '../widgets/ad_widgets.dart';

class CloudStorageScreen extends StatefulWidget {
  const CloudStorageScreen({super.key});

  @override
  State<CloudStorageScreen> createState() => _CloudStorageScreenState();
}

class _CloudStorageScreenState extends State<CloudStorageScreen> {
  final CloudStorageService _service = CloudStorageService.instance;
  final Set<CloudProvider> _busyProviders = <CloudProvider>{};
  static const List<CloudProvider> _visibleProviders = <CloudProvider>[
    CloudProvider.googleDrive,
    CloudProvider.dropbox,
  ];

  bool _isLoading = true;
  CloudProvider? _expandedProvider;
  String? _loadNotice;

  @override
  void initState() {
    super.initState();
    AdsService().registerScreenVisit();
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    try {
      await _service.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadNotice = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadNotice = AppErrorFormatter.format(
          error,
          fallback: 'Cloud status could not be checked right now.',
        );
      });
    }
  }

  List<CloudProviderStatus> get _statuses =>
      _visibleProviders.map(_service.statusFor).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Hub', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildHeroCard(context),
                      const SizedBox(height: 14),
                      _buildSignalBar(context),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        'Connected Workspaces',
                        'Sign in with your own cloud account and manage synced PDFs in one place.',
                      ),
                      if (_loadNotice != null) ...[
                        const SizedBox(height: 12),
                        _buildInlineNotice(context, _loadNotice!),
                      ],
                      const SizedBox(height: 14),
                      ..._statuses.map((status) => _buildProviderCard(context, status)),
                      const SizedBox(height: 20),
                      const SmartNativeAd(isSmall: false),
                      const SizedBox(height: 40),
                      _buildSecurityNote(context),
                    ],
                  ),
                ),
                const SmartBannerAd(),
              ],
            ),
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D3F4D), Color(0xFF0D2027)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.16),
            blurRadius: 22,
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
                Icon(Icons.cloud_done_rounded, color: Colors.amberAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'PRIVATE FILE ACCESS',
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
          const Icon(Icons.cloud_sync_rounded, size: 34, color: Colors.white),
          const SizedBox(height: 14),
          const Text(
            'Sync PDFs beautifully across Google Drive and Dropbox.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your own account, browse remote files, upload fresh documents, and open synced PDFs instantly.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.76), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          Expanded(
            child: _CloudMetricChip(
              icon: Icons.verified_user_rounded,
              title: 'Secure',
              subtitle: 'OAuth sign-in flow',
            ),
          ),
          Expanded(
            child: _CloudMetricChip(
              icon: Icons.upload_file_rounded,
              title: 'Upload',
              subtitle: 'Sync PDFs quickly',
            ),
          ),
          Expanded(
            child: _CloudMetricChip(
              icon: Icons.folder_copy_rounded,
              title: 'Browse',
              subtitle: 'Open remote files',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, String subtitle) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.35),
        ),
      ],
    );
  }

  Widget _buildSecurityNote(BuildContext context) {
    final theme = Theme.of(context);
    final message = CloudEnvironment.requiresGoogleServerClientId
        ? 'Cloud credentials come from build-time dart-defines. On Android, Google Drive needs GOOGLE_SERVER_CLIENT_ID from a Google Web OAuth client, while Dropbox uses DROPBOX_CLIENT_ID.'
        : 'Cloud credentials are loaded from build-time dart-defines for Google Drive and Dropbox setup.';
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildInlineNotice(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: theme.colorScheme.onErrorContainer,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, CloudProviderStatus status) {
    final provider = status.provider;
    final session = status.session;
    final busy = _busyProviders.contains(provider);
    final expanded = _expandedProvider == provider || session != null;
    final theme = Theme.of(context);

    final color = _providerColor(provider);
    final subtitle = !status.isConfigured
        ? 'Setup required'
        : session == null
            ? 'Disconnected'
            : session.accountEmail;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedProvider = expanded ? null : provider;
          });
        },
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.22),
                          color.withValues(alpha: 0.07),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(_providerIcon(provider), color: color, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: !status.isConfigured
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (session == null) ...[
                          const SizedBox(height: 6),
                          Text(
                            provider.shortDescription,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  else if (!status.isConfigured)
                    FilledButton.tonal(
                      onPressed: () => _showSetupSheet(provider),
                      child: const Text('Setup'),
                    )
                  else if (session == null)
                    FilledButton.tonal(
                      onPressed: () => _handleConnect(provider),
                      child: const Text('Connect'),
                    )
                  else
                    FilledButton.tonal(
                      onPressed: () {
                        setState(() {
                          _expandedProvider = expanded ? null : provider;
                        });
                      },
                      child: Text(expanded ? 'Hide' : 'Manage'),
                    ),
                ],
              ),
              if (status.warning != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status.warning!,
                    style: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              if (expanded && session != null) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ProviderTag(
                      label: status.isConfigured ? 'Configured' : 'Setup needed',
                      color: status.isConfigured
                          ? theme.colorScheme.tertiaryContainer
                          : theme.colorScheme.errorContainer,
                      textColor: status.isConfigured
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                    _ProviderTag(
                      label: session.accountName,
                      color: theme.colorScheme.surfaceContainerHigh,
                      textColor: theme.colorScheme.onSurface,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _handleUpload(provider),
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Upload PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _handleBrowse(provider),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Browse PDFs'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _handleDisconnect(provider),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConnect(CloudProvider provider) async {
    await _runProviderTask(provider, () async {
      await _service.connect(provider);
      if (!mounted) {
        return;
      }
      setState(() {
        _expandedProvider = provider;
      });
      AppFeedback.showSuccess(
        context,
        '${provider.displayName} is connected and ready for PDF sync.',
      );
    });
  }

  Future<void> _handleDisconnect(CloudProvider provider) async {
    await _runProviderTask(provider, () async {
      await _service.disconnect(provider);
      if (!mounted) {
        return;
      }
      setState(() {
        if (_expandedProvider == provider) {
          _expandedProvider = null;
        }
      });
      AppFeedback.showInfo(
        context,
        '${provider.displayName} has been disconnected from this device.',
      );
    });
  }

  Future<void> _handleUpload(CloudProvider provider) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }

    await _runProviderTask(provider, () async {
      final uploaded = await _service.uploadPdf(provider, path);
      if (!mounted) {
        return;
      }
      AppFeedback.showSuccess(
        context,
        '${uploaded.name} is now available in ${provider.displayName}.',
      );
    });
  }

  Future<void> _handleBrowse(CloudProvider provider) async {
    await _runProviderTask(provider, () async {
      final files = await _service.listPdfFiles(provider);
      if (!mounted) {
        return;
      }
      await _showFilesSheet(provider, files);
    });
  }

  Future<void> _showFilesSheet(CloudProvider provider, List<CloudRemoteFile> files) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    '${provider.displayName} PDFs',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (files.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No PDFs found yet. Upload a PDF to sync it here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: files.length,
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                          ),
                          title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_formatFileMeta(file)),
                          trailing: TextButton(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await _openRemotePdf(file);
                            },
                            child: const Text('Open'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openRemotePdf(CloudRemoteFile file) async {
    await _runProviderTask(file.provider, () async {
      final path = await _service.downloadPdf(file);
      if (!mounted) {
        return;
      }
      context.read<PdfBloc>().add(LoadPdfEvent(path));
      Navigator.pop(context);
    });
  }

  Future<void> _runProviderTask(
    CloudProvider provider,
    Future<void> Function() action,
  ) async {
    setState(() {
      _busyProviders.add(provider);
    });
    try {
      await action();
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppFeedback.showError(
        context,
        error,
        fallback: 'Something went wrong while working with the cloud provider.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyProviders.remove(provider);
        });
      }
    }
  }

  Future<void> _showSetupSheet(CloudProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.displayName} Setup',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text(
                  CloudEnvironment.missingConfigurationMessage(provider),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _setupDetails(provider),
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _setupDetails(CloudProvider provider) {
    return switch (provider) {
      CloudProvider.googleDrive =>
        'Build define: GOOGLE_SERVER_CLIENT_ID\nUse your Google Web OAuth client ID for Android sign-in.\nAndroid package: com.pdfediter.pro\nOAuth API: Google Drive API\nAdd both release and debug signing SHA values in Google Cloud for this Android app.',
      CloudProvider.oneDrive =>
        'Build define: MICROSOFT_CLIENT_ID\nOptional: MICROSOFT_TENANT_ID\nRedirect URI: ${CloudEnvironment.appAuthRedirectUri}\nPermissions: Files.ReadWrite.AppFolder, User.Read, offline_access, openid, profile',
      CloudProvider.dropbox =>
        'Build define: DROPBOX_CLIENT_ID\nRedirect URI: ${CloudEnvironment.appAuthRedirectUri}\nScopes: files.metadata.read, files.content.read, files.content.write, account_info.read\nEnable offline access / refresh tokens in the Dropbox app settings.',
      CloudProvider.box =>
        'Build defines: BOX_CLIENT_ID and BOX_CLIENT_SECRET\nRedirect URI pattern: ${CloudEnvironment.boxLoopbackRedirectBase}\nNote: production Box auth should move token exchange to your backend because a client secret inside a mobile app is not secure.',
    };
  }

  String _formatFileMeta(CloudRemoteFile file) {
    final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(2);
    final date = file.modifiedAt == null ? 'Unknown date' : DateFormat('dd MMM yyyy').format(file.modifiedAt!);
    return '$sizeMb MB | $date';
  }

  IconData _providerIcon(CloudProvider provider) {
    return switch (provider) {
      CloudProvider.googleDrive => Icons.add_to_drive_rounded,
      CloudProvider.oneDrive => Icons.cloud_queue_rounded,
      CloudProvider.dropbox => Icons.cloud_circle_rounded,
      CloudProvider.box => Icons.archive_rounded,
    };
  }

  Color _providerColor(CloudProvider provider) {
    return switch (provider) {
      CloudProvider.googleDrive => Colors.blue,
      CloudProvider.oneDrive => Colors.blue.shade400,
      CloudProvider.dropbox => Colors.blue.shade800,
      CloudProvider.box => Colors.blue.shade900,
    };
  }

}

class _CloudMetricChip extends StatelessWidget {
  const _CloudMetricChip({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

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
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProviderTag extends StatelessWidget {
  const _ProviderTag({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
