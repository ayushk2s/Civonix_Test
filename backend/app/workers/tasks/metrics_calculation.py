"""
Metrics calculation tasks.
Computes analytics, behavioral, and AI insights for users.
"""
import asyncio
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import structlog
from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.database import AsyncSessionLocal
from app.models.portfolio import (
    AiInsight,
    BehavioralMetrics,
    PortfolioMetrics,
    PortfolioSnapshot,
)
from app.models.trade import Trade
from app.models.user import User
from app.services.analytics_engine import AnalyticsEngine, SnapshotRecord, TradeRecord
from app.services.behavioral_engine import BehavioralEngine
from app.workers.celery_app import celery

log = structlog.get_logger()


async def run_metrics_now(user_id: str) -> None:
    """Called directly by FastAPI BackgroundTasks — no Celery/Redis needed."""
    await _recalc_async(user_id)
    await _generate_ai_insights_async(user_id)


@celery.task(bind=True, max_retries=3, default_retry_delay=60)
def recalculate_user_metrics(self, user_id: str):
    asyncio.get_event_loop().run_until_complete(_recalc_async(user_id))


async def _recalc_async(user_id: str):
    async with AsyncSessionLocal() as db:
        log.info("Recalculating metrics", user_id=user_id)

        # Load all trades
        result = await db.execute(
            select(Trade).where(Trade.user_id == user_id).order_by(Trade.executed_at.asc())
        )
        db_trades = result.scalars().all()
        if not db_trades:
            log.info("No trades found, skipping", user_id=user_id)
            return

        trades = [
            TradeRecord(
                trade_id=str(t.id),
                symbol=t.symbol,
                base_asset=t.base_asset,
                quote_asset=t.quote_asset,
                side=t.side,
                price=float(t.price),
                quantity=float(t.quantity),
                quote_quantity=float(t.quote_quantity),
                fee=float(t.fee),
                fee_asset=t.fee_asset or "USDT",
                executed_at=t.executed_at,
                realized_pnl=float(t.realized_pnl) if t.realized_pnl is not None else None,
            )
            for t in db_trades
        ]

        # Load portfolio snapshots
        snap_result = await db.execute(
            select(PortfolioSnapshot)
            .where(PortfolioSnapshot.user_id == user_id)
            .order_by(PortfolioSnapshot.snapshot_date.asc())
        )
        db_snaps = snap_result.scalars().all()
        snapshots = [
            SnapshotRecord(
                snapshot_date=s.snapshot_date,
                total_value_usd=float(s.total_value_usd),
                daily_return=float(s.daily_return) if s.daily_return is not None else None,
            )
            for s in db_snaps
        ]

        # Fetch BTC returns for market comparison
        try:
            from app.models.exchange import ExchangeAccount
            acc_result = await db.execute(
                select(ExchangeAccount).where(
                    ExchangeAccount.user_id == user_id,
                    ExchangeAccount.is_active == True,
                ).limit(1)
            )
            account = acc_result.scalar_one_or_none()
            btc_returns = []
            if account:
                from app.services.exchange_service import ExchangeService
                svc = ExchangeService.from_account(account)
                btc_returns = await svc.get_btc_daily_returns(365)
        except Exception as e:
            log.warning("Could not fetch BTC returns", error=str(e))
            btc_returns = []

        # Run analytics engine
        engine = AnalyticsEngine(trades, snapshots, {}, btc_returns)
        metrics_result = engine.compute()

        # Run behavioral engine
        behavioral_engine = BehavioralEngine(trades)
        behavioral_result = behavioral_engine.analyze()

        # Upsert portfolio metrics
        metrics_data = {k: v for k, v in metrics_result.__dict__.items() if v is not None}
        metrics_data["computed_at"] = datetime.now(timezone.utc)
        metrics_data["user_id"] = user_id

        await db.execute(
            pg_insert(PortfolioMetrics)
            .values(**metrics_data)
            .on_conflict_do_update(
                index_elements=["user_id"],
                set_=metrics_data,
            )
        )

        # Upsert behavioral metrics
        behavioral_data = {
            "user_id": user_id,
            "computed_at": datetime.now(timezone.utc),
            "overtrading_score": behavioral_result.overtrading_score,
            "avg_trades_per_day": behavioral_result.avg_trades_per_day,
            "revenge_trade_count": behavioral_result.revenge_trade_count,
            "revenge_trade_loss_usd": behavioral_result.revenge_trade_loss_usd,
            "fomo_trade_count": behavioral_result.fomo_trade_count,
            "fomo_trade_loss_usd": behavioral_result.fomo_trade_loss_usd,
            "panic_sell_count": behavioral_result.panic_sell_count,
            "panic_sell_loss_usd": behavioral_result.panic_sell_loss_usd,
            "best_performing_hour": behavioral_result.best_performing_hour,
            "worst_performing_hour": behavioral_result.worst_performing_hour,
            "best_performing_day": behavioral_result.best_performing_day,
            "worst_performing_day": behavioral_result.worst_performing_day,
            "discipline_score": behavioral_result.discipline_score,
        }

        await db.execute(
            pg_insert(BehavioralMetrics)
            .values(**behavioral_data)
            .on_conflict_do_update(
                index_elements=["user_id"],
                set_=behavioral_data,
            )
        )
        await db.commit()

        # Update leaderboard
        user_result = await db.execute(select(User).where(User.id == user_id))
        user = user_result.scalar_one_or_none()
        if user:
            from app.services.leaderboard_service import LeaderboardService
            metrics_db_result = await db.execute(
                select(PortfolioMetrics).where(PortfolioMetrics.user_id == user_id)
            )
            metrics_db = metrics_db_result.scalar_one_or_none()
            if metrics_db:
                lb_service = LeaderboardService(db)
                await lb_service.update_user_ranking(user, metrics_db)

        log.info("Metrics recalculation completed", user_id=user_id)


@celery.task
def recalculate_all_metrics():
    """Hourly: recalculate metrics for all users."""
    asyncio.get_event_loop().run_until_complete(_recalc_all_async())


async def _recalc_all_async():
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User.id))
        user_ids = [str(r[0]) for r in result.all()]
        for uid in user_ids:
            recalculate_user_metrics.delay(uid)


@celery.task
def take_daily_snapshots():
    """Midnight task: snapshot all portfolio values."""
    asyncio.get_event_loop().run_until_complete(_snapshot_async())


async def _snapshot_async():
    async with AsyncSessionLocal() as db:
        from app.models.exchange import ExchangeAccount
        accounts = (await db.execute(
            select(ExchangeAccount).where(ExchangeAccount.is_active == True)
        )).scalars().all()

        today = date.today()
        for account in accounts:
            try:
                from app.services.exchange_service import ExchangeService
                svc = ExchangeService.from_account(account)
                holdings = await svc.get_current_holdings_with_prices()
                total_usd = sum(h["value_usd"] for h in holdings.values())

                # Compute daily return
                prev_result = await db.execute(
                    select(PortfolioSnapshot)
                    .where(
                        PortfolioSnapshot.user_id == account.user_id,
                        PortfolioSnapshot.snapshot_date == today - timedelta(days=1),
                    )
                )
                prev = prev_result.scalar_one_or_none()
                daily_return = None
                if prev and float(prev.total_value_usd) > 0:
                    daily_return = (total_usd - float(prev.total_value_usd)) / float(prev.total_value_usd)

                snap = PortfolioSnapshot(
                    user_id=account.user_id,
                    snapshot_date=today,
                    total_value_usd=Decimal(str(total_usd)),
                    daily_return=Decimal(str(daily_return)) if daily_return else None,
                    holdings={sym: {"qty": h["qty"], "value_usd": h["value_usd"]} for sym, h in holdings.items()},
                )
                db.add(snap)
            except Exception as e:
                log.error("Snapshot failed", account_id=str(account.id), error=str(e))

        await db.commit()
        log.info("Daily snapshots taken")


@celery.task
def resolve_daily_predictions():
    """Resolves yesterday's daily prediction game."""
    asyncio.get_event_loop().run_until_complete(_resolve_predictions_async())


async def _resolve_predictions_async():
    from sqlalchemy import text
    async with AsyncSessionLocal() as db:
        yesterday = date.today() - timedelta(days=1)
        result = await db.execute(
            text("SELECT id FROM daily_predictions WHERE game_date = :d AND resolved = FALSE"),
            {"d": yesterday},
        )
        row = result.mappings().first()
        if not row:
            return

        pred_id = row["id"]

        # Get BTC price movement
        try:
            import aiohttp
            async with aiohttp.ClientSession() as session:
                async with session.get(
                    "https://api.binance.com/api/v3/klines",
                    params={"symbol": "BTCUSDT", "interval": "1d", "limit": 2},
                ) as resp:
                    data = await resp.json()
            open_price = float(data[0][1])
            close_price = float(data[0][4])
            direction = "up" if close_price > open_price else "down"

            await db.execute(
                text("""
                    UPDATE daily_predictions
                    SET resolved = TRUE, actual_direction = :dir, open_price = :op, close_price = :cp
                    WHERE id = :id
                """),
                {"dir": direction, "op": open_price, "cp": close_price, "id": str(pred_id)},
            )

            # Update is_correct for all user predictions
            await db.execute(
                text("""
                    UPDATE user_predictions
                    SET is_correct = (direction = :dir)
                    WHERE prediction_id = :id
                """),
                {"dir": direction, "id": str(pred_id)},
            )

            # Update user prediction stats
            await db.execute(
                text("""
                    UPDATE users u
                    SET
                        total_predictions = total_predictions + 1,
                        correct_predictions = correct_predictions + CASE WHEN up.is_correct THEN 1 ELSE 0 END
                    FROM user_predictions up
                    WHERE up.user_id = u.id AND up.prediction_id = :id
                """),
                {"id": str(pred_id)},
            )
            await db.commit()
            log.info("Daily predictions resolved", direction=direction)
        except Exception as e:
            log.error("Failed to resolve predictions", error=str(e))


@celery.task
def generate_ai_insights_task(user_id: str):
    asyncio.get_event_loop().run_until_complete(_generate_ai_insights_async(user_id))


async def _generate_ai_insights_async(user_id: str):
    async with AsyncSessionLocal() as db:
        from app.models.portfolio import BehavioralMetrics as BM, PortfolioMetrics as PM
        from app.api.routes.ai_insights import _db_metrics_to_result, _db_behavioral_to_result
        from app.services.ai_service import generate_portfolio_insights

        metrics_result = await db.execute(select(PM).where(PM.user_id == user_id))
        metrics = metrics_result.scalar_one_or_none()
        if not metrics:
            return

        bm_result = await db.execute(select(BM).where(BM.user_id == user_id))
        bm = bm_result.scalar_one_or_none()

        insights = await generate_portfolio_insights(
            _db_metrics_to_result(metrics),
            _db_behavioral_to_result(bm),
        )

        for insight in insights:
            ai = AiInsight(
                user_id=user_id,
                category=insight.get("category", "performance"),
                severity=insight.get("severity", "info"),
                title=insight.get("title", ""),
                body=insight.get("body", ""),
                action_items=insight.get("action_items", []),
                metrics_used={},
            )
            db.add(ai)

        await db.commit()
        log.info("AI insights generated", user_id=user_id, count=len(insights))
