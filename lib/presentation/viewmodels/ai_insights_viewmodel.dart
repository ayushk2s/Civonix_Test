import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/remote/ai_remote_datasource.dart';
import '../../domain/entities/ai_insight.dart';

class AiInsightsState {
  final bool isLoading;
  final bool isGenerating;
  final List<AiInsightEntity> insights;
  final WhyLosingReport? whyLosingReport;
  final bool isLoadingReport;
  final String? error;

  const AiInsightsState({
    this.isLoading = false,
    this.isGenerating = false,
    this.insights = const [],
    this.whyLosingReport,
    this.isLoadingReport = false,
    this.error,
  });

  AiInsightsState copyWith({
    bool? isLoading,
    bool? isGenerating,
    List<AiInsightEntity>? insights,
    WhyLosingReport? whyLosingReport,
    bool? isLoadingReport,
    String? error,
  }) =>
      AiInsightsState(
        isLoading: isLoading ?? this.isLoading,
        isGenerating: isGenerating ?? this.isGenerating,
        insights: insights ?? this.insights,
        whyLosingReport: whyLosingReport ?? this.whyLosingReport,
        isLoadingReport: isLoadingReport ?? this.isLoadingReport,
        error: error,
      );

  int get unreadCount => insights.where((i) => !i.isRead).length;
  List<AiInsightEntity> get critical => insights.where((i) => i.isCritical).toList();
}

class AiInsightsViewModel extends StateNotifier<AiInsightsState> {
  final AiRemoteDatasource _ds;

  AiInsightsViewModel(this._ds) : super(const AiInsightsState());

  Future<void> loadInsights() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final insights = await _ds.getInsights();
      state = state.copyWith(isLoading: false, insights: insights);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadWhyLosingReport() async {
    state = state.copyWith(isLoadingReport: true, error: null);
    try {
      final report = await _ds.getWhyLosingReport();
      state = state.copyWith(isLoadingReport: false, whyLosingReport: report);
    } catch (e) {
      state = state.copyWith(isLoadingReport: false, error: e.toString());
    }
  }

  Future<void> generateInsights() async {
    state = state.copyWith(isGenerating: true);
    try {
      await _ds.generateInsights();
      await Future.delayed(const Duration(seconds: 3));
      await loadInsights();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isGenerating: false);
    }
  }

  Future<void> markRead(List<String> ids) async {
    await _ds.markRead(ids);
    state = state.copyWith(
      insights: state.insights.map((i) {
        return ids.contains(i.id)
            ? AiInsightEntity(
                id: i.id, category: i.category, severity: i.severity,
                title: i.title, body: i.body, actionItems: i.actionItems,
                isRead: true, isDismissed: i.isDismissed, createdAt: i.createdAt,
              )
            : i;
      }).toList(),
    );
  }
}

final aiInsightsViewModelProvider =
    StateNotifierProvider<AiInsightsViewModel, AiInsightsState>((ref) {
  return AiInsightsViewModel(AiRemoteDatasource(ApiClient()));
});
