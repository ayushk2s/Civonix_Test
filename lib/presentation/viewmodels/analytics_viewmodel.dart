import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/remote/analytics_remote_datasource.dart';
import '../../domain/entities/analytics.dart';

class AnalyticsState {
  final bool isLoading;
  final FullAnalyticsEntity? analytics;
  final List<ReturnPoint> returnSeries;
  final String? error;
  final int periodDays;

  const AnalyticsState({
    this.isLoading = false,
    this.analytics,
    this.returnSeries = const [],
    this.error,
    this.periodDays = 365,
  });

  AnalyticsState copyWith({
    bool? isLoading,
    FullAnalyticsEntity? analytics,
    List<ReturnPoint>? returnSeries,
    String? error,
    int? periodDays,
  }) =>
      AnalyticsState(
        isLoading: isLoading ?? this.isLoading,
        analytics: analytics ?? this.analytics,
        returnSeries: returnSeries ?? this.returnSeries,
        error: error,
        periodDays: periodDays ?? this.periodDays,
      );
}

class AnalyticsViewModel extends StateNotifier<AnalyticsState> {
  final AnalyticsRemoteDatasource _ds;

  AnalyticsViewModel(this._ds) : super(const AnalyticsState());

  Future<void> loadAll({int periodDays = 365}) async {
    state = state.copyWith(isLoading: true, error: null, periodDays: periodDays);
    try {
      final results = await Future.wait([
        _ds.getFullAnalytics(periodDays: periodDays),
        _ds.getReturnSeries(days: 90),
      ]);
      state = state.copyWith(
        isLoading: false,
        analytics: (results[0] as dynamic).toEntity() as FullAnalyticsEntity,
        returnSeries: (results[1] as List)
            .map((m) => (m as dynamic).toEntity() as ReturnPoint)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> changePeriod(int days) async {
    if (days == state.periodDays) return;
    await loadAll(periodDays: days);
  }
}

final analyticsViewModelProvider =
    StateNotifierProvider<AnalyticsViewModel, AnalyticsState>((ref) {
  return AnalyticsViewModel(AnalyticsRemoteDatasource(ApiClient()));
});
