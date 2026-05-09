from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.portfolio import AiInsight, BehavioralMetrics, PortfolioMetrics
from app.models.user import User
from app.schemas.ai_insight import AiInsightResponse, MarkInsightReadRequest, WhyLosingMoneyReport
from app.services.analytics_engine import PortfolioMetricsResult
from app.services.behavioral_engine import BehavioralResult

router = APIRouter()


def _db_metrics_to_result(m: PortfolioMetrics) -> PortfolioMetricsResult:
    r = PortfolioMetricsResult()
    fields = r.__dataclass_fields__.keys()
    for f in fields:
        setattr(r, f, getattr(m, f, None))
    return r


def _db_behavioral_to_result(b: BehavioralMetrics | None) -> BehavioralResult:
    r = BehavioralResult()
    if not b:
        return r
    r.overtrading_score = float(b.overtrading_score or 0)
    r.avg_trades_per_day = float(b.avg_trades_per_day or 0)
    r.revenge_trade_count = b.revenge_trade_count or 0
    r.revenge_trade_loss_usd = float(b.revenge_trade_loss_usd or 0)
    r.fomo_trade_count = b.fomo_trade_count or 0
    r.fomo_trade_loss_usd = float(b.fomo_trade_loss_usd or 0)
    r.panic_sell_count = b.panic_sell_count or 0
    r.panic_sell_loss_usd = float(b.panic_sell_loss_usd or 0)
    r.best_performing_hour = b.best_performing_hour
    r.worst_performing_hour = b.worst_performing_hour
    r.best_performing_day = b.best_performing_day
    r.worst_performing_day = b.worst_performing_day
    r.discipline_score = float(b.discipline_score or 100)
    return r


@router.get("/insights", response_model=list[AiInsightResponse])
async def get_insights(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    unread_only: bool = False,
    limit: int = 20,
):
    query = (
        select(AiInsight)
        .where(AiInsight.user_id == user.id, AiInsight.is_dismissed == False)
        .order_by(AiInsight.created_at.desc())
        .limit(limit)
    )
    if unread_only:
        query = query.where(AiInsight.is_read == False)
    result = await db.execute(query)
    return result.scalars().all()


@router.post("/insights/generate")
async def generate_insights(
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Triggers metrics recalc + AI insight generation. No Redis needed."""
    from app.workers.tasks.metrics_calculation import run_metrics_now
    background_tasks.add_task(run_metrics_now, str(user.id))
    return {"message": "Metrics and insight generation started"}


@router.post("/insights/read", status_code=204)
async def mark_read(
    body: MarkInsightReadRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(AiInsight)
        .where(
            AiInsight.id.in_(body.insight_ids),
            AiInsight.user_id == user.id,
        )
        .values(is_read=True)
    )
    await db.commit()


@router.post("/insights/{insight_id}/dismiss", status_code=204)
async def dismiss_insight(
    insight_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AiInsight).where(
            AiInsight.id == insight_id,
            AiInsight.user_id == user.id,
        )
    )
    insight = result.scalar_one_or_none()
    if insight:
        insight.is_dismissed = True
        await db.commit()


@router.get("/why-losing", response_model=WhyLosingMoneyReport)
async def why_losing_money(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Generates a real-time AI report explaining why the user is losing money."""
    from app.services.ai_service import generate_why_losing_money_report
    from datetime import datetime, timezone

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

    report = await generate_why_losing_money_report(
        _db_metrics_to_result(metrics),
        _db_behavioral_to_result(behavioral),
    )

    if "error" in report:
        raise HTTPException(status_code=503, detail=report["error"])

    return {**report, "generated_at": datetime.now(timezone.utc)}
