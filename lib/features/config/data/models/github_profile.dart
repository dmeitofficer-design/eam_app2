class GitHubProfile {
  final String username;
  final String displayName;
  final String avatarUrl;

  const GitHubProfile({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory GitHubProfile.fromJson(Map<String, dynamic> json) {
    return GitHubProfile(
      username: json['login'] ?? '',
      displayName: json['name'] ?? json['login'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
    );
  }
}