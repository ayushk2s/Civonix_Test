import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../data/datasources/remote/news_remote_datasource.dart';
import '../../domain/entities/news_article.dart';

class NewsState {
  final bool isLoading;
  final List<NewsArticleEntity> articles;
  final PredictionEntity? prediction;
  final bool isSubmittingPrediction;
  final String? sentimentFilter;
  final String? error;

  const NewsState({
    this.isLoading = false,
    this.articles = const [],
    this.prediction,
    this.isSubmittingPrediction = false,
    this.sentimentFilter,
    this.error,
  });

  NewsState copyWith({
    bool? isLoading,
    List<NewsArticleEntity>? articles,
    PredictionEntity? prediction,
    bool? isSubmittingPrediction,
    String? sentimentFilter,
    String? error,
  }) =>
      NewsState(
        isLoading: isLoading ?? this.isLoading,
        articles: articles ?? this.articles,
        prediction: prediction ?? this.prediction,
        isSubmittingPrediction: isSubmittingPrediction ?? this.isSubmittingPrediction,
        sentimentFilter: sentimentFilter,
        error: error,
      );

  List<NewsArticleEntity> get filteredArticles {
    if (sentimentFilter == null) return articles;
    return articles.where((a) => a.sentimentLabel == sentimentFilter).toList();
  }

  List<NewsArticleEntity> get portfolioAlerts =>
      articles.where((a) => a.affectsMyPortfolio).toList();
}

class NewsViewModel extends StateNotifier<NewsState> {
  final NewsRemoteDatasource _ds;

  NewsViewModel(this._ds) : super(const NewsState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _ds.getNewsFeed(),
        _ds.getTodayPrediction(),
      ]);
      state = state.copyWith(
        isLoading: false,
        articles: (results[0] as List)
            .map((m) => (m as dynamic).toEntity() as NewsArticleEntity)
            .toList(),
        prediction: (results[1] as dynamic).toEntity() as PredictionEntity,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNews({String? sentiment}) async {
    try {
      final models = await _ds.getNewsFeed(sentiment: sentiment);
      state = state.copyWith(
        articles: models.map((m) => m.toEntity()).toList(),
        sentimentFilter: sentiment,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> submitPrediction(String direction) async {
    state = state.copyWith(isSubmittingPrediction: true, error: null);
    try {
      final model = await _ds.submitPrediction(direction);
      state = state.copyWith(
        isSubmittingPrediction: false,
        prediction: model.toEntity(),
      );
    } catch (e) {
      state = state.copyWith(isSubmittingPrediction: false, error: e.toString());
    }
  }

  void setSentimentFilter(String? sentiment) {
    state = state.copyWith(sentimentFilter: sentiment);
  }
}

final newsViewModelProvider =
    StateNotifierProvider<NewsViewModel, NewsState>((ref) {
  return NewsViewModel(NewsRemoteDatasource(ApiClient()));
});
