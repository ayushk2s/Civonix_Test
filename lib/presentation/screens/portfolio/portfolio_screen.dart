import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/portfolio.dart';
import '../../viewmodels/portfolio_viewmodel.dart';
import '../../widgets/common/metric_card.dart';

class PortfolioScreen extends ConsumerStatefulWidget {
  const PortfolioScreen({super.key});

  @override
  ConsumerState<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends ConsumerState<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(
        () => ref.read(portfolioViewModelProvider.notifier).loadAll());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          if (state.accounts.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              color: AppColors.textSecondary,
              onPressed: state.isLoading
                  ? null
                  : () => ref
                      .read(portfolioViewModelProvider.notifier)
                      .loadAll(),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_link_rounded),
              color: AppColors.primary,
              onPressed: () => context.push('/connect-exchange'),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Holdings'),
            Tab(text: 'Accounts'),
          ],
        ),
      ),
      body: state.isLoading && state.summary == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabs,
              children: [
                _HoldingsTab(
                  state: state,
                  onRefresh: () =>
                      ref.read(portfolioViewModelProvider.notifier).loadAll(),
                ),
                _AccountsTab(state: state),
              ],
            ),
    );
  }
}

// ── Holdings Tab ─────────────────────────────────────────────────────────────

class _HoldingsTab extends StatelessWidget {
  final PortfolioState state;
  final Future<void> Function() onRefresh;
  const _HoldingsTab({required this.state, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    if (summary == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            const Text('No portfolio data',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Connect an exchange to get started',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        slivers: [
          // Summary metrics
          SliverPadding(
            padding: const EdgeInsets.all(AppSizes.md),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Total Value',
                          value: Fmt.usd(summary.totalValueUsd),
                          subtitle: 'Portfolio',
                          variant: MetricCardVariant.neutral,
                        ),
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
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(
                        child: MetricCard(
                          label: 'Daily Change',
                          value: Fmt.usd(summary.dailyChangeUsd),
                          subtitle: Fmt.pct(summary.dailyChangePct),
                          variant: summary.isDailyPositive
                              ? MetricCardVariant.gain
                              : MetricCardVariant.loss,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: MetricCard(
                          label: 'Assets',
                          value: '${summary.holdings.length}',
                          subtitle: 'positions',
                          variant: MetricCardVariant.neutral,
                        ),
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
            ),
          ),

          // Holdings list header
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Row(
                  children: [
                    const Text('All Holdings',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(
                      'Updated ${Fmt.timeAgo(summary.lastUpdated)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Holdings
          SliverPadding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _HoldingTile(
                  holding: summary.holdings[i],
                  index: i,
                ),
                childCount: summary.holdings.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

class _HoldingTile extends StatelessWidget {
  final HoldingEntity holding;
  final int index;
  const _HoldingTile({required this.holding, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                holding.symbol.length >= 2
                    ? holding.symbol.substring(0, 2)
                    : holding.symbol,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${Fmt.crypto(holding.quantity)} @ ${Fmt.usd(holding.avgBuyPrice)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Row(
                children: [
                  Text(
                    Fmt.pct(holding.unrealizedPnlPct),
                    style: TextStyle(
                      color: holding.isProfit
                          ? AppColors.gain
                          : AppColors.loss,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${Fmt.usd(holding.unrealizedPnlUsd)})',
                    style: TextStyle(
                      color: holding.isProfit
                          ? AppColors.gain
                          : AppColors.loss,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: index * 30));
  }
}

// ── Accounts Tab ─────────────────────────────────────────────────────────────

class _AccountsTab extends ConsumerWidget {
  final PortfolioState state;
  const _AccountsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSizes.md),
            const Text('No exchanges connected',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 16)),
            const SizedBox(height: AppSizes.md),
            GestureDetector(
              onTap: () => context.push('/connect-exchange'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusFull),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'Connect Exchange',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSizes.md),
      itemCount: state.accounts.length + 1,
      itemBuilder: (context, i) {
        if (i == state.accounts.length) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSizes.sm),
            child: GestureDetector(
              onTap: () => context.push('/connect-exchange'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(AppSizes.radiusMd),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Add Exchange',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          );
        }
        final account = state.accounts[i];
        return _AccountCard(
          account: account,
          onSync: () => ref
              .read(portfolioViewModelProvider.notifier)
              .syncAccount(account.id),
          onFullSync: () => ref
              .read(portfolioViewModelProvider.notifier)
              .syncAccount(account.id, full: true),
          onDisconnect: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
                title: const Text('Disconnect Exchange',
                    style: TextStyle(color: AppColors.textPrimary)),
                content: Text(
                  'Remove ${account.exchange.toUpperCase()} (${account.label})?\n\nYour trade history will be preserved.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Disconnect', style: TextStyle(color: AppColors.loss)),
                  ),
                ],
              ),
            );
            if (ok == true) {
              ref.read(portfolioViewModelProvider.notifier).disconnectExchange(account.id);
            }
          },
        ).animate().fadeIn(delay: Duration(milliseconds: i * 60));
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final ExchangeAccountEntity account;
  final VoidCallback onSync;
  final VoidCallback onFullSync;
  final VoidCallback onDisconnect;
  const _AccountCard({
    required this.account,
    required this.onSync,
    required this.onFullSync,
    required this.onDisconnect,
  });

  static const _exchangeColors = {
    'binance': Color(0xFFF0B90B),
    'bybit':   Color(0xFFF7A600),
    'kucoin':  Color(0xFF24AE8F),
  };

  @override
  Widget build(BuildContext context) {
    final hasError = account.syncError != null;
    final brandColor = _exchangeColors[account.exchange] ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: hasError
              ? AppColors.loss.withValues(alpha: 0.4)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      account.exchange[0].toUpperCase(),
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
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
                        account.label,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: brandColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              account.exchange.toUpperCase(),
                              style: TextStyle(
                                color: brandColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (account.lastSyncedAt != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              'Synced ${Fmt.timeAgo(account.lastSyncedAt!)}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ] else ...[
                            const SizedBox(width: 6),
                            const Text(
                              'Never synced',
                              style: TextStyle(color: AppColors.warning, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    side: const BorderSide(color: AppColors.cardBorder),
                  ),
                  onSelected: (v) {
                    if (v == 'sync') onSync();
                    if (v == 'full') onFullSync();
                    if (v == 'disconnect') onDisconnect();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'sync',
                      child: Row(children: [
                        Icon(Icons.sync_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Quick Sync', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'full',
                      child: Row(children: [
                        Icon(Icons.history_rounded, size: 16, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text('Full Resync (all history)', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: Row(children: [
                        Icon(Icons.link_off_rounded, size: 16, color: AppColors.loss),
                        SizedBox(width: 8),
                        Text('Disconnect', style: TextStyle(color: AppColors.loss, fontSize: 13)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(AppSizes.cardPadding, 0, AppSizes.cardPadding, AppSizes.cardPadding),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lossMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.loss, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        account.syncError!,
                        style: const TextStyle(color: AppColors.loss, fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
