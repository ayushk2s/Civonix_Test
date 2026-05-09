class LeaderboardEntryEntity {
  final int rank;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? country;
  final double? roi30d;
  final double? sharpeRatio;
  final double? winRate;
  final double? totalPnlUsd;
  final int winningStreak;
  final double? consistencyScore;

  const LeaderboardEntryEntity({
    required this.rank,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.country,
    this.roi30d,
    this.sharpeRatio,
    this.winRate,
    this.totalPnlUsd,
    required this.winningStreak,
    this.consistencyScore,
  });

  String get displayNameOrUsername => displayName ?? username;
  bool get isPositive => (roi30d ?? 0) >= 0;
}

class LeaderboardEntity {
  final String scope;
  final String scopeValue;
  final int totalParticipants;
  final int? yourRank;
  final List<LeaderboardEntryEntity> entries;

  const LeaderboardEntity({
    required this.scope,
    required this.scopeValue,
    required this.totalParticipants,
    this.yourRank,
    required this.entries,
  });
}
