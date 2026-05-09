"""
Civonix Binance Service
Handles all Binance API interactions in read-only mode.
Uses python-binance for authenticated calls and public endpoints for prices.
"""
from __future__ import annotations

import asyncio
import hashlib
import hmac
import time
from datetime import datetime, timezone
from urllib.parse import urlencode

import aiohttp
import structlog

from app.config import settings
from app.core.exceptions import ExchangeError
from app.core.security import decrypt_api_key
from app.services.analytics_engine import TradeRecord

log = structlog.get_logger()

BINANCE_BASE = "https://api.binance.com"
BINANCE_TESTNET = "https://testnet.binance.vision"


class BinanceService:
    def __init__(self, api_key_encrypted: str, api_secret_encrypted: str):
        self.api_key = decrypt_api_key(api_key_encrypted)
        self.api_secret = decrypt_api_key(api_secret_encrypted)
        self.base_url = BINANCE_TESTNET if settings.BINANCE_TESTNET else BINANCE_BASE

    # ── Signature ─────────────────────────────────────────────────────────────

    def _sign(self, params: dict) -> dict:
        params["timestamp"] = int(time.time() * 1000)
        params["recvWindow"] = 5000
        query = urlencode(params)
        sig = hmac.new(
            self.api_secret.encode("utf-8"),
            query.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()
        params["signature"] = sig
        return params

    def _headers(self) -> dict:
        return {"X-MBX-APIKEY": self.api_key, "Content-Type": "application/json"}

    # ── HTTP ──────────────────────────────────────────────────────────────────

    async def _get(self, path: str, params: dict | None = None, signed: bool = False) -> dict | list:
        url = f"{self.base_url}{path}"
        p = params or {}
        if signed:
            p = self._sign(p)
        async with aiohttp.ClientSession() as session:
            async with session.get(url, params=p, headers=self._headers()) as resp:
                data = await resp.json()
                if isinstance(data, dict) and "code" in data and data["code"] < 0:
                    raise ExchangeError(f"Binance error {data['code']}: {data.get('msg')}")
                return data

    # ── Account ───────────────────────────────────────────────────────────────

    async def validate_api_keys(self) -> bool:
        """Verify API keys work. Read-only permissions only needed."""
        try:
            data = await self._get("/api/v3/account", signed=True)
            return isinstance(data, dict) and "balances" in data
        except Exception as e:
            log.warning("Binance key validation failed", error=str(e))
            return False

    async def get_account_balances(self) -> list[dict]:
        """Return all non-zero asset balances."""
        data = await self._get("/api/v3/account", signed=True)
        return [
            {
                "asset": b["asset"],
                "free": float(b["free"]),
                "locked": float(b["locked"]),
                "total": float(b["free"]) + float(b["locked"]),
            }
            for b in data.get("balances", [])
            if float(b["free"]) + float(b["locked"]) > 0
        ]

    # ── Trades ────────────────────────────────────────────────────────────────

    async def get_all_symbols(self) -> list[str]:
        """Get all USDT trading pairs."""
        data = await self._get("/api/v3/exchangeInfo")
        return [
            s["symbol"]
            for s in data.get("symbols", [])
            if s["quoteAsset"] in ("USDT", "BUSD", "USDC")
            and s["status"] == "TRADING"
        ]

    async def get_my_trades(self, symbol: str, start_time_ms: int | None = None) -> list[dict]:
        """Fetch all user trades for a symbol."""
        params: dict = {"symbol": symbol, "limit": 1000}
        if start_time_ms:
            params["startTime"] = start_time_ms

        all_trades = []
        while True:
            batch = await self._get("/api/v3/myTrades", params=params, signed=True)
            if not batch:
                break
            all_trades.extend(batch)
            if len(batch) < 1000:
                break
            # Paginate: use last trade time + 1ms
            params["startTime"] = batch[-1]["time"] + 1
            await asyncio.sleep(0.05)  # respect rate limits

        return all_trades

    async def fetch_all_user_trades(
        self,
        symbols: list[str],
        last_sync_ms: int | None = None,
    ) -> list[TradeRecord]:
        """
        Fetch trades for all held symbols. Converts Binance format to TradeRecord.
        Computes realized PnL using FIFO matching.
        """
        all_records: list[TradeRecord] = []

        for symbol in symbols:
            try:
                raw = await self.get_my_trades(symbol, start_time_ms=last_sync_ms)
                for t in raw:
                    base = t["symbol"].replace(t.get("quoteAsset", "USDT"), "")
                    # Binance gives isBuyer
                    side = "buy" if t["isBuyer"] else "sell"
                    qty = float(t["qty"])
                    price = float(t["price"])

                    record = TradeRecord(
                        trade_id=str(t["id"]),
                        symbol=t["symbol"],
                        base_asset=base,
                        quote_asset=t.get("quoteAsset", "USDT"),
                        side=side,
                        price=price,
                        quantity=qty,
                        quote_quantity=float(t["quoteQty"]),
                        fee=float(t["commission"]),
                        fee_asset=t["commissionAsset"],
                        executed_at=datetime.fromtimestamp(t["time"] / 1000, tz=timezone.utc),
                    )
                    all_records.append(record)
            except ExchangeError as e:
                log.warning("Failed to fetch trades for symbol", symbol=symbol, error=str(e))
            except Exception as e:
                log.error("Unexpected error fetching trades", symbol=symbol, error=str(e))

        # Sort and compute realized PnL via FIFO
        all_records.sort(key=lambda r: r.executed_at)
        self._compute_realized_pnl_fifo(all_records)
        return all_records

    # ── Realized PnL (FIFO) ──────────────────────────────────────────────────

    @staticmethod
    def _compute_realized_pnl_fifo(trades: list[TradeRecord]) -> None:
        """
        Mutates trade records in-place to set realized_pnl on sell trades.
        Uses FIFO cost basis matching.
        """
        from collections import deque
        cost_basis: dict[str, deque] = {}  # symbol → deque of (price, qty)

        for trade in trades:
            symbol = trade.symbol
            if symbol not in cost_basis:
                cost_basis[symbol] = deque()

            if trade.side == "buy":
                cost_basis[symbol].append((trade.price, trade.quantity))
            elif trade.side == "sell":
                pnl = 0.0
                remaining = trade.quantity

                while remaining > 0 and cost_basis.get(symbol):
                    buy_price, buy_qty = cost_basis[symbol].popleft()
                    matched = min(remaining, buy_qty)
                    pnl += matched * (trade.price - buy_price)
                    remaining -= matched
                    leftover = buy_qty - matched
                    if leftover > 0:
                        cost_basis[symbol].appendleft((buy_price, leftover))

                # Subtract fees (in quote asset equivalent)
                fee_in_quote = trade.fee if trade.fee_asset == trade.quote_asset else 0.0
                trade.realized_pnl = pnl - fee_in_quote

    # ── Current Holdings with Prices ─────────────────────────────────────────

    async def get_current_holdings_with_prices(self) -> dict[str, dict]:
        """
        Returns {symbol: {qty, avg_cost, current_price, value_usd, unrealized_pnl_usd}}
        """
        balances = await self.get_account_balances()
        result = {}

        for b in balances:
            asset = b["asset"]
            qty = b["total"]
            if qty <= 0:
                continue
            symbol_usdt = f"{asset}USDT"
            try:
                ticker = await self._get("/api/v3/ticker/price", {"symbol": symbol_usdt})
                current_price = float(ticker["price"])
                result[asset] = {
                    "qty": qty,
                    "current_price": current_price,
                    "value_usd": qty * current_price,
                }
            except Exception:
                if asset in ("USDT", "USDC", "BUSD", "DAI"):
                    result[asset] = {"qty": qty, "current_price": 1.0, "value_usd": qty}

        return result

    # ── Historical Price Data ─────────────────────────────────────────────────

    async def get_klines(
        self,
        symbol: str,
        interval: str = "1h",
        limit: int = 720,  # 30 days of hourly data
    ) -> list[tuple[datetime, float]]:
        """Returns list of (timestamp, close_price)."""
        data = await self._get(
            "/api/v3/klines",
            {"symbol": symbol, "interval": interval, "limit": limit},
        )
        return [
            (datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc), float(k[4]))
            for k in data
        ]

    async def get_btc_daily_returns(self, days: int = 365) -> list[float]:
        """Returns daily return series for BTC/USDT."""
        klines = await self.get_klines("BTCUSDT", interval="1d", limit=days + 1)
        prices = [p for _, p in klines]
        if len(prices) < 2:
            return []
        return [(prices[i] - prices[i - 1]) / prices[i - 1] for i in range(1, len(prices))]
