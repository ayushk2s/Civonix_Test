import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/leaderboard_entry.dart';
import '../../viewmodels/leaderboard_viewmodel.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(leaderboardViewModelProvider.notifier).load());
  }

  static const _scopes = ['district', 'state', 'country', 'global'];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaderboardViewModelProvider);
    final lb = state.leaderboard;
    final entries = lb?.entries ?? [];
    final myRank = lb?.yourRank;
    final myEntry = myRank != null
        ? entries.where((e) => e.rank == myRank).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: 8),
            child: Row(
              children: _scopes.map((scope) {
                final selected = state.scope == scope;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(leaderboardViewModelProvider.notifier)
                        .load(scope: scope),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surfaceHigh,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        scope[0].toUpperCase() + scope.substring(1),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(leaderboardViewModelProvider.notifier)
            .load(scope: state.scope),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : entries.isEmpty
                ? const Center(
                    child: Text('No data yet',
                        style: TextStyle(color: AppColors.textMuted)))
                : CustomScrollView(
                    slivers: [
                      if (myEntry != null)
                        SliverToBoxAdapter(
                          child: _MyRankBanner(entry: myEntry),
                        ),

                      if (entries.length >= 3)
                        SliverToBoxAdapter(
                          child: _Podium(
                              entries: entries.take(3).toList()),
                        ),

                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _RankRow(
                              entry: entries[i],
                              isMe: myEntry != null &&
                                  entries[i].rank == myEntry.rank,
                            ).animate().fadeIn(
                                delay: Duration(milliseconds: i * 30)),
                            childCount: entries.length,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 80)),
                    ],
                  ),
      ),
    );
  }
}

class _MyRankBanner extends StatelessWidget {
  final LeaderboardEntryEntity entry;
  const _MyRankBanner({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.md),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          const Text('Your Rank',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const Spacer(),
          Text(
            '#${entry.rank}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.pct(entry.roi30d ?? 0),
                style: TextStyle(
                  color: entry.isPositive ? AppColors.gain : AppColors.loss,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'score ${(entry.consistencyScore ?? 0).toStringAsFixed(1)}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntryEntity> entries;
  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    final gold = entries[0];
    final silver = entries.length > 1 ? entries[1] : null;
    final bronze = entries.length > 2 ? entries[2] : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (silver != null)
            Expanded(child: _PodiumSlot(entry: silver, height: 80, rank: 2)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumSlot(entry: gold, height: 100, rank: 1)),
          const SizedBox(width: 8),
          if (bronze != null)
            Expanded(child: _PodiumSlot(entry: bronze, height: 64, rank: 3)),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  final LeaderboardEntryEntity entry;
  final double height;
  final int rank;
  const _PodiumSlot(
      {required this.entry, required this.height, required this.rank});

  Color get _color {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    return const Color(0xFFCD7F32);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          entry.displayNameOrUsername,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          Fmt.pct(entry.roi30d ?? 0),
          style: TextStyle(
              color: entry.isPositive ? AppColors.gain : AppColors.loss,
              fontSize: 11,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSizes.radiusMd)),
            border: Border.all(color: _color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              rank == 1
                  ? '🥇'
                  : rank == 2
                      ? '🥈'
                      : '🥉',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  final LeaderboardEntryEntity entry;
  final bool isMe;
  const _RankRow({required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: entry.rank <= 3
                    ? const Color(0xFFFFD700)
                    : AppColors.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                entry.displayNameOrUsername.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.displayNameOrUsername,
                      style: TextStyle(
                        color: isMe
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (entry.winningStreak > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull),
                        ),
                        child: Text(
                          '🔥 ${entry.winningStreak}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Sharpe ${(entry.sharpeRatio ?? 0).toStringAsFixed(2)} · Win ${Fmt.pct(entry.winRate ?? 0)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.pct(entry.roi30d ?? 0),
                style: TextStyle(
                  color: entry.isPositive ? AppColors.gain : AppColors.loss,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                (entry.consistencyScore ?? 0).toStringAsFixed(1),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
