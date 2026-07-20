import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/models/github_profile.dart';
import '../../data/repositories/github_repository.dart';

class DeveloperFooter extends StatelessWidget {
  const DeveloperFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;

    return FutureBuilder<GitHubProfile?>(
      future: GitHubRepository().getDeveloperProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return InkWell(
          onTap: () async {
            final url = Uri.parse(
              'https://github.com/${profile?.username ?? "firefish46"}',
            );

            if (await canLaunchUrl(url)) {
              await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              );
            }
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.dividerTheme.color ??
                          AppColors.surface3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 11,
                    backgroundImage: profile != null
                        ? NetworkImage(profile.avatarUrl)
                        : null,
                    child: profile == null
                        ? const Icon(Icons.person, size: 12)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),

                Text(
                  profile?.displayName ??
                      profile?.username ??
                      'Developer',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}