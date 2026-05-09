import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/ai_insight.dart';
import '../../viewmodels/ai_insights_viewmodel.dart';
import '../../widgets/common/gradient_button.dart';

class AiInsightsScreen extends ConsumerStatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  ConsumerState<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends ConsumerState<AiInsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(
        () => ref.read(aiInsightsViewModelProvider.notifier).loadInsights());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiInsightsViewModelProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('AI Advisor'),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: const [
            Tab(text: 'Insights'),
            Tab(text: "Why Losing?"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _InsightsTab(state: state),
          _WhyLosingTab(state: state),
        ],
      ),
    );
  }
}

// ── Insights Tab ────────────────────────────────────────────────────────────────

class _InsightsTab extends ConsumerWidget {
  final AiInsightsState state;
  const _InsightsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: GradientButton(
            label: state.isGenerating ? 'Analyzing your trades...' : 'Generate New Insights',
            isLoading: state.isGenerating,
            onTap: state.isGenerating
                ? null
                : () => ref.read(aiInsightsViewModelProvider.notifier).generateInsights(),
            prefix: const Icon(Icons.auto_awesome_rounded, size: 18),
          ),
        ),

        if (state.insights.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: AppSizes.md),
                  const Text('No insights yet',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('Tap "Generate" to analyze your portfolio',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              itemCount: state.insights.length,
              separatorBuilder: (context, i) => const SizedBox(height: AppSizes.sm),
              itemBuilder: (_, i) => _InsightCard(
                insight: state.insights[i],
                onTap: () => ref
                    .read(aiInsightsViewModelProvider.notifier)
                    .markRead([state.insights[i].id]),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 50)),
            ),
          ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AiInsightEntity insight;
  final VoidCallback? onTap;
  const _InsightCard({required this.insight, this.onTap});

  Color get _borderColor {
    if (insight.isCritical) return AppColors.loss;
    if (insight.isWarning) return AppColors.warning;
    return AppColors.primary;
  }

  Color get _iconBg {
    if (insight.isCritical) return AppColors.lossMuted;
    if (insight.isWarning) return AppColors.warningMuted;
    return AppColors.primary.withValues(alpha: 0.15);
  }

  IconData get _icon {
    switch (insight.category) {
      case 'behavioral': return Icons.psychology_rounded;
      case 'risk': return Icons.shield_outlined;
      case 'opportunity': return Icons.rocket_launch_outlined;
      default: return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(
            color: insight.isRead
                ? AppColors.cardBorder
                : _borderColor.withValues(alpha: 0.5),
            width: insight.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: _borderColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (!insight.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _borderColor, shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.body,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (insight.actionItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...insight.actionItems.take(2).map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.arrow_right_rounded,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  a,
                                  style: const TextStyle(
                                      color: AppColors.primary, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    Fmt.timeAgo(insight.createdAt),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Why Losing Tab ──────────────────────────────────────────────────────────────

class _WhyLosingTab extends ConsumerWidget {
  final AiInsightsState state;
  const _WhyLosingTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = state.whyLosingReport;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.md),
      children: [
        GradientButton(
          label: report == null
              ? 'Analyze Why I\'m Losing Money'
              : 'Refresh Report',
          isLoading: state.isLoadingReport,
          gradient: AppColors.lossGradient,
          onTap: state.isLoadingReport
              ? null
              : () => ref
                  .read(aiInsightsViewModelProvider.notifier)
                  .loadWhyLosingReport(),
          prefix: const Icon(Icons.psychology_alt_rounded, size: 18),
        ),
        const SizedBox(height: AppSizes.md),

        if (state.isLoadingReport) ...[
          const SizedBox(height: AppSizes.xxl),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: AppSizes.md),
                Text('Analyzing your complete trade history...',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ] else if (report != null) ...[
          // Overall assessment
          Container(
            padding: const EdgeInsets.all(AppSizes.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.lossMuted,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 18),
                    SizedBox(width: 8),
                    Text('Assessment',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: AppSizes.sm),
                Text(report.overallAssessment,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14, height: 1.5)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppSizes.md),

          // Primary Issues
          if (report.primaryIssues.isNotEmpty) ...[
            const Text('Primary Issues',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.sm),
            ...report.primaryIssues.asMap().entries.map((e) =>
                _IssueCard(issue: e.value)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: e.key * 60))),
            const SizedBox(height: AppSizes.md),
          ],

          // Behavioral Mistakes
          if (report.behavioralMistakes.isNotEmpty) ...[
            const Text('Behavioral Mistakes',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.sm),
            ...report.behavioralMistakes.map((m) => _MistakeCard(mistake: m)),
            const SizedBox(height: AppSizes.md),
          ],

          // Action Steps
          if (report.actionableSteps.isNotEmpty) ...[
            const Text('Action Plan',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.sm),
            Container(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: report.actionableSteps.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${e.key + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            e.value,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          if (report.estimatedRecoverableLoss != null) ...[
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.all(AppSizes.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.gainMuted,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(color: AppColors.gain.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.savings_outlined, color: AppColors.gain, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Potentially Recoverable',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        Text(
                          Fmt.usd(report.estimatedRecoverableLoss),
                          style: const TextStyle(
                              color: AppColors.gain,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: AppSizes.xxl),
          const Center(
            child: Column(
              children: [
                Icon(Icons.search_rounded, size: 64, color: AppColors.textMuted),
                SizedBox(height: AppSizes.md),
                Text(
                  'Tap the button above to get an AI-powered\nanalysis of your trading mistakes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  final WhyLosingIssue issue;
  const _IssueCard({required this.issue});

  Color get _severityColor {
    switch (issue.severity) {
      case 'critical': return AppColors.loss;
      case 'warning': return AppColors.warning;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: _severityColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _severityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                ),
                child: Text(
                  issue.severity.toUpperCase(),
                  style: TextStyle(
                      color: _severityColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              if (issue.impactUsd != null) ...[
                const Spacer(),
                Text(
                  '~${Fmt.usd(issue.impactUsd)} impact',
                  style: const TextStyle(color: AppColors.loss, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(issue.issue,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(issue.evidence,
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 12, fontStyle: FontStyle.italic)),
          const SizedBox(height: 4),
          Text(issue.explanation,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  final BehavioralMistake mistake;
  const _MistakeCard({required this.mistake});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
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
                Text(mistake.mistake,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  mistake.howToFix,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                ),
                if (mistake.estimatedLossUsd != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Est. loss: ${Fmt.usd(mistake.estimatedLossUsd)}',
                    style: const TextStyle(color: AppColors.loss, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Text(
                '${mistake.count}x',
                style: const TextStyle(
                    color: AppColors.loss, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Text('times', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
