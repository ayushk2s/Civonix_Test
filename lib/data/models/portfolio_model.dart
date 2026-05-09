import '../../domain/entities/portfolio.dart';

class PortfolioSummaryModel {
  final double totalValueUsd;
  final double totalPnlUsd;
  final double totalPnlPct;
  final double dailyChangeUsd;
  final double dailyChangePct;
  final List<HoldingModel> holdings;
  final DateTime lastUpdated;

  const PortfolioSummaryModel({
    required this.totalValueUsd,
    required this.totalPnlUsd,
    required this.totalPnlPct,
    required this.dailyChangeUsd,
    required this.dailyChangePct,
    required this.holdings,
    required this.lastUpdated,
  });

  factory PortfolioSummaryModel.fromJson(Map<String, dynamic> j) =>
      PortfolioSummaryModel(
        totalValueUsd: (j['total_value_usd'] as num).toDouble(),
        totalPnlUsd: (j['total_pnl_usd'] as num).toDouble(),
        totalPnlPct: (j['total_pnl_pct'] as num).toDouble(),
        dailyChangeUsd: (j['daily_change_usd'] as num).toDouble(),
        dailyChangePct: (j['daily_change_pct'] as num).toDouble(),
        holdings: (j['holdings'] as List)
            .map((h) => HoldingModel.fromJson(h as Map<String, dynamic>))
            .toList(),
        lastUpdated: DateTime.parse(j['last_updated'] as String),
      );

  PortfolioSummaryEntity toEntity() => PortfolioSummaryEntity(
        totalValueUsd: totalValueUsd,
        totalPnlUsd: totalPnlUsd,
        totalPnlPct: totalPnlPct,
        dailyChangeUsd: dailyChangeUsd,
        dailyChangePct: dailyChangePct,
        holdings: holdings.map((h) => h.toEntity()).toList(),
        lastUpdated: lastUpdated,
      );
}

class HoldingModel {
  final String symbol;
  final String? name;
  final double quantity;
  final double avgBuyPrice;
  final double currentPrice;
  final double valueUsd;
  final double unrealizedPnlUsd;
  final double unrealizedPnlPct;
  final double allocationPct;

  const HoldingModel({
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

  factory HoldingModel.fromJson(Map<String, dynamic> j) => HoldingModel(
        symbol: j['symbol'] as String,
        name: j['name'] as String?,
        quantity: (j['quantity'] as num).toDouble(),
        avgBuyPrice: (j['avg_buy_price'] as num).toDouble(),
        currentPrice: (j['current_price'] as num).toDouble(),
        valueUsd: (j['value_usd'] as num).toDouble(),
        unrealizedPnlUsd: (j['unrealized_pnl_usd'] as num).toDouble(),
        unrealizedPnlPct: (j['unrealized_pnl_pct'] as num).toDouble(),
        allocationPct: (j['allocation_pct'] as num).toDouble(),
      );

  HoldingEntity toEntity() => HoldingEntity(
        symbol: symbol,
        name: name,
        quantity: quantity,
        avgBuyPrice: avgBuyPrice,
        currentPrice: currentPrice,
        valueUsd: valueUsd,
        unrealizedPnlUsd: unrealizedPnlUsd,
        unrealizedPnlPct: unrealizedPnlPct,
        allocationPct: allocationPct,
      );
}

class ExchangeAccountModel {
  final String id;
  final String exchange;
  final String label;
  final bool isActive;
  final DateTime? lastSyncedAt;
  final String? syncError;

  const ExchangeAccountModel({
    required this.id,
    required this.exchange,
    required this.label,
    required this.isActive,
    this.lastSyncedAt,
    this.syncError,
  });

  factory ExchangeAccountModel.fromJson(Map<String, dynamic> j) =>
      ExchangeAccountModel(
        id: j['id'] as String,
        exchange: j['exchange'] as String,
        label: j['label'] as String,
        isActive: j['is_active'] as bool,
        lastSyncedAt: j['last_synced_at'] != null
            ? DateTime.parse(j['last_synced_at'] as String)
            : null,
        syncError: j['sync_error'] as String?,
      );

  ExchangeAccountEntity toEntity() => ExchangeAccountEntity(
        id: id,
        exchange: exchange,
        label: label,
        isActive: isActive,
        lastSyncedAt: lastSyncedAt,
        syncError: syncError,
      );
}

class TradeModel {
  final String id;
  final String symbol;
  final String side;
  final double price;
  final double quantity;
  final double quoteQuantity;
  final double fee;
  final double? realizedPnl;
  final DateTime executedAt;

  const TradeModel({
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

  factory TradeModel.fromJson(Map<String, dynamic> j) => TradeModel(
        id: j['id'] as String,
        symbol: j['symbol'] as String,
        side: j['side'] as String,
        price: (j['price'] as num).toDouble(),
        quantity: (j['quantity'] as num).toDouble(),
        quoteQuantity: (j['quote_quantity'] as num).toDouble(),
        fee: (j['fee'] as num).toDouble(),
        realizedPnl: j['realized_pnl'] != null
            ? (j['realized_pnl'] as num).toDouble()
            : null,
        executedAt: DateTime.parse(j['executed_at'] as String),
      );

  TradeEntity toEntity() => TradeEntity(
        id: id,
        symbol: symbol,
        side: side,
        price: price,
        quantity: quantity,
        quoteQuantity: quoteQuantity,
        fee: fee,
        realizedPnl: realizedPnl,
        executedAt: executedAt,
      );
}
