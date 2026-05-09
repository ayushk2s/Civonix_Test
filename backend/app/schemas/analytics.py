from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class PerformanceMetrics(BaseModel):
    total_pnl_usd: Decimal | None
    realized_pnl_usd: Decimal | None
    unrealized_pnl_usd: Decimal | None
    roi_daily: Decimal | None
    roi_weekly: Decimal | None
    roi_monthly: Decimal | None
    roi_yearly: Decimal | None
    roi_all_time: Decimal | None
    cagr: Decimal | None


class RiskMetrics(BaseModel):
    max_drawdown: Decimal | None
    avg_drawdown: Decimal | None
    volatility_daily: Decimal | None
    volatility_annualized: Decimal | None
    downside_deviation: Decimal | None
    var_95: Decimal | None
    var_99: Decimal | None


class RiskAdjustedMetrics(BaseModel):
    sharpe_ratio: Decimal | None
    sortino_ratio: Decimal | None
    calmar_ratio: Decimal | None


class TradeQualityMetrics(BaseModel):
    total_trades: int | None
    winning_trades: int | None
    losing_trades: int | None
    win_rate: Decimal | None
    loss_rate: Decimal | None
    profit_factor: Decimal | None
    expectancy_usd: Decimal | None
    avg_win_usd: Decimal | None
    avg_loss_usd: Decimal | None
    avg_win_loss_ratio: Decimal | None
    avg_holding_hours: Decimal | None


class PortfolioStructureMetrics(BaseModel):
    diversification_score: Decimal | None
    concentration_risk: Decimal | None
    btc_exposure_pct: Decimal | None
    eth_exposure_pct: Decimal | None
    stablecoin_pct: Decimal | None


class MarketMetrics(BaseModel):
    beta_vs_btc: Decimal | None
    alpha_vs_btc: Decimal | None
    correlation_vs_btc: Decimal | None
    fear_greed_score: int | None


class BehavioralMetricsResponse(BaseModel):
    overtrading_score: Decimal | None
    avg_trades_per_day: Decimal | None
    revenge_trade_count: int
    revenge_trade_loss_usd: Decimal
    fomo_trade_count: int
    fomo_trade_loss_usd: Decimal
    panic_sell_count: int
    panic_sell_loss_usd: Decimal
    best_performing_hour: int | None
    worst_performing_hour: int | None
    best_performing_day: int | None
    worst_performing_day: int | None
    discipline_score: Decimal | None


class FullAnalyticsResponse(BaseModel):
    computed_at: datetime
    period_days: int
    performance: PerformanceMetrics
    risk: RiskMetrics
    risk_adjusted: RiskAdjustedMetrics
    trade_quality: TradeQualityMetrics
    portfolio_structure: PortfolioStructureMetrics
    market: MarketMetrics
    behavioral: BehavioralMetricsResponse


class ReturnSeriesPoint(BaseModel):
    date: str
    value: Decimal
    daily_return: Decimal | None


class DrawdownPoint(BaseModel):
    date: str
    drawdown: Decimal
