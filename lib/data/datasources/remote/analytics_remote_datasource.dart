import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../models/analytics_model.dart';

class AnalyticsRemoteDatasource {
  final ApiClient _api;
  AnalyticsRemoteDatasource(this._api);

  Future<FullAnalyticsModel> getFullAnalytics({int periodDays = 365}) async {
    final data = await _api.get(
      Endpoints.fullAnalytics,
      queryParams: {'period_days': periodDays},
    ) as Map<String, dynamic>;
    return FullAnalyticsModel.fromJson(data);
  }

  Future<List<ReturnPointModel>> getReturnSeries({int days = 90}) async {
    final data = await _api.get(
      Endpoints.returnSeries,
      queryParams: {'days': days},
    ) as List;
    return data.map((e) => ReturnPointModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
