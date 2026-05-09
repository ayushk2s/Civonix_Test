class HoldingEntity {
  final String symbol;
  final String? name;
  final double quantity;
  final double avgBuyPrice;
  final double currentPrice;
  final double valueUsd;
  final double unrealizedPnlUsd;
  final double unrealizedPnlPct;
  final double allocationPct;

  const HoldingEntity({
    required this.symbol,
    this.name,
    required this.quantity,
    required this.avgBuyPrice,
    required this.currentPrice,
    required this.valueUsd,
    required this.unrealizedPnlUsd,
    required this.unrealizedPnlPct,
    required this.allocationPct,
  });

  bool get isProfit => unrealizedPnlUsd >= 0;
}

class PortfolioSummaryEntity {
  final double totalValueUsd;
  final double totalPnlUsd;
  final double totalPnlPct;
  final double dailyChangeUsd;
  final double dailyChangePct;
  final List<HoldingEntity> holdings;
  final DateTime lastUpdated;

  const PortfolioSummaryEntity({
    required this.totalValueUsd,
    required this.totalPnlUsd,
    required this.totalPnlPct,
    required this.dailyChangeUsd,
    required this.dailyChangePct,
    required this.holdings,
    required this.lastUpdated,
  });

  bool get isPositive => totalPnlUsd >= 0;
  bool get isDailyPositive => dailyChangeUsd >= 0;
}

class ExchangeAccountEntity {
  final String id;
  final String exchange;
  final String label;
  final bool isActive;
  final DateTime? lastSyncedAt;
  final String? syncError;

  const ExchangeAccountEntity({
    required this.id,
    required this.exchange,
    required this.label,
    required this.isActive,
    this.lastSyncedAt,
    this.syncError,
  });
}

class TradeEntity {
  final String id;
  final String symbol;
  final String side;
  final double price;
  final double quantity;
  final double quoteQuantity;
  final double fee;
  final double? realizedPnl;
  final DateTime executedAt;

  const TradeEntity({
    required this.id,
    required this.symbol,
    required this.side,
    required this.price,
    required this.quantity,
    required this.quoteQuantity,
    required this.fee,
    this.realizedPnl,
    required this.executedAt,
  });

  bool get isBuy => side == 'buy';
  bool get isProfit => (realizedPnl ?? 0) > 0;
}
