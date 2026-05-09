class Endpoints {
  Endpoints._();

  static const String _base = '/api/v1';

  // Auth
  static const String register      = '$_base/auth/register';
  static const String login         = '$_base/auth/login';
  static const String refresh       = '$_base/auth/refresh';
  static const String me            = '$_base/auth/me';
  static const String updateProfile = '$_base/auth/me';

  // Portfolio
  static const String connectExchange  = '$_base/portfolio/exchange/connect';
  static const String listExchanges    = '$_base/portfolio/exchange';
  static const String portfolioSummary = '$_base/portfolio/summary';
  static const String trades           = '$_base/portfolio/trades';
  static String syncAccount(String id) => '$_base/portfolio/sync/$id';
  static String disconnectExchange(String id) => '$_base/portfolio/exchange/$id';

  // Analytics
  static const String fullAnalytics  = '$_base/analytics/full';
  static const String returnSeries   = '$_base/analytics/returns';
  static const String drawdownSeries = '$_base/analytics/drawdown';

  // AI
  static const String aiInsights     = '$_base/ai/insights';
  static const String generateInsights = '$_base/ai/insights/generate';
  static const String markInsightsRead = '$_base/ai/insights/read';
  static const String whyLosing      = '$_base/ai/why-losing';

  // Leaderboard
  static String leaderboard(String scope, String value) =>
      '$_base/leaderboard/$scope?scope_value=$value';
  static String compare(String a, String b) =>
      '$_base/leaderboard/compare/$a/$b';

  // News
  static const String newsFeed       = '$_base/news/feed';

  // Prediction
  static const String todayPrediction  = '$_base/prediction/today';
  static const String submitPrediction = '$_base/prediction/submit';
  static const String predictionHistory = '$_base/prediction/history';
}
