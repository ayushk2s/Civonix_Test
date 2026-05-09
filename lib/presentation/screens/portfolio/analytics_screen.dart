import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/analytics.dart';
import '../../viewmodels/analytics_viewmodel.dart';
import '../../widgets/charts/portfolio_chart.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/metric_card.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _periods = [30, 90, 180, 365];
  int _selectedPeriod = 365;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    Future.microtask(
        () => ref.read(analyticsViewModelProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsViewModelProvider);

    if (state.isLoading && state.analytics == null) {
      return const AnalyticsShimmer();
    }

    if (state.error != null && state.analytics == null) {
      return _ErrorState(error: state.error!, onRetry: () {
        ref.read(analyticsViewModelProvider.notifier).loadAll();
      });
    }

    final a = state.analytics;

    return NestedScrollView(
      headerSliverBuilder: (ctx, _) => [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.background,
          title: const Text('Analytics'),
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Performance'),
              Tab(text: 'Risk'),
              Tab(text: 'Trade Quality'),
              Tab(text: 'Structure'),
              Tab(text: 'Behavioral'),
            ],
          ),
        ),
      ],
      body: Column(
        children: [
          // Period selector
          _PeriodSelector(
            periods: _periods,
            selected: _selectedPeriod,
            onSelect: (p) {
              setState(() => _selectedPeriod = p);
              ref
                  .read(analyticsViewModelProvider.notifier)
                  .changePeriod(p);
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PerformanceTab(a: a, returns: state.returnSeries),
                _RiskTab(a: a),
                _TradeQualityTab(a: a),
                _StructureTab(a: a),
                _BehavioralTab(a: a),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Period Selector ────────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final List<int> periods;
  final int selected;
  final ValueChanged<int> onSelect;

  const _PeriodSelector(
      {required this.periods, required this.selected, required this.onSelect});

  String _label(int days) {
    if (days == 30) return '1M';
    if (days == 90) return '3M';
    if (days == 180) return '6M';
    return '1Y';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      child: Row(
        children: periods.map((p) {
          final active = p == selected;
          return Padding(
            padding: const EdgeInsets.only(right: AppSizes.xs),
            child: GestureDetector(
              onTap: () => onSelect(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.surfaceHigh,
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  _label(p),
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Performance Tab ─────────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  final FullAnalyticsEntity? a;
  final List<ReturnPoint> returns;
  const _PerformanceTab({this.a, required this.returns});

  @override
  Widget build(BuildContext context) {
    final p = a?.performance;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        // Chart
        if (returns.isNotEmpty) ...[
          _Card(
            title: 'Portfolio Value',
            child: SizedBox(
              height: 200,
              child: PortfolioLineChart(data: returns),
            ),
          ),
          const SizedBox(height: AppSizes.md),
        ],

        // Metrics grid
        _MetricsGrid(children: [
          MetricCard(
            label: 'Total P&L',
            value: Fmt.usd(p?.totalPnlUsd),
            variant: (p?.totalPnlUsd ?? 0) >= 0
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(
            label: 'Realized P&L',
            value: Fmt.usd(p?.realizedPnlUsd),
            variant: (p?.realizedPnlUsd ?? 0) >= 0
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(
            label: 'ROI (Monthly)',
            value: Fmt.pct(p?.roiMonthly),
            variant: (p?.roiMonthly ?? 0) >= 0
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(
            label: 'ROI (Yearly)',
            value: Fmt.pct(p?.roiYearly),
            variant: (p?.roiYearly ?? 0) >= 0
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(label: 'CAGR', value: Fmt.pct(p?.cagr)),
          MetricCard(
              label: 'All-time ROI', value: Fmt.pct(p?.roiAllTime)),
        ]),
      ],
    );
  }
}

// ── Risk Tab ────────────────────────────────────────────────────────────────────

class _RiskTab extends StatelessWidget {
  final FullAnalyticsEntity? a;
  const _RiskTab({this.a});

  @override
  Widget build(BuildContext context) {
    final r = a?.risk;
    final ra = a?.riskAdjusted;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _Card(
          title: 'Risk Metrics',
          child: Column(
            children: [
              MetricRow(
                label: 'Max Drawdown',
                value: Fmt.pct(r?.maxDrawdown),
                variant: MetricCardVariant.loss,
              ),
              const Divider(),
              MetricRow(
                  label: 'Avg Drawdown', value: Fmt.pct(r?.avgDrawdown)),
              const Divider(),
              MetricRow(
                  label: 'Volatility (Annualized)',
                  value: Fmt.pct(r?.volatilityAnnualized)),
              const Divider(),
              MetricRow(
                  label: 'Downside Deviation',
                  value: Fmt.pct(r?.downsideDeviation)),
              const Divider(),
              MetricRow(
                  label: 'VaR 95%',
                  value: Fmt.pct(r?.var95),
                  variant: MetricCardVariant.loss),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _Card(
          title: 'Risk-Adjusted Returns',
          child: Column(
            children: [
              _RatioRow(
                label: 'Sharpe Ratio',
                value: ra?.sharpeRatio,
                good: 1.0,
                great: 2.0,
              ),
              const Divider(),
              _RatioRow(
                label: 'Sortino Ratio',
                value: ra?.sortinoRatio,
                good: 1.0,
                great: 2.0,
              ),
              const Divider(),
              _RatioRow(
                label: 'Calmar Ratio',
                value: ra?.calmarRatio,
                good: 0.5,
                great: 1.0,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        _Card(
          title: 'Market Comparison',
          child: Column(
            children: [
              MetricRow(label: 'Beta vs BTC', value: Fmt.ratio(a?.market.betaVsBtc)),
              const Divider(),
              MetricRow(
                label: 'Alpha vs BTC',
                value: Fmt.pct(a?.market.alphaVsBtc),
                variant: (a?.market.alphaVsBtc ?? 0) >= 0
                    ? MetricCardVariant.gain
                    : MetricCardVariant.loss,
              ),
              const Divider(),
              MetricRow(
                  label: 'Correlation vs BTC',
                  value: Fmt.ratio(a?.market.correlationVsBtc)),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        if (a?.market.fearGreedScore != null)
          _FearGreedCard(score: a!.market.fearGreedScore!),
      ],
    );
  }
}

// ── Trade Quality Tab ───────────────────────────────────────────────────────────

class _TradeQualityTab extends StatelessWidget {
  final FullAnalyticsEntity? a;
  const _TradeQualityTab({this.a});

  @override
  Widget build(BuildContext context) {
    final tq = a?.tradeQuality;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _MetricsGrid(children: [
          MetricCard(
            label: 'Win Rate',
            value: Fmt.pct(tq?.winRate, showSign: false),
            variant: (tq?.winRate ?? 0) >= 0.5
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(
            label: 'Profit Factor',
            value: Fmt.ratio(tq?.profitFactor),
            variant: (tq?.profitFactor ?? 0) >= 1
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(
            label: 'Expectancy',
            value: Fmt.usd(tq?.expectancyUsd),
            variant: (tq?.expectancyUsd ?? 0) >= 0
                ? MetricCardVariant.gain
                : MetricCardVariant.loss,
          ),
          MetricCard(label: 'Total Trades', value: '${tq?.totalTrades ?? 0}'),
        ]),
        const SizedBox(height: AppSizes.md),
        _Card(
          title: 'Win/Loss Analysis',
          child: Column(
            children: [
              MetricRow(
                  label: 'Avg Win', value: Fmt.usd(tq?.avgWinUsd),
                  variant: MetricCardVariant.gain),
              const Divider(),
              MetricRow(
                  label: 'Avg Loss', value: Fmt.usd(tq?.avgLossUsd),
                  variant: MetricCardVariant.loss),
              const Divider(),
              MetricRow(
                  label: 'Win/Loss Ratio', value: Fmt.ratio(tq?.avgWinLossRatio)),
              const Divider(),
              MetricRow(
                  label: 'Avg Hold Time', value: Fmt.hours(tq?.avgHoldingHours)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Structure Tab ───────────────────────────────────────────────────────────────

class _StructureTab extends StatelessWidget {
  final FullAnalyticsEntity? a;
  const _StructureTab({this.a});

  @override
  Widget build(BuildContext context) {
    final s = a?.structure;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        _Card(
          title: 'Portfolio Structure',
          child: Column(
            children: [
              _ProgressMetric(
                  label: 'Diversification Score',
                  value: s?.diversificationScore ?? 0,
                  good: 0.6),
              const SizedBox(height: AppSizes.sm),
              _ProgressMetric(
                  label: 'BTC Exposure',
                  value: s?.btcExposurePct ?? 0,
                  good: 0.5,
                  inverted: true),
              const SizedBox(height: AppSizes.sm),
              _ProgressMetric(
                  label: 'ETH Exposure',
                  value: s?.ethExposurePct ?? 0,
                  good: 0.4,
                  inverted: true),
              const SizedBox(height: AppSizes.sm),
              _ProgressMetric(
                  label: 'Stablecoin %',
                  value: s?.stablecoinPct ?? 0,
                  good: 0.2),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Behavioral Tab ──────────────────────────────────────────────────────────────

class _BehavioralTab extends StatelessWidget {
  final FullAnalyticsEntity? a;
  const _BehavioralTab({this.a});

  @override
  Widget build(BuildContext context) {
    final b = a?.behavioral;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        // Discipline Score hero
        if (b?.disciplineScore != null)
          _DisciplineScoreCard(score: b!.disciplineScore!)
              .animate()
              .fadeIn(duration: 300.ms),
        const SizedBox(height: AppSizes.md),

        _Card(
          title: 'Behavioral Mistakes',
          child: Column(
            children: [
              _BehavioralRow(
                icon: Icons.refresh_rounded,
                iconColor: AppColors.loss,
                label: 'Revenge Trades',
                count: b?.revengeTradeCount ?? 0,
                lossUsd: b?.revengeTradeUsd ?? 0,
              ),
              const Divider(),
              _BehavioralRow(
                icon: Icons.trending_up_rounded,
                iconColor: AppColors.warning,
                label: 'FOMO Buys',
                count: b?.fomoTradeCount ?? 0,
                lossUsd: b?.fomoTradeUsd ?? 0,
              ),
              const Divider(),
              _BehavioralRow(
                icon: Icons.trending_down_rounded,
                iconColor: AppColors.loss,
                label: 'Panic Sells',
                count: b?.panicSellCount ?? 0,
                lossUsd: b?.panicSellUsd ?? 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),

        _Card(
          title: 'Trading Patterns',
          child: Column(
            children: [
              MetricRow(
                label: 'Overtrading Score',
                value: '${b?.overtradingScore?.toStringAsFixed(0) ?? "--"}/100',
                variant: (b?.overtradingScore ?? 0) > 50
                    ? MetricCardVariant.warning
                    : MetricCardVariant.neutral,
              ),
              const Divider(),
              MetricRow(
                  label: 'Avg Trades/Day',
                  value: b?.avgTradesPerDay?.toStringAsFixed(1) ?? '--'),
              if (b?.bestHour != null) ...[
                const Divider(),
                MetricRow(
                    label: 'Best Hour (UTC)',
                    value: '${b!.bestHour}:00',
                    variant: MetricCardVariant.gain),
                const Divider(),
                MetricRow(
                    label: 'Worst Hour (UTC)',
                    value: '${b.worstHour}:00',
                    variant: MetricCardVariant.loss),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared Sub-Widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

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
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final List<Widget> children;
  const _MetricsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSizes.sm,
        mainAxisSpacing: AppSizes.sm,
        childAspectRatio: 1.6,
      ),
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
    );
  }
}

class _RatioRow extends StatelessWidget {
  final String label;
  final double? value;
  final double good;
  final double great;

  const _RatioRow({
    required this.label,
    required this.value,
    required this.good,
    required this.great,
  });

  MetricCardVariant get _variant {
    final v = value ?? 0;
    if (v >= great) return MetricCardVariant.gain;
    if (v >= good) return MetricCardVariant.warning;
    return MetricCardVariant.loss;
  }

  @override
  Widget build(BuildContext context) => MetricRow(
        label: label,
        value: Fmt.ratio(value),
        variant: _variant,
      );
}

class _FearGreedCard extends StatelessWidget {
  final int score;
  const _FearGreedCard({required this.score});

  Color get _color {
    if (score >= 75) return AppColors.gain;
    if (score >= 55) return AppColors.warning;
    if (score >= 45) return AppColors.textSecondary;
    if (score >= 25) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Fear & Greed Index',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  Fmt.fearGreed(score),
                  style: TextStyle(
                    color: _color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: _color,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DisciplineScoreCard extends StatelessWidget {
  final double score;
  const _DisciplineScoreCard({required this.score});

  Color get _color {
    if (score >= 80) return AppColors.gain;
    if (score >= 50) return AppColors.warning;
    return AppColors.loss;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Discipline Score',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(
                  score >= 80 ? 'Excellent' : score >= 50 ? 'Needs Work' : 'Poor',
                  style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: AlwaysStoppedAnimation(_color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            score.toStringAsFixed(0),
            style: TextStyle(
              color: _color,
              fontSize: 40,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('/100', style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BehavioralRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;
  final double lossUsd;

  const _BehavioralRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
    required this.lossUsd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                Text(
                  count == 0
                      ? 'None detected'
                      : '$count occurrences · ${Fmt.usd(lossUsd)} est. loss',
                  style: TextStyle(
                    color: count > 0 ? AppColors.loss : AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: count > 0 ? AppColors.loss : AppColors.gain,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  final String label;
  final double value;
  final double good;
  final bool inverted;

  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.good,
    this.inverted = false,
  });

  Color get _color {
    final isGood = inverted ? value <= good : value >= good;
    return isGood ? AppColors.gain : AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Text(
              Fmt.pct(value, showSign: false),
              style: TextStyle(color: _color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: AppColors.surfaceHigh,
            valueColor: AlwaysStoppedAnimation(_color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            Text(
              error.contains('404') || error.contains('No analytics')
                  ? 'No analytics data yet.\nSync your exchange to get started.'
                  : error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.lg),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
