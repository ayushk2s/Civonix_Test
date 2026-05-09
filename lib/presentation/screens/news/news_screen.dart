import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/news_article.dart';
import '../../viewmodels/news_viewmodel.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});

  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(newsViewModelProvider.notifier).loadAll());
  }

  static const _filters = [
    (label: 'All', value: null),
    (label: 'Bullish', value: 'bullish'),
    (label: 'Bearish', value: 'bearish'),
    (label: 'Neutral', value: 'neutral'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newsViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Market News'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md, vertical: 8),
            child: Row(
              children: _filters.map((f) {
                final selected = state.sentimentFilter == f.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(newsViewModelProvider.notifier)
                        .setSentimentFilter(f.value),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? _filterColor(f.value)
                            : AppColors.surfaceHigh,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        f.label,
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
        onRefresh: () =>
            ref.read(newsViewModelProvider.notifier).loadAll(),
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: state.isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                slivers: [
                  // BTC Prediction Game
                  if (state.prediction != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSizes.md),
                        child: _PredictionCard(
                          prediction: state.prediction!,
                          isSubmitting: state.isSubmittingPrediction,
                          onVote: (dir) => ref
                              .read(newsViewModelProvider.notifier)
                              .submitPrediction(dir),
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                    ),

                  // Portfolio alerts header
                  if (state.portfolioAlerts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSizes.md, 0, AppSizes.md, AppSizes.sm),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${state.portfolioAlerts.length} alerts affect your portfolio',
                              style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md),
                    sliver: state.filteredArticles.isEmpty
                        ? const SliverFillRemaining(
                            child: Center(
                              child: Text('No articles found',
                                  style: TextStyle(
                                      color: AppColors.textMuted)),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => _ArticleCard(
                                article: state.filteredArticles[i],
                              )
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(
                                          milliseconds: i * 40)),
                              childCount: state.filteredArticles.length,
                            ),
                          ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
      ),
    );
  }

  Color _filterColor(String? value) {
    if (value == 'bullish') return AppColors.gain;
    if (value == 'bearish') return AppColors.loss;
    if (value == 'neutral') return AppColors.textMuted;
    return AppColors.primary;
  }
}

// ── Prediction Card ──────────────────────────────────────────────────────────

class _PredictionCard extends StatelessWidget {
  final PredictionEntity prediction;
  final bool isSubmitting;
  final void Function(String) onVote;

  const _PredictionCard({
    required this.prediction,
    required this.isSubmitting,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1F35), Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: const Text(
                  'DAILY PREDICTION',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                prediction.gameDate,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            'Will ${prediction.assetSymbol} go UP or DOWN today?',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.sm),

          // Vote bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Flexible(
                    flex: (prediction.upPct * 100).round(),
                    child: Container(color: AppColors.gain),
                  ),
                  Flexible(
                    flex: (prediction.downPct * 100).round(),
                    child: Container(color: AppColors.loss),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${Fmt.pct(prediction.upPct)} UP',
                style: const TextStyle(
                    color: AppColors.gain,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${prediction.totalVotes} votes',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
              const Spacer(),
              Text(
                'DOWN ${Fmt.pct(prediction.downPct)}',
                style: const TextStyle(
                    color: AppColors.loss,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),

          if (prediction.hasVoted)
            _VotedResult(prediction: prediction)
          else if (prediction.resolved)
            const Center(
              child: Text('Voting closed',
                  style: TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    label: 'BULL',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.gain,
                    isLoading: isSubmitting,
                    onTap: () => onVote('up'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: _VoteButton(
                    label: 'BEAR',
                    icon: Icons.trending_down_rounded,
                    color: AppColors.loss,
                    isLoading: isSubmitting,
                    onTap: () => onVote('down'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _VotedResult extends StatelessWidget {
  final PredictionEntity prediction;
  const _VotedResult({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final correct = prediction.isCorrect;
    final voted = prediction.userPrediction ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: correct == null
            ? AppColors.surfaceHigh
            : correct
                ? AppColors.gainMuted
                : AppColors.lossMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: [
          Icon(
            correct == null
                ? Icons.access_time_rounded
                : correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
            color: correct == null
                ? AppColors.textMuted
                : correct
                    ? AppColors.gain
                    : AppColors.loss,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            correct == null
                ? 'You voted ${voted.toUpperCase()} — awaiting result'
                : correct
                    ? 'Correct! You predicted ${voted.toUpperCase()}'
                    : 'Wrong — you predicted ${voted.toUpperCase()}',
            style: TextStyle(
              color: correct == null
                  ? AppColors.textSecondary
                  : correct
                      ? AppColors.gain
                      : AppColors.loss,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;

  const _VoteButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: isLoading
            ? Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Article Card ─────────────────────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final NewsArticleEntity article;
  const _ArticleCard({required this.article});

  Color get _sentimentColor {
    if (article.isBullish) return AppColors.gain;
    if (article.isBearish) return AppColors.loss;
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(article.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.sm),
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: article.affectsMyPortfolio
                ? AppColors.warning.withValues(alpha: 0.4)
                : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _sentimentColor.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSizes.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        article.isBullish
                            ? Icons.trending_up_rounded
                            : article.isBearish
                                ? Icons.trending_down_rounded
                                : Icons.remove_rounded,
                        color: _sentimentColor,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        article.sentimentLabel?.toUpperCase() ?? 'NEUTRAL',
                        style: TextStyle(
                            color: _sentimentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (article.affectsMyPortfolio) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSizes.radiusFull),
                    ),
                    child: const Text(
                      'MY PORTFOLIO',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                Text(
                  article.source,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              article.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (article.summary != null) ...[
              const SizedBox(height: 4),
              Text(
                article.summary!,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (article.portfolioImpact != null) ...[
              const SizedBox(height: 6),
              Text(
                article.portfolioImpact!,
                style: const TextStyle(
                    color: AppColors.warning, fontSize: 12),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  Fmt.timeAgo(article.publishedAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
                if (article.affectedSymbols.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ...article.affectedSymbols.take(3).map((s) => Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(
                              AppSizes.radiusFull),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      )),
                ],
                const Spacer(),
                const Icon(Icons.open_in_new_rounded,
                    size: 14, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
