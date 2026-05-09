import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/portfolio.dart';
import '../../viewmodels/portfolio_viewmodel.dart';
import '../../viewmodels/news_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/charts/allocation_chart.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/metric_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(portfolioViewModelProvider.notifier).loadAll();
      ref.read(newsViewModelProvider.notifier).loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final portfolioState = ref.watch(portfolioViewModelProvider);
    final newsState = ref.watch(newsViewModelProvider);
    final authState = ref.watch(authViewModelProvider);

    if (portfolioState.isLoading && portfolioState.summary == null) {
      return const DashboardShimmer();
    }

    final summary = portfolioState.summary;

    return RefreshIndicator(
      onRefresh: () => ref.read(portfolioViewModelProvider.notifier).loadAll(),
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.background,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_greeting()},',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  authState.user?.displayNameOrUsername ?? AppStrings.appName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: AppColors.textSecondary,
                onPressed: () {},
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  color: AppColors.textSecondary,
                  onPressed: () => context.push('/settings'),
                ),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Hero Balance Card ─────────────────────────────────────
                if (summary == null)
                  _ConnectExchangeCard()
                else
                  _BalanceCard(summary: summary),

                const SizedBox(height: AppSizes.md),

                // ── Quick Metrics ─────────────────────────────────────────
                if (summary != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Daily P&L',
                          value: Fmt.usd(summary.dailyChangeUsd),
                          subtitle: Fmt.pct(summary.dailyChangePct),
                          variant: summary.isDailyPositive
                              ? MetricCardVariant.gain
                              : MetricCardVariant.loss,
                        ).animate().fadeIn(delay: 100.ms),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: MetricCard(
                          label: 'All-time P&L',
                          value: Fmt.usd(summary.totalPnlUsd),
                          subtitle: Fmt.pct(summary.totalPnlPct),
                          variant: summary.isPositive
                              ? MetricCardVariant.gain
                              : MetricCardVariant.loss,
                        ).animate().fadeIn(delay: 150.ms),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  // ── Allocation ────────────────────────────────────────
                  _SectionCard(
                    title: 'Allocation',
                    child: AllocationPieChart(holdings: summary.holdings),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: AppSizes.md),

                  // ── Holdings List ─────────────────────────────────────
                  _SectionCard(
                    title: 'Holdings',
                    trailing: TextButton(
                      onPressed: () => context.go('/portfolio'),
                      child: const Text('See all',
                          style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                    child: Column(
                      children: summary.holdings
                          .take(5)
                          .map((h) => _HoldingRow(holding: h))
                          .toList(),
                    ),
                  ).animate().fadeIn(delay: 250.ms),
                  const SizedBox(height: AppSizes.md),
                ],

                // ── News Alert ────────────────────────────────────────────
                if (newsState.portfolioAlerts.isNotEmpty) ...[
                  _SectionCard(
                    title: 'Portfolio Alerts',
                    child: Column(
                      children: newsState.portfolioAlerts.take(3).map((article) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: article.isBullish
                                  ? AppColors.gainMuted
                                  : AppColors.lossMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              article.isBullish
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: article.isBullish
                                  ? AppColors.gain
                                  : AppColors.loss,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            article.title,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            article.portfolioImpact ?? '',
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 11),
                          ),
                          onTap: () => context.go('/news'),
                        );
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: AppSizes.md),
                ],

                // ── Connect Exchange CTA (if no accounts) ─────────────────
                if (portfolioState.accounts.isEmpty &&
                    portfolioState.summary == null)
                  _ConnectExchangeCard(),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _BalanceCard extends StatelessWidget {
  final PortfolioSummaryEntity summary;
  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
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
          const Text(
            AppStrings.totalBalance,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12,
                fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            Fmt.usd(summary.totalValueUsd),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.isDailyPositive
                      ? AppColors.gainMuted
                      : AppColors.lossMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      summary.isDailyPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: summary.isDailyPositive
                          ? AppColors.gain
                          : AppColors.loss,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${Fmt.pct(summary.dailyChangePct)} today',
                      style: TextStyle(
                        color: summary.isDailyPositive
                            ? AppColors.gain
                            : AppColors.loss,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }
}

class _ConnectExchangeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/connect-exchange'),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.accent.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_link_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AppStrings.connectExchange,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Connect an exchange to unlock analytics',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  final HoldingEntity holding;
  const _HoldingRow({required this.holding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                holding.symbol.substring(0, 1),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holding.symbol,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  Fmt.crypto(holding.quantity),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Fmt.usd(holding.valueUsd),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                Fmt.pct(holding.unrealizedPnlPct),
                style: TextStyle(
                  color: holding.isProfit ? AppColors.gain : AppColors.loss,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
