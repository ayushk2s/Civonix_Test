import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../domain/entities/ai_insight.dart';

class AiRemoteDatasource {
  final ApiClient _api;
  AiRemoteDatasource(this._api);

  Future<List<AiInsightEntity>> getInsights({bool unreadOnly = false}) async {
    final data = await _api.get(
      Endpoints.aiInsights,
      queryParams: {'unread_only': unreadOnly},
    ) as List;
    return data.map((e) => _mapInsight(e as Map<String, dynamic>)).toList();
  }

  Future<WhyLosingReport> getWhyLosingReport() async {
    final data = await _api.get(Endpoints.whyLosing) as Map<String, dynamic>;
    return _mapWhyLosing(data);
  }

  Future<void> generateInsights() async {
    await _api.post(Endpoints.generateInsights);
  }

  Future<void> markRead(List<String> insightIds) async {
    await _api.post(Endpoints.markInsightsRead, data: {'insight_ids': insightIds});
  }

  AiInsightEntity _mapInsight(Map<String, dynamic> j) => AiInsightEntity(
        id: j['id'] as String,
        category: j['category'] as String,
        severity: j['severity'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        actionItems: (j['action_items'] as List).map((e) => e as String).toList(),
        isRead: j['is_read'] as bool,
        isDismissed: j['is_dismissed'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  WhyLosingReport _mapWhyLosing(Map<String, dynamic> j) => WhyLosingReport(
        overallAssessment: j['overall_assessment'] as String,
        primaryIssues: (j['primary_issues'] as List? ?? []).map((e) {
          final m = e as Map<String, dynamic>;
          return WhyLosingIssue(
            issue: m['issue'] as String,
            severity: m['severity'] as String,
            evidence: m['evidence'] as String,
            impactUsd: m['impact_usd'] != null ? (m['impact_usd'] as num).toDouble() : null,
            explanation: m['explanation'] as String,
          );
        }).toList(),
        behavioralMistakes: (j['behavioral_mistakes'] as List? ?? []).map((e) {
          final m = e as Map<String, dynamic>;
          return BehavioralMistake(
            mistake: m['mistake'] as String,
            count: (m['count'] as num).toInt(),
            estimatedLossUsd: m['estimated_loss_usd'] != null
                ? (m['estimated_loss_usd'] as num).toDouble()
                : null,
            howToFix: m['how_to_fix'] as String,
          );
        }).toList(),
        actionableSteps: (j['actionable_steps'] as List? ?? []).map((e) => e as String).toList(),
        estimatedRecoverableLoss: j['estimated_recoverable_loss_usd'] != null
            ? (j['estimated_recoverable_loss_usd'] as num).toDouble()
            : null,
        generatedAt: DateTime.parse(j['generated_at'] as String),
      );
}
