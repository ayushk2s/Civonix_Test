class PerformanceMetrics {
  final double? totalPnlUsd;
  final double? realizedPnlUsd;
  final double? unrealizedPnlUsd;
  final double? roiDaily;
  final double? roiWeekly;
  final double? roiMonthly;
  final double? roiYearly;
  final double? roiAllTime;
  final double? cagr;

  const PerformanceMetrics({
    this.totalPnlUsd,
    this.realizedPnlUsd,
    this.unrealizedPnlUsd,
    this.roiDaily,
    this.roiWeekly,
    this.roiMonthly,
    this.roiYearly,
    this.roiAllTime,
    this.cagr,
  });
}

class RiskMetrics {
  final double? maxDrawdown;
  final double? avgDrawdown;
  final double? volatilityDaily;
  final double? volatilityAnnualized;
  final double? downsideDeviation;
  final double? var95;
  final double? var99;

  const RiskMetrics({
    this.maxDrawdown,
    this.avgDrawdown,
    this.volatilityDaily,
    this.volatilityAnnualized,
    this.downsideDeviation,
    this.var95,
    this.var99,
  });
}

class RiskAdjustedMetrics {
  final double? sharpeRatio;
  final double? sortinoRatio;
  final double? calmarRatio;

  const RiskAdjustedMetrics({
    this.sharpeRatio,
    this.sortinoRatio,
    this.calmarRatio,
  });
}

class TradeQualityMetrics {
  final int? totalTrades;
  final int? winningTrades;
  final int? losingTrades;
  final double? winRate;
  final double? lossRate;
  final double? profitFactor;
  final double? expectancyUsd;
  final double? avgWinUsd;
  final double? avgLossUsd;
  final double? avgWinLossRatio;
  final double? avgHoldingHours;

  const TradeQualityMetrics({
    this.totalTrades,
    this.winningTrades,
    this.losingTrades,
    this.winRate,
    this.lossRate,
    this.profitFactor,
    this.expectancyUsd,
    this.avgWinUsd,
    this.avgLossUsd,
    this.avgWinLossRatio,
    this.avgHoldingHours,
  });
}

class PortfolioStructureMetrics {
  final double? diversificationScore;
  final double? concentrationRisk;
  final double? btcExposurePct;
  final double? ethExposurePct;
  final double? stablecoinPct;

  const PortfolioStructureMetrics({
    this.diversificationScore,
    this.concentrationRisk,
    this.btcExposurePct,
    this.ethExposurePct,
    this.stablecoinPct,
  });
}

class MarketMetrics {
  final double? betaVsBtc;
  final double? alphaVsBtc;
  final double? correlationVsBtc;
  final int? fearGreedScore;

  const MarketMetrics({
    this.betaVsBtc,
    this.alphaVsBtc,
    this.correlationVsBtc,
    this.fearGreedScore,
  });
}

class BehavioralMetrics {
  final double? overtradingScore;
  final double? avgTradesPerDay;
  final int revengeTradeCount;
  final double revengeTradeUsd;
  final int fomoTradeCount;
  final double fomoTradeUsd;
  final int panicSellCount;
  final double panicSellUsd;
  final int? bestHour;
  final int? worstHour;
  final int? bestDay;
  final int? worstDay;
  final double? disciplineScore;

  const BehavioralMetrics({
    this.overtradingScore,
    this.avgTradesPerDay,
    required this.revengeTradeCount,
    required this.revengeTradeUsd,
    required this.fomoTradeCount,
    required this.fomoTradeUsd,
    required this.panicSellCount,
    required this.panicSellUsd,
    this.bestHour,
    this.worstHour,
    this.bestDay,
    this.worstDay,
    this.disciplineScore,
  });

  double get totalBehavioralLoss =>
      revengeTradeUsd + fomoTradeUsd + panicSellUsd;
}

class FullAnalyticsEntity {
  final DateTime computedAt;
  final int periodDays;
  final PerformanceMetrics performance;
  final RiskMetrics risk;
  final RiskAdjustedMetrics riskAdjusted;
  final TradeQualityMetrics tradeQuality;
  final PortfolioStructureMetrics structure;
  final MarketMetrics market;
  final BehavioralMetrics behavioral;

  const FullAnalyticsEntity({
    required this.computedAt,
    required this.periodDays,
    required this.performance,
    required this.risk,
    required this.riskAdjusted,
    required this.tradeQuality,
    required this.structure,
    required this.market,
    required this.behavioral,
  });
}

class ReturnPoint {
  final DateTime date;
  final double value;
  final double? dailyReturn;

  const ReturnPoint({required this.date, required this.value, this.dailyReturn});
}
