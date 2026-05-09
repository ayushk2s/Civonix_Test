import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Integer, Numeric, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PortfolioSnapshot(Base):
    __tablename__ = "portfolio_snapshots"

    id:              Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:         Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    snapshot_date:   Mapped[date]              = mapped_column(Date, nullable=False)
    total_value_usd: Mapped[Decimal]           = mapped_column(Numeric(20, 4), nullable=False)
    btc_price_usd:   Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    daily_return:    Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    holdings:        Mapped[dict]              = mapped_column(JSONB, default={})
    created_at:      Mapped[datetime]          = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User")


class PortfolioMetrics(Base):
    __tablename__ = "portfolio_metrics"

    id:                    Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:               Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    computed_at:           Mapped[datetime]          = mapped_column(DateTime(timezone=True), server_default=func.now())
    period_days:           Mapped[int]               = mapped_column(Integer, default=365)

    total_pnl_usd:         Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    realized_pnl_usd:      Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    unrealized_pnl_usd:    Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    roi_daily:             Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    roi_weekly:            Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    roi_monthly:           Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    roi_yearly:            Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    roi_all_time:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    cagr:                  Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))

    max_drawdown:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    avg_drawdown:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    volatility_daily:      Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    volatility_annualized: Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    downside_deviation:    Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    var_95:                Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    var_99:                Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))

    sharpe_ratio:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    sortino_ratio:         Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    calmar_ratio:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))

    total_trades:          Mapped[int | None]        = mapped_column(Integer)
    winning_trades:        Mapped[int | None]        = mapped_column(Integer)
    losing_trades:         Mapped[int | None]        = mapped_column(Integer)
    win_rate:              Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    loss_rate:             Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    profit_factor:         Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    expectancy_usd:        Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    avg_win_usd:           Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    avg_loss_usd:          Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    avg_win_loss_ratio:    Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    avg_holding_hours:     Mapped[Decimal | None]    = mapped_column(Numeric(12, 4))

    diversification_score: Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    concentration_risk:    Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    btc_exposure_pct:      Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    eth_exposure_pct:      Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    stablecoin_pct:        Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))

    beta_vs_btc:           Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    alpha_vs_btc:          Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    correlation_vs_btc:    Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    fear_greed_score:      Mapped[int | None]        = mapped_column(Integer)

    user = relationship("User", back_populates="portfolio_metrics")


class BehavioralMetrics(Base):
    __tablename__ = "behavioral_metrics"

    id:                       Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:                  Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    computed_at:              Mapped[datetime]          = mapped_column(DateTime(timezone=True), server_default=func.now())

    overtrading_score:        Mapped[Decimal | None]    = mapped_column(Numeric(8, 4))
    avg_trades_per_day:       Mapped[Decimal | None]    = mapped_column(Numeric(8, 4))
    revenge_trade_count:      Mapped[int]               = mapped_column(Integer, default=0)
    revenge_trade_loss_usd:   Mapped[Decimal]           = mapped_column(Numeric(20, 4), default=0)
    fomo_trade_count:         Mapped[int]               = mapped_column(Integer, default=0)
    fomo_trade_loss_usd:      Mapped[Decimal]           = mapped_column(Numeric(20, 4), default=0)
    panic_sell_count:         Mapped[int]               = mapped_column(Integer, default=0)
    panic_sell_loss_usd:      Mapped[Decimal]           = mapped_column(Numeric(20, 4), default=0)
    best_performing_hour:     Mapped[int | None]        = mapped_column(Integer)
    worst_performing_hour:    Mapped[int | None]        = mapped_column(Integer)
    best_performing_day:      Mapped[int | None]        = mapped_column(Integer)
    worst_performing_day:     Mapped[int | None]        = mapped_column(Integer)
    discipline_score:         Mapped[Decimal | None]    = mapped_column(Numeric(8, 4))

    user = relationship("User", back_populates="behavioral_metrics")


class AiInsight(Base):
    __tablename__ = "ai_insights"

    id:           Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:      Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    category:     Mapped[str]              = mapped_column(String(50), nullable=False)
    severity:     Mapped[str]              = mapped_column(String(20), default="info")
    title:        Mapped[str]              = mapped_column(Text, nullable=False)
    body:         Mapped[str]              = mapped_column(Text, nullable=False)
    action_items: Mapped[list]             = mapped_column(JSONB, default=[])
    metrics_used: Mapped[dict]             = mapped_column(JSONB, default={})
    is_read:      Mapped[bool]             = mapped_column(Boolean, default=False)
    is_dismissed: Mapped[bool]             = mapped_column(Boolean, default=False)
    expires_at:   Mapped[datetime | None]  = mapped_column(DateTime(timezone=True))
    created_at:   Mapped[datetime]         = mapped_column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="ai_insights")


class LeaderboardEntry(Base):
    __tablename__ = "leaderboard_entries"

    id:                Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:           Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    scope:             Mapped[str]              = mapped_column(String(20), nullable=False)
    scope_value:       Mapped[str]              = mapped_column(String(100), nullable=False)
    rank:              Mapped[int | None]        = mapped_column(Integer)
    roi_30d:           Mapped[Decimal | None]    = mapped_column(Numeric(12, 8))
    sharpe_ratio:      Mapped[Decimal | None]    = mapped_column(Numeric(12, 6))
    win_rate:          Mapped[Decimal | None]    = mapped_column(Numeric(8, 6))
    total_pnl_usd:     Mapped[Decimal | None]    = mapped_column(Numeric(20, 4))
    winning_streak:    Mapped[int]               = mapped_column(Integer, default=0)
    losing_streak:     Mapped[int]               = mapped_column(Integer, default=0)
    consistency_score: Mapped[Decimal | None]    = mapped_column(Numeric(8, 4))
    updated_at:        Mapped[datetime]          = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="leaderboard_entries")
