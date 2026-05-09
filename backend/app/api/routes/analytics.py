from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.portfolio import BehavioralMetrics, PortfolioMetrics, PortfolioSnapshot
from app.models.user import User
from app.redis_client import cache_get, cache_set
from app.schemas.analytics import (
    BehavioralMetricsResponse,
    DrawdownPoint,
    FullAnalyticsResponse,
    MarketMetrics,
    PerformanceMetrics,
    PortfolioStructureMetrics,
    ReturnSeriesPoint,
    RiskAdjustedMetrics,
    RiskMetrics,
    TradeQualityMetrics,
)

router = APIRouter()


@router.get("/full", response_model=FullAnalyticsResponse)
async def full_analytics(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    period_days: int = 365,
):
    """Returns all 25+ analytics metrics for the authenticated user."""
    cache_key = f"analytics:full:{user.id}:{period_days}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    metrics_result = await db.execute(
        select(PortfolioMetrics).where(PortfolioMetrics.user_id == user.id)
    )
    metrics = metrics_result.scalar_one_or_none()
    if not metrics:
        raise HTTPException(status_code=404, detail="No analytics data yet. Sync your exchange first.")

    behavioral_result = await db.execute(
        select(BehavioralMetrics).where(BehavioralMetrics.user_id == user.id)
    )
    behavioral = behavioral_result.scalar_one_or_none()

    def d(v):
        return v

    response = FullAnalyticsResponse(
        computed_at=metrics.computed_at,
        period_days=metrics.period_days,
        performance=PerformanceMetrics(
            total_pnl_usd=d(metrics.total_pnl_usd),
            realized_pnl_usd=d(metrics.realized_pnl_usd),
            unrealized_pnl_usd=d(metrics.unrealized_pnl_usd),
            roi_daily=d(metrics.roi_daily),
            roi_weekly=d(metrics.roi_weekly),
            roi_monthly=d(metrics.roi_monthly),
            roi_yearly=d(metrics.roi_yearly),
            roi_all_time=d(metrics.roi_all_time),
            cagr=d(metrics.cagr),
        ),
        risk=RiskMetrics(
            max_drawdown=d(metrics.max_drawdown),
            avg_drawdown=d(metrics.avg_drawdown),
            volatility_daily=d(metrics.volatility_daily),
            volatility_annualized=d(metrics.volatility_annualized),
            downside_deviation=d(metrics.downside_deviation),
            var_95=d(metrics.var_95),
            var_99=d(metrics.var_99),
        ),
        risk_adjusted=RiskAdjustedMetrics(
            sharpe_ratio=d(metrics.sharpe_ratio),
            sortino_ratio=d(metrics.sortino_ratio),
            calmar_ratio=d(metrics.calmar_ratio),
        ),
        trade_quality=TradeQualityMetrics(
            total_trades=metrics.total_trades,
            winning_trades=metrics.winning_trades,
            losing_trades=metrics.losing_trades,
            win_rate=d(metrics.win_rate),
            loss_rate=d(metrics.loss_rate),
            profit_factor=d(metrics.profit_factor),
            expectancy_usd=d(metrics.expectancy_usd),
            avg_win_usd=d(metrics.avg_win_usd),
            avg_loss_usd=d(metrics.avg_loss_usd),
            avg_win_loss_ratio=d(metrics.avg_win_loss_ratio),
            avg_holding_hours=d(metrics.avg_holding_hours),
        ),
        portfolio_structure=PortfolioStructureMetrics(
            diversification_score=d(metrics.diversification_score),
            concentration_risk=d(metrics.concentration_risk),
            btc_exposure_pct=d(metrics.btc_exposure_pct),
            eth_exposure_pct=d(metrics.eth_exposure_pct),
            stablecoin_pct=d(metrics.stablecoin_pct),
        ),
        market=MarketMetrics(
            beta_vs_btc=d(metrics.beta_vs_btc),
            alpha_vs_btc=d(metrics.alpha_vs_btc),
            correlation_vs_btc=d(metrics.correlation_vs_btc),
            fear_greed_score=metrics.fear_greed_score,
        ),
        behavioral=BehavioralMetricsResponse(
            overtrading_score=d(behavioral.overtrading_score) if behavioral else None,
            avg_trades_per_day=d(behavioral.avg_trades_per_day) if behavioral else None,
            revenge_trade_count=behavioral.revenge_trade_count if behavioral else 0,
            revenge_trade_loss_usd=behavioral.revenge_trade_loss_usd if behavioral else 0,
            fomo_trade_count=behavioral.fomo_trade_count if behavioral else 0,
            fomo_trade_loss_usd=behavioral.fomo_trade_loss_usd if behavioral else 0,
            panic_sell_count=behavioral.panic_sell_count if behavioral else 0,
            panic_sell_loss_usd=behavioral.panic_sell_loss_usd if behavioral else 0,
            best_performing_hour=behavioral.best_performing_hour if behavioral else None,
            worst_performing_hour=behavioral.worst_performing_hour if behavioral else None,
            best_performing_day=behavioral.best_performing_day if behavioral else None,
            worst_performing_day=behavioral.worst_performing_day if behavioral else None,
            discipline_score=d(behavioral.discipline_score) if behavioral else None,
        ),
    )

    await cache_set(cache_key, response.model_dump(mode="json"), ttl=300)
    return response


@router.get("/returns", response_model=list[ReturnSeriesPoint])
async def return_series(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    days: int = 90,
):
    """Returns daily portfolio value series for charting."""
    from datetime import date, timedelta
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(PortfolioSnapshot)
        .where(
            PortfolioSnapshot.user_id == user.id,
            PortfolioSnapshot.snapshot_date >= cutoff,
        )
        .order_by(PortfolioSnapshot.snapshot_date.asc())
    )
    snaps = result.scalars().all()
    return [
        ReturnSeriesPoint(
            date=str(s.snapshot_date),
            value=s.total_value_usd,
            daily_return=s.daily_return,
        )
        for s in snaps
    ]


@router.get("/drawdown", response_model=list[DrawdownPoint])
async def drawdown_series(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    days: int = 90,
):
    """Returns drawdown series from peak for the given period."""
    from datetime import date, timedelta
    cutoff = date.today() - timedelta(days=days)
    result = await db.execute(
        select(PortfolioSnapshot)
        .where(
            PortfolioSnapshot.user_id == user.id,
            PortfolioSnapshot.snapshot_date >= cutoff,
        )
        .order_by(PortfolioSnapshot.snapshot_date.asc())
    )
    snaps = result.scalars().all()
    if not snaps:
        return []

    peak = float(snaps[0].total_value_usd)
    points = []
    for s in snaps:
        v = float(s.total_value_usd)
        if v > peak:
            peak = v
        dd = (peak - v) / peak if peak > 0 else 0.0
        points.append(DrawdownPoint(date=str(s.snapshot_date), drawdown=dd))
    return points
