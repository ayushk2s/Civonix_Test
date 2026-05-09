import '../../domain/entities/news_article.dart';

class NewsArticleModel {
  final String id;
  final String title;
  final String? summary;
  final String url;
  final String source;
  final String? imageUrl;
  final double? sentiment;
  final String? sentimentLabel;
  final List<String> affectedSymbols;
  final String? portfolioImpact;
  final DateTime publishedAt;

  const NewsArticleModel({
    required this.id,
    required this.title,
    this.summary,
    required this.url,
    required this.source,
    this.imageUrl,
    this.sentiment,
    this.sentimentLabel,
    required this.affectedSymbols,
    this.portfolioImpact,
    required this.publishedAt,
  });

  factory NewsArticleModel.fromJson(Map<String, dynamic> j) => NewsArticleModel(
        id: j['id'] as String? ?? '',
        title: j['title'] as String,
        summary: j['summary'] as String?,
        url: j['url'] as String,
        source: j['source'] as String,
        imageUrl: j['image_url'] as String?,
        sentiment: j['sentiment'] != null ? (j['sentiment'] as num).toDouble() : null,
        sentimentLabel: j['sentiment_label'] as String?,
        affectedSymbols: (j['affected_symbols'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        portfolioImpact: j['portfolio_impact'] as String?,
        publishedAt: DateTime.parse(j['published_at'] as String),
      );

  NewsArticleEntity toEntity() => NewsArticleEntity(
        id: id,
        title: title,
        summary: summary,
        url: url,
        source: source,
        imageUrl: imageUrl,
        sentiment: sentiment,
        sentimentLabel: sentimentLabel,
        affectedSymbols: affectedSymbols,
        portfolioImpact: portfolioImpact,
        publishedAt: publishedAt,
      );
}

class PredictionModel {
  final String id;
  final String gameDate;
  final String assetSymbol;
  final int upVotes;
  final int downVotes;
  final int totalVotes;
  final double upPct;
  final double downPct;
  final bool resolved;
  final String? actualDirection;
  final String? userPrediction;
  final bool? isCorrect;

  const PredictionModel({
    required this.id,
    required this.gameDate,
    required this.assetSymbol,
    required this.upVotes,
    required this.downVotes,
    required this.totalVotes,
    required this.upPct,
    required this.downPct,
    required this.resolved,
    this.actualDirection,
    this.userPrediction,
    this.isCorrect,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> j) => PredictionModel(
        id: j['id'] as String,
        gameDate: j['game_date'] as String,
        assetSymbol: j['asset_symbol'] as String,
        upVotes: (j['up_votes'] as num).toInt(),
        downVotes: (j['down_votes'] as num).toInt(),
        totalVotes: (j['total_votes'] as num).toInt(),
        upPct: (j['up_pct'] as num).toDouble(),
        downPct: (j['down_pct'] as num).toDouble(),
        resolved: j['resolved'] as bool,
        actualDirection: j['actual_direction'] as String?,
        userPrediction: j['user_prediction'] as String?,
        isCorrect: j['is_correct'] as bool?,
      );

  PredictionEntity toEntity() => PredictionEntity(
        id: id,
        gameDate: gameDate,
        assetSymbol: assetSymbol,
        upVotes: upVotes,
        downVotes: downVotes,
        totalVotes: totalVotes,
        upPct: upPct,
        downPct: downPct,
        resolved: resolved,
        actualDirection: actualDirection,
        userPrediction: userPrediction,
        isCorrect: isCorrect,
      );
}
