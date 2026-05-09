import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../models/news_model.dart';

class NewsRemoteDatasource {
  final ApiClient _api;
  NewsRemoteDatasource(this._api);

  Future<List<NewsArticleModel>> getNewsFeed({
    int page = 1,
    int pageSize = 20,
    String? sentiment,
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (sentiment != null) params['sentiment'] = sentiment;
    final data = await _api.get(Endpoints.newsFeed, queryParams: params) as Map<String, dynamic>;
    return (data['articles'] as List)
        .map((e) => NewsArticleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PredictionModel> getTodayPrediction() async {
    final data = await _api.get(Endpoints.todayPrediction) as Map<String, dynamic>;
    return PredictionModel.fromJson(data);
  }

  Future<PredictionModel> submitPrediction(String direction) async {
    final data = await _api.post(
      Endpoints.submitPrediction,
      data: {'direction': direction},
    ) as Map<String, dynamic>;
    return PredictionModel.fromJson(data);
  }
}
