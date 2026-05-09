from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ConnectExchangeRequest(BaseModel):
    exchange: str = Field(..., pattern=r"^(binance|bybit|kucoin)$")
    api_key: str = Field(..., min_length=10)
    api_secret: str = Field(..., min_length=10)
    api_passphrase: str | None = Field(default=None)
    label: str = Field(default="My Account", max_length=100)

    @property
    def passphrase(self) -> str | None:
        return self.api_passphrase


class ExchangeAccountResponse(BaseModel):
    id: UUID
    exchange: str
    label: str
    is_active: bool
    last_synced_at: datetime | None
    sync_error: str | None

    model_config = {"from_attributes": True}


class HoldingItem(BaseModel):
    symbol: str
    name: str | None
    quantity: float
    avg_buy_price: float
    current_price: float
    value_usd: float
    unrealized_pnl_usd: float
    unrealized_pnl_pct: float
    allocation_pct: float


class PortfolioSummary(BaseModel):
    total_value_usd: float
    total_pnl_usd: float
    total_pnl_pct: float
    daily_change_usd: float
    daily_change_pct: float
    holdings: list[HoldingItem]
    last_updated: datetime


class TradeResponse(BaseModel):
    id: UUID
    symbol: str
    side: str
    price: float
    quantity: float
    quote_quantity: float
    fee: float
    fee_asset: str | None
    realized_pnl: float | None
    executed_at: datetime

    model_config = {"from_attributes": True}


class SyncStatusResponse(BaseModel):
    exchange_account_id: str
    status: str
    trades_synced: int
    message: str
