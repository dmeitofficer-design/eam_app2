// lib/core/services/update_dialog.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import '../theme/app_theme.dart';
import 'update_service.dart';

/// "Update available" dialog. On Android it downloads the APK inside the app
/// and opens the system installer; elsewhere it opens the download link.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final AppUpdateInfo info;

  /// Versions the user chose "Later" for, so the splash screen and the
  /// dashboard don't both ask in the same session.
  static final Set<String> _postponed = {};

  static Future<void> show(BuildContext context, AppUpdateInfo info) async {
    if (!info.isMandatory && _postponed.contains(info.latestVersion)) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(info: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  StreamSubscription<OtaEvent>? _sub;
  double? _progress; // null = not downloading
  String? _status;
  String? _error;

  bool get _inAppInstall =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    if (!_inAppInstall) {
      UpdateService.launchUpdateUrl(widget.info.downloadUrl);
      return;
    }
    setState(() {
      _progress = 0;
      _status = 'Downloading…';
      _error = null;
    });
    try {
      _sub = OtaUpdate()
          .execute(
            widget.info.downloadUrl,
            destinationFilename: 'dme-cm-${widget.info.latestVersion}.apk',
          )
          .listen(_onEvent, onError: (Object e) => _fail('Update failed: $e'));
    } catch (e) {
      _fail('Update failed: $e');
    }
  }

  void _onEvent(OtaEvent event) {
    if (!mounted) return;
    switch (event.status) {
      case OtaStatus.DOWNLOADING:
        final percent = double.tryParse(event.value ?? '') ?? 0;
        setState(() {
          _progress = percent / 100;
          _status = 'Downloading… ${percent.toStringAsFixed(0)}%';
        });
      case OtaStatus.INSTALLING:
      case OtaStatus.INSTALLATION_DONE:
        setState(() {
          _progress = 1;
          _status = 'Opening the installer… Tap "Update" or "Install" to finish.';
        });
      case OtaStatus.ALREADY_RUNNING_ERROR:
        setState(() => _status = 'The download is already running.');
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        _fail('Allow "Install unknown apps" for DME CM in your phone settings, '
            'then tap Update again.');
      case OtaStatus.CANCELED:
        _fail('The update was cancelled.');
      case OtaStatus.DOWNLOAD_ERROR:
      case OtaStatus.CHECKSUM_ERROR:
      case OtaStatus.INSTALLATION_ERROR:
      case OtaStatus.INTERNAL_ERROR:
        _fail('Update failed (${event.status.name.toLowerCase()}). '
            'Check your connection and try again.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _progress = null;
      _status = null;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final busy = _progress != null;

    return PopScope(
      canPop: !info.isMandatory && !busy,
      child: AlertDialog(
        title: Text('Update Available (${info.latestVersion})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.releaseNotes ?? 'A new version of DME CM is available.'),
            if (info.isMandatory) ...[
              const SizedBox(height: 12),
              const Text(
                'This update is required to continue using the app.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
            if (busy) ...[
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(value: _progress == 0 ? null : _progress),
              const SizedBox(height: AppSpacing.xs),
              Text(_status ?? '', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
          ],
        ),
        actions: [
          if (!info.isMandatory && !busy)
            TextButton(
              onPressed: () {
                UpdateDialog._postponed.add(info.latestVersion);
                Navigator.pop(context);
              },
              child: const Text('Later'),
            ),
          if (_error != null && _inAppInstall)
            TextButton(
              onPressed: () => UpdateService.launchUpdateUrl(info.downloadUrl),
              child: const Text('Download in browser'),
            ),
          ElevatedButton(
            onPressed: busy && _error == null ? null : _start,
            child: Text(_error != null ? 'Try Again' : 'Update Now'),
          ),
        ],
      ),
    );
  }
}
