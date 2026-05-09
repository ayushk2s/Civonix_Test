class NewsArticleEntity {
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

  const NewsArticleEntity({
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

  bool get isBullish => sentimentLabel == 'bullish';
  bool get isBearish => sentimentLabel == 'bearish';
  bool get affectsMyPortfolio => portfolioImpact != null;
}

class PredictionEntity {
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

  const PredictionEntity({
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

  bool get hasVoted => userPrediction != null;
}
