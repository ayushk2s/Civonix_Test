from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.core.exceptions import ExchangeError
from app.core.security import encrypt_api_key
from app.database import get_db
from app.models.exchange import ExchangeAccount
from app.models.user import User
from app.schemas.portfolio import (
    ConnectExchangeRequest,
    ExchangeAccountResponse,
    PortfolioSummary,
    SyncStatusResponse,
    TradeResponse,
)
from app.services.exchange_service import ExchangeService
from app.workers.tasks.trade_sync import run_sync_now

router = APIRouter()


@router.post("/exchange/connect", response_model=ExchangeAccountResponse, status_code=201)
async def connect_exchange(
    body: ConnectExchangeRequest,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # KuCoin requires passphrase
    if body.exchange == "kucoin" and not body.api_passphrase:
        raise HTTPException(status_code=400, detail="KuCoin requires an API passphrase")

    # Validate keys before storing
    svc = ExchangeService(
        exchange=body.exchange,
        api_key=body.api_key,
        api_secret=body.api_secret,
        passphrase=body.api_passphrase,
    )
    if not await svc.validate_api_keys():
        raise HTTPException(
            status_code=400,
            detail=f"Invalid {body.exchange.title()} API keys. Ensure read-only permissions are enabled.",
        )

    # Deactivate any existing active account for the same exchange to avoid duplicates
    await db.execute(
        update(ExchangeAccount)
        .where(
            ExchangeAccount.user_id == user.id,
            ExchangeAccount.exchange == body.exchange,
            ExchangeAccount.is_active == True,
        )
        .values(is_active=False)
    )

    account = ExchangeAccount(
        user_id=user.id,
        exchange=body.exchange,
        label=body.label,
        api_key_encrypted=encrypt_api_key(body.api_key),
        api_secret_encrypted=encrypt_api_key(body.api_secret),
        passphrase_encrypted=encrypt_api_key(body.api_passphrase) if body.api_passphrase else None,
    )
    db.add(account)
    await db.commit()
    await db.refresh(account)

    # Trigger initial sync in background (direct async, no Celery needed)
    background_tasks.add_task(run_sync_now, str(account.id))

    return account


@router.get("/exchange", response_model=list[ExchangeAccountResponse])
async def list_exchanges(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExchangeAccount).where(
            ExchangeAccount.user_id == user.id,
            ExchangeAccount.is_active == True,
        )
    )
    return result.scalars().all()


@router.delete("/exchange/{account_id}", status_code=204)
async def disconnect_exchange(
    account_id: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(ExchangeAccount).where(
            ExchangeAccount.id == account_id,
            ExchangeAccount.user_id == user.id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Exchange account not found")
    account.is_active = False
    await db.commit()


@router.get("/summary", response_model=PortfolioSummary)
async def portfolio_summary(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Returns current portfolio value, PnL, and holdings with live prices."""
    from app.redis_client import cache_get, cache_set
    cache_key = f"portfolio:summary:{user.id}"
    cached = await cache_get(cache_key)
    if cached:
        return cached

    accounts_result = await db.execute(
        select(ExchangeAccount).where(
            ExchangeAccount.user_id == user.id,
            ExchangeAccount.is_active == True,
        )
    )
    accounts = accounts_result.scalars().all()
    if not accounts:
        raise HTTPException(status_code=404, detail="No connected exchanges")

    # Aggregate holdings from all accounts
    from datetime import datetime, timezone
    from decimal import Decimal
    import asyncio

    import structlog as _log
    _logger = _log.get_logger()

    all_holdings: dict = {}
    for account in accounts:
        try:
            svc = ExchangeService.from_account(account)
            holdings = await svc.get_current_holdings_with_prices()
            for symbol, data in holdings.items():
                if symbol in all_holdings:
                    all_holdings[symbol]["qty"] += data["qty"]
                    all_holdings[symbol]["value_usd"] += data["value_usd"]
                else:
                    all_holdings[symbol] = data.copy()
        except Exception as e:
            import traceback
            _logger.warning("Failed to fetch holdings for account",
                            account_id=str(account.id),
                            exchange=account.exchange,
                            error=str(e),
                            trace=traceback.format_exc()[-500:])
            continue

    if not all_holdings:
        raise HTTPException(status_code=503, detail="Could not fetch live holdings from any exchange. Please try again.")

    total_value = sum(h["value_usd"] for h in all_holdings.values())

    from app.models.portfolio import PortfolioMetrics as PM
    metrics_result = await db.execute(select(PM).where(PM.user_id == user.id))
    metrics = metrics_result.scalar_one_or_none()

    from app.schemas.portfolio import HoldingItem
    holdings_list = []
    for symbol, h in all_holdings.items():
        qty = float(h["qty"])
        price = float(h["current_price"])
        value = float(h["value_usd"])
        allocation = value / total_value if total_value > 0 else 0.0
        holdings_list.append(HoldingItem(
            symbol=symbol,
            name=symbol,
            quantity=qty,
            avg_buy_price=0.0,
            current_price=price,
            value_usd=value,
            unrealized_pnl_usd=0.0,
            unrealized_pnl_pct=0.0,
            allocation_pct=allocation,
        ))

    summary = PortfolioSummary(
        total_value_usd=float(total_value),
        total_pnl_usd=float(metrics.total_pnl_usd or 0) if metrics else 0.0,
        total_pnl_pct=float(metrics.roi_all_time or 0) if metrics else 0.0,
        daily_change_usd=float(metrics.roi_daily or 0) if metrics else 0.0,
        daily_change_pct=float(metrics.roi_daily or 0) if metrics else 0.0,
        holdings=sorted(holdings_list, key=lambda x: x.value_usd, reverse=True),
        last_updated=datetime.now(timezone.utc),
    )

    await cache_set(cache_key, summary.model_dump(mode="json"), ttl=60)
    return summary


@router.get("/trades", response_model=list[TradeResponse])
async def get_trades(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 100,
    offset: int = 0,
):
    from app.models.trade import Trade
    result = await db.execute(
        select(Trade)
        .where(Trade.user_id == user.id)
        .order_by(Trade.executed_at.desc())
        .limit(limit)
        .offset(offset)
    )
    return result.scalars().all()


@router.post("/sync/{account_id}", response_model=SyncStatusResponse)
async def trigger_sync(
    account_id: str,
    background_tasks: BackgroundTasks,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    full: bool = False,
):
    result = await db.execute(
        select(ExchangeAccount).where(
            ExchangeAccount.id == account_id,
            ExchangeAccount.user_id == user.id,
        )
    )
    account = result.scalar_one_or_none()
    if not account:
        raise HTTPException(status_code=404, detail="Exchange account not found")

    # Full resync: clear last_synced_at so the worker fetches all history
    if full:
        await db.execute(
            update(ExchangeAccount)
            .where(ExchangeAccount.id == account_id)
            .values(last_synced_at=None, sync_error=None)
        )
        await db.commit()

    background_tasks.add_task(run_sync_now, account_id)
    return SyncStatusResponse(
        exchange_account_id=account_id,
        status="queued",
        trades_synced=0,
        message="Full resync started" if full else "Sync started in background",
    )
