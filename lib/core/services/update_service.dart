import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final bool isMandatory;
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.isMandatory,
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
  });
}

class UpdateService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      // 1. Detect target platform
      final platform = defaultTargetPlatform.name.toLowerCase(); // 'windows', 'android', etc.
      debugPrint('🔍 [UPDATE CHECK] Detected Platform: "$platform"');

      // 2. Fetch local package info
      final packageInfo = await PackageInfo.fromPlatform();
      debugPrint('🔍 [UPDATE CHECK] Local Version: "${packageInfo.version}" | Raw Build Number: "${packageInfo.buildNumber}"');

      // 3. Parse local build number safely (Windows desktop often returns empty string or "1.0.0.0")
      int localBuildNumber = int.tryParse(packageInfo.buildNumber.replaceAll(RegExp(r'\D'), '')) ?? 0;
      if (localBuildNumber == 0) {
        // Fallback: Use last number of version string (e.g., "1.0.1" -> 1)
        final parts = packageInfo.version.split('.');
        localBuildNumber = int.tryParse(parts.last) ?? 0;
      }
      debugPrint('🔍 [UPDATE CHECK] Parsed Local Build Number: $localBuildNumber');

      // 4. Query Supabase
      final response = await _client
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('🔍 [UPDATE CHECK] Supabase Query Result: $response');

      if (response == null) {
        debugPrint('⚠️ [UPDATE CHECK] No record found in Supabase for platform "$platform".');
        return null;
      }

      final latestBuildNumber = response['build_number'] as int;
      debugPrint('🔍 [UPDATE CHECK] Supabase Build Number: $latestBuildNumber vs Local: $localBuildNumber');

      if (latestBuildNumber > localBuildNumber) {
        debugPrint('🚀 [UPDATE CHECK] Update found!');
        return AppUpdateInfo(
          hasUpdate: true,
          isMandatory: response['is_mandatory'] ?? false,
          latestVersion: response['latest_version'] as String,
          downloadUrl: response['download_url'] as String,
          releaseNotes: response['release_notes'] as String?,
        );
      } else {
        debugPrint('✅ [UPDATE CHECK] App is up to date.');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [UPDATE CHECK ERROR]: $e');
      debugPrint(stackTrace.toString());
    }
    return null;
  }

  static Future<void> launchUpdateUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}