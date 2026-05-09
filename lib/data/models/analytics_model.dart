import '../../domain/entities/analytics.dart';

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
int? _i(dynamic v) => v == null ? null : (v as num).toInt();

class FullAnalyticsModel {
  final DateTime computedAt;
  final int periodDays;
  final PerformanceMetrics performance;
  final RiskMetrics risk;
  final RiskAdjustedMetrics riskAdjusted;
  final TradeQualityMetrics tradeQuality;
  final PortfolioStructureMetrics structure;
  final MarketMetrics market;
  final BehavioralMetrics behavioral;

  const FullAnalyticsModel({
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

  factory FullAnalyticsModel.fromJson(Map<String, dynamic> j) {
    final p = j['performance'] as Map<String, dynamic>;
    final r = j['risk'] as Map<String, dynamic>;
    final ra = j['risk_adjusted'] as Map<String, dynamic>;
    final tq = j['trade_quality'] as Map<String, dynamic>;
    final ps = j['portfolio_structure'] as Map<String, dynamic>;
    final m = j['market'] as Map<String, dynamic>;
    final b = j['behavioral'] as Map<String, dynamic>;

    return FullAnalyticsModel(
      computedAt: DateTime.parse(j['computed_at'] as String),
      periodDays: j['period_days'] as int,
      performance: PerformanceMetrics(
        totalPnlUsd: _d(p['total_pnl_usd']),
        realizedPnlUsd: _d(p['realized_pnl_usd']),
        unrealizedPnlUsd: _d(p['unrealized_pnl_usd']),
        roiDaily: _d(p['roi_daily']),
        roiWeekly: _d(p['roi_weekly']),
        roiMonthly: _d(p['roi_monthly']),
        roiYearly: _d(p['roi_yearly']),
        roiAllTime: _d(p['roi_all_time']),
        cagr: _d(p['cagr']),
      ),
      risk: RiskMetrics(
        maxDrawdown: _d(r['max_drawdown']),
        avgDrawdown: _d(r['avg_drawdown']),
        volatilityDaily: _d(r['volatility_daily']),
        volatilityAnnualized: _d(r['volatility_annualized']),
        downsideDeviation: _d(r['downside_deviation']),
        var95: _d(r['var_95']),
        var99: _d(r['var_99']),
      ),
      riskAdjusted: RiskAdjustedMetrics(
        sharpeRatio: _d(ra['sharpe_ratio']),
        sortinoRatio: _d(ra['sortino_ratio']),
        calmarRatio: _d(ra['calmar_ratio']),
      ),
      tradeQuality: TradeQualityMetrics(
        totalTrades: _i(tq['total_trades']),
        winningTrades: _i(tq['winning_trades']),
        losingTrades: _i(tq['losing_trades']),
        winRate: _d(tq['win_rate']),
        lossRate: _d(tq['loss_rate']),
        profitFactor: _d(tq['profit_factor']),
        expectancyUsd: _d(tq['expectancy_usd']),
        avgWinUsd: _d(tq['avg_win_usd']),
        avgLossUsd: _d(tq['avg_loss_usd']),
        avgWinLossRatio: _d(tq['avg_win_loss_ratio']),
        avgHoldingHours: _d(tq['avg_holding_hours']),
      ),
      structure: PortfolioStructureMetrics(
        diversificationScore: _d(ps['diversification_score']),
        concentrationRisk: _d(ps['concentration_risk']),
        btcExposurePct: _d(ps['btc_exposure_pct']),
        ethExposurePct: _d(ps['eth_exposure_pct']),
        stablecoinPct: _d(ps['stablecoin_pct']),
      ),
      market: MarketMetrics(
        betaVsBtc: _d(m['beta_vs_btc']),
        alphaVsBtc: _d(m['alpha_vs_btc']),
        correlationVsBtc: _d(m['correlation_vs_btc']),
        fearGreedScore: _i(m['fear_greed_score']),
      ),
      behavioral: BehavioralMetrics(
        overtradingScore: _d(b['overtrading_score']),
        avgTradesPerDay: _d(b['avg_trades_per_day']),
        revengeTradeCount: (b['revenge_trade_count'] as num? ?? 0).toInt(),
        revengeTradeUsd: (b['revenge_trade_loss_usd'] as num? ?? 0).toDouble(),
        fomoTradeCount: (b['fomo_trade_count'] as num? ?? 0).toInt(),
        fomoTradeUsd: (b['fomo_trade_loss_usd'] as num? ?? 0).toDouble(),
        panicSellCount: (b['panic_sell_count'] as num? ?? 0).toInt(),
        panicSellUsd: (b['panic_sell_loss_usd'] as num? ?? 0).toDouble(),
        bestHour: _i(b['best_performing_hour']),
        worstHour: _i(b['worst_performing_hour']),
        bestDay: _i(b['best_performing_day']),
        worstDay: _i(b['worst_performing_day']),
        disciplineScore: _d(b['discipline_score']),
      ),
    );
  }

  FullAnalyticsEntity toEntity() => FullAnalyticsEntity(
        computedAt: computedAt,
        periodDays: periodDays,
        performance: performance,
        risk: risk,
        riskAdjusted: riskAdjusted,
        tradeQuality: tradeQuality,
        structure: structure,
        market: market,
        behavioral: behavioral,
      );
}

class ReturnPointModel {
  final DateTime date;
  final double value;
  final double? dailyReturn;

  const ReturnPointModel({required this.date, required this.value, this.dailyReturn});

  factory ReturnPointModel.fromJson(Map<String, dynamic> j) => ReturnPointModel(
        date: DateTime.parse(j['date'] as String),
        value: (j['value'] as num).toDouble(),
        dailyReturn: _d(j['daily_return']),
      );

  ReturnPoint toEntity() => ReturnPoint(date: date, value: value, dailyReturn: dailyReturn);
}
