import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/github_profile.dart';

class GitHubRepository {
  static const _githubUsername = 'firefish46';

  static const _nameKey = 'github_name';
  static const _avatarKey = 'github_avatar';
  static const _timestampKey = 'github_timestamp';

  Future<GitHubProfile?> getDeveloperProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedName = prefs.getString(_nameKey);
    final cachedAvatar = prefs.getString(_avatarKey);
    final cachedTimestamp = prefs.getInt(_timestampKey);

    final now = DateTime.now().millisecondsSinceEpoch;

    // Use cache for 24 hours
    if (cachedName != null &&
        cachedAvatar != null &&
        cachedTimestamp != null &&
        now - cachedTimestamp <
            const Duration(hours: 24).inMilliseconds) {
      return GitHubProfile(
        username: _githubUsername,
        displayName: cachedName,
        avatarUrl: cachedAvatar,
      );
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/users/$_githubUsername',
        ),
        headers: {
          'Accept': 'application/vnd.github+json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final profile = GitHubProfile.fromJson(data);

        await prefs.setString(
          _nameKey,
          profile.displayName,
        );

        await prefs.setString(
          _avatarKey,
          profile.avatarUrl,
        );

        await prefs.setInt(
          _timestampKey,
          now,
        );

        return profile;
      }
    } catch (_) {}

    // Fallback to cache
    if (cachedName != null && cachedAvatar != null) {
      return GitHubProfile(
        username: _githubUsername,
        displayName: cachedName,
        avatarUrl: cachedAvatar,
      );
    }

    return null;
  }
}