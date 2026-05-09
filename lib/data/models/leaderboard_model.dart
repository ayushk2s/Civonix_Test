import '../../domain/entities/leaderboard_entry.dart';

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

class LeaderboardEntryModel {
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

  const LeaderboardEntryModel({
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

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> j) =>
      LeaderboardEntryModel(
        rank: (j['rank'] as num).toInt(),
        userId: j['user_id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String?,
        avatarUrl: j['avatar_url'] as String?,
        country: j['country'] as String?,
        roi30d: _d(j['roi_30d']),
        sharpeRatio: _d(j['sharpe_ratio']),
        winRate: _d(j['win_rate']),
        totalPnlUsd: _d(j['total_pnl_usd']),
        winningStreak: (j['winning_streak'] as num? ?? 0).toInt(),
        consistencyScore: _d(j['consistency_score']),
      );

  LeaderboardEntryEntity toEntity() => LeaderboardEntryEntity(
        rank: rank,
        userId: userId,
        username: username,
        displayName: displayName,
        avatarUrl: avatarUrl,
        country: country,
        roi30d: roi30d,
        sharpeRatio: sharpeRatio,
        winRate: winRate,
        totalPnlUsd: totalPnlUsd,
        winningStreak: winningStreak,
        consistencyScore: consistencyScore,
      );
}

class LeaderboardModel {
  final String scope;
  final String scopeValue;
  final int totalParticipants;
  final int? yourRank;
  final List<LeaderboardEntryModel> entries;

  const LeaderboardModel({
    required this.scope,
    required this.scopeValue,
    required this.totalParticipants,
    this.yourRank,
    required this.entries,
  });

  factory LeaderboardModel.fromJson(Map<String, dynamic> j) => LeaderboardModel(
        scope: j['scope'] as String,
        scopeValue: j['scope_value'] as String,
        totalParticipants: (j['total_participants'] as num).toInt(),
        yourRank: j['your_rank'] != null ? (j['your_rank'] as num).toInt() : null,
        entries: (j['entries'] as List)
            .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  LeaderboardEntity toEntity() => LeaderboardEntity(
        scope: scope,
        scopeValue: scopeValue,
        totalParticipants: totalParticipants,
        yourRank: yourRank,
        entries: entries.map((e) => e.toEntity()).toList(),
      );
}
