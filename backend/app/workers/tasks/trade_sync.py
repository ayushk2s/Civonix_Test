"""
Trade synchronization tasks.
Fetches new trades from exchanges and stores them in the database.
"""
import asyncio
import uuid
from datetime import datetime, timezone

import structlog
from sqlalchemy import select, update

from app.database import AsyncSessionLocal
from app.models.exchange import ExchangeAccount
from app.models.trade import Trade
from app.models.user import User
from app.services.exchange_service import ExchangeService
from app.workers.celery_app import celery

log = structlog.get_logger()


async def run_sync_now(account_id: str) -> None:
    """Called directly by FastAPI BackgroundTasks — no Celery needed."""
    await _sync_account_async(account_id)


@celery.task(bind=True, max_retries=3, default_retry_delay=300)
def sync_exchange_account(self, account_id: str):
    """Celery task wrapper (only used when Celery/Redis is running)."""
    asyncio.get_event_loop().run_until_complete(_sync_account_async(account_id))


async def _sync_account_async(account_id: str):
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(ExchangeAccount).where(ExchangeAccount.id == account_id)
        )
        account = result.scalar_one_or_none()
        if not account or not account.is_active:
            log.warning("Account not found or inactive", account_id=account_id)
            return

        log.info("Starting trade sync", account_id=account_id, exchange=account.exchange)

        # Get last sync timestamp
        last_ms = None
        if account.last_synced_at:
            last_ms = int(account.last_synced_at.timestamp() * 1000)

        try:
            svc = ExchangeService.from_account(account)

            # Get symbols with balances + those that have been traded
            symbols = await _get_symbols_to_sync(svc, account.user_id, db)

            # Fetch trades
            new_trades = await svc.fetch_all_user_trades(symbols, last_sync_ms=last_ms)
            synced = 0

            for trade in new_trades:
                # Upsert trade
                existing = await db.execute(
                    select(Trade).where(
                        Trade.exchange_account_id == account.id,
                        Trade.exchange_trade_id == trade.trade_id,
                    )
                )
                if existing.scalar_one_or_none():
                    continue

                db_trade = Trade(
                    user_id=account.user_id,
                    exchange_account_id=account.id,
                    exchange_trade_id=trade.trade_id,
                    symbol=trade.symbol,
                    base_asset=trade.base_asset,
                    quote_asset=trade.quote_asset,
                    side=trade.side,
                    price=trade.price,
                    quantity=trade.quantity,
                    quote_quantity=trade.quote_quantity,
                    fee=trade.fee,
                    fee_asset=trade.fee_asset,
                    realized_pnl=trade.realized_pnl,
                    executed_at=trade.executed_at,
                )
                db.add(db_trade)
                synced += 1

            await db.commit()

            # Update last sync time
            await db.execute(
                update(ExchangeAccount)
                .where(ExchangeAccount.id == account.id)
                .values(last_synced_at=datetime.now(timezone.utc), sync_error=None)
            )
            await db.commit()

            log.info("Trade sync completed", account_id=account_id, new_trades=synced)

            # Recalculate metrics + generate AI insights inline (no Celery needed)
            from app.workers.tasks.metrics_calculation import run_metrics_now
            await run_metrics_now(str(account.user_id))

        except Exception as e:
            log.error("Trade sync failed", account_id=account_id, error=str(e))
            await db.execute(
                update(ExchangeAccount)
                .where(ExchangeAccount.id == account.id)
                .values(sync_error=str(e)[:500])
            )
            await db.commit()
            raise


async def _get_symbols_to_sync(svc: ExchangeService, user_id: uuid.UUID, db) -> list[str]:
    """Get symbols to sync: current non-stable balances + previously traded."""
    holdings = await svc.get_account_balances()
    stables = {"USDT", "USDC", "BUSD", "DAI", "FDUSD", "TUSD"}
    is_kucoin = svc.exchange_name == "kucoin"

    symbols: set[str] = set()
    for b in holdings:
        asset = b["asset"]
        if asset in stables:
            continue
        # KuCoin uses "ASSET-USDT" format; Binance/Bybit use "ASSETUSDT"
        symbols.add(f"{asset}-USDT" if is_kucoin else f"{asset}USDT")

    # Include symbols already stored in the trades table for this account
    result = await db.execute(
        select(Trade.symbol).where(Trade.user_id == user_id).distinct()
    )
    symbols.update(r[0] for r in result.all())
    return list(symbols)


@celery.task
def sync_all_active_exchanges():
    """Hourly task: sync all active exchange accounts."""
    asyncio.get_event_loop().run_until_complete(_sync_all_async())


async def _sync_all_async():
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(ExchangeAccount).where(ExchangeAccount.is_active == True)
        )
        accounts = result.scalars().all()
        log.info("Syncing all accounts", count=len(accounts))
        for account in accounts:
            sync_exchange_account.delay(str(account.id))
