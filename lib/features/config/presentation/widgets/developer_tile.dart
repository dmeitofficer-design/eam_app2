import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/models/github_profile.dart';
import '../../data/repositories/github_repository.dart';
import 'package:url_launcher/url_launcher.dart';
class DeveloperTile extends StatelessWidget {
  const DeveloperTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = ThemeController.isDarkMode;

    return FutureBuilder<GitHubProfile?>(
      future: GitHubRepository().getDeveloperProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 2,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
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
              borderRadius: AppRadius.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: profile != null
                          ? Image.network(
                              profile.avatarUrl,
                              width: 24,
                              height: 24,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                Icons.person,
                                size: 20,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.displayName ??
                                'Loading...',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors
                                      .lightTextSecondary,
                            ),
                          ),
                          Text(
                            'visit developer',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}