"""
Unified exchange service using official SDKs.
Binance: python-binance (Spot client)
Bybit:   pybit (unified_trading HTTP)
KuCoin:  kucoin-universal-sdk (DefaultClient REST)
All exchange calls are wrapped with asyncio.to_thread so they don't block
the async event loop.
"""
from __future__ import annotations

import asyncio
from collections import deque
from datetime import datetime, timezone
from typing import Any

import structlog

from app.core.exceptions import ExchangeError
from app.core.security import decrypt_api_key
from app.services.analytics_engine import TradeRecord

log = structlog.get_logger()

SUPPORTED_EXCHANGES = {"binance", "bybit", "kucoin"}


# ── Binance ───────────────────────────────────────────────────────────────────

class _BinanceClient:
    def __init__(self, api_key: str, api_secret: str):
        from binance.spot import Spot
        self._c = Spot(api_key=api_key, api_secret=api_secret)
        self._pub = Spot()  # public endpoints (no auth)

    async def validate(self) -> bool:
        try:
            await asyncio.to_thread(self._c.account)
            return True
        except Exception as e:
            msg = str(e).lower()
            if "invalid api" in msg or "api-key" in msg or "unauthorized" in msg or "-2014" in msg or "-2015" in msg:
                return False
            # Other errors (rate limit, etc.) — key is likely valid
            log.info("Binance validation non-auth error, accepting key", error=str(e))
            return True

    async def balances(self) -> list[dict]:
        data = await asyncio.to_thread(self._c.account)
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

    async def ticker_price(self, symbol: str) -> float:
        data = await asyncio.to_thread(self._c.ticker_price, symbol)
        return float(data["price"])

    async def my_trades(self, symbol: str, start_time_ms: int | None = None) -> list[dict]:
        params: dict[str, Any] = {"symbol": symbol, "limit": 1000}
        if start_time_ms:
            params["startTime"] = start_time_ms
        all_trades: list[dict] = []
        while True:
            batch = await asyncio.to_thread(self._c.my_trades, **params)
            if not batch:
                break
            all_trades.extend(batch)
            if len(batch) < 1000:
                break
            params["startTime"] = batch[-1]["time"] + 1
            await asyncio.sleep(0.05)
        return all_trades

    async def btc_daily_returns(self, days: int = 365) -> list[float]:
        klines = await asyncio.to_thread(
            self._pub.klines, "BTCUSDT", "1d", limit=days + 1
        )
        prices = [float(k[4]) for k in klines]
        if len(prices) < 2:
            return []
        return [(prices[i] - prices[i - 1]) / prices[i - 1] for i in range(1, len(prices))]

    def to_trade_records(self, raw: list[dict], symbol: str) -> list[TradeRecord]:
        records = []
        quote = "USDT"
        for q in ("USDT", "USDC", "BUSD", "BTC", "ETH", "BNB"):
            if symbol.endswith(q):
                quote = q
                break
        base = symbol[: len(symbol) - len(quote)]
        for t in raw:
            records.append(TradeRecord(
                trade_id=str(t["id"]),
                symbol=symbol,
                base_asset=base,
                quote_asset=quote,
                side="buy" if t["isBuyer"] else "sell",
                price=float(t["price"]),
                quantity=float(t["qty"]),
                quote_quantity=float(t["quoteQty"]),
                fee=float(t["commission"]),
                fee_asset=t["commissionAsset"],
                executed_at=datetime.fromtimestamp(t["time"] / 1000, tz=timezone.utc),
            ))
        return records


# ── Bybit ─────────────────────────────────────────────────────────────────────

class _BybitClient:
    def __init__(self, api_key: str, api_secret: str):
        from pybit.unified_trading import HTTP
        self._s = HTTP(testnet=False, api_key=api_key, api_secret=api_secret)

    async def validate(self) -> bool:
        try:
            await asyncio.to_thread(self._s.get_wallet_balance, accountType="UNIFIED")
            return True
        except Exception as e:
            msg = str(e).lower()
            if "invalid api" in msg or "api key" in msg or "10004" in msg or "33004" in msg:
                return False
            try:
                await asyncio.to_thread(self._s.get_wallet_balance, accountType="SPOT")
                return True
            except Exception as e2:
                msg2 = str(e2).lower()
                if "invalid api" in msg2 or "api key" in msg2:
                    return False
                log.info("Bybit validation non-auth error, accepting key", error=str(e2))
                return True

    async def balances(self) -> list[dict]:
        aggregated: dict[str, dict] = {}

        def _add(asset: str, free: float, locked: float) -> None:
            if asset not in aggregated:
                aggregated[asset] = {"asset": asset, "free": 0.0, "locked": 0.0, "total": 0.0}
            aggregated[asset]["free"] += free
            aggregated[asset]["locked"] += locked
            aggregated[asset]["total"] += free + locked

        # Trading accounts: UNIFIED first, fall back to SPOT
        for account_type in ("UNIFIED", "SPOT"):
            try:
                data = await asyncio.to_thread(
                    self._s.get_wallet_balance, accountType=account_type
                )
                coin_list = data["result"]["list"][0].get("coin", []) if data["result"]["list"] else []
                for c in coin_list:
                    total = float(c.get("walletBalance") or 0)
                    if total > 0:
                        free = float(c.get("availableToWithdraw") or c.get("free") or total)
                        locked = max(0.0, total - free)
                        _add(c["coin"], free, locked)
                break
            except Exception:
                continue

        # Funding account (holds idle/transferred funds)
        try:
            data = await asyncio.to_thread(
                self._s.get_coins_balance, accountType="FUND"
            )
            for c in data["result"].get("balance", []):
                total = float(c.get("walletBalance") or 0)
                if total > 0:
                    _add(c["coin"], total, 0.0)
        except Exception as e:
            log.warning("Bybit FUND balance fetch failed", error=str(e))

        return [v for v in aggregated.values() if v["total"] > 0]

    async def ticker_price(self, symbol: str) -> float:
        data = await asyncio.to_thread(
            self._s.get_tickers, category="spot", symbol=symbol
        )
        return float(data["result"]["list"][0]["lastPrice"])

    async def my_trades(self, symbol: str, start_time_ms: int | None = None) -> list[dict]:
        """Fetch trades for a specific symbol (spot only — used as fallback)."""
        params: dict[str, Any] = {"category": "spot", "symbol": symbol, "limit": 100}
        all_trades: list[dict] = []
        cursor = None
        while True:
            if cursor:
                params["cursor"] = cursor
            if start_time_ms:
                params["startTime"] = start_time_ms
            data = await asyncio.to_thread(self._s.get_executions, **params)
            result = data.get("result", {})
            batch = result.get("list", [])
            all_trades.extend(batch)
            cursor = result.get("nextPageCursor")
            if not cursor or len(batch) < 100:
                break
            await asyncio.sleep(0.05)
        return all_trades

    async def all_trades(self, start_time_ms: int | None = None) -> list[TradeRecord]:
        """Fetch ALL trades across spot + linear futures without needing a symbol list."""
        records: list[TradeRecord] = []
        for category in ("spot", "linear"):
            cursor = None
            while True:
                params: dict[str, Any] = {"category": category, "limit": 100}
                if start_time_ms:
                    params["startTime"] = start_time_ms
                if cursor:
                    params["cursor"] = cursor
                try:
                    data = await asyncio.to_thread(self._s.get_executions, **params)
                    result = data.get("result", {})
                    batch = result.get("list", [])
                    for t in batch:
                        symbol = t.get("symbol", "")
                        if not symbol:
                            continue
                        quote = "USDT"
                        for q in ("USDT", "USDC", "BTC", "ETH", "BNB"):
                            if symbol.endswith(q):
                                quote = q
                                break
                        base = symbol[: len(symbol) - len(quote)]
                        records.append(TradeRecord(
                            trade_id=t["execId"],
                            symbol=symbol,
                            base_asset=base,
                            quote_asset=quote,
                            side="buy" if t["side"].lower() == "buy" else "sell",
                            price=float(t["execPrice"]),
                            quantity=float(t["execQty"]),
                            quote_quantity=float(t.get("execValue") or float(t["execPrice"]) * float(t["execQty"])),
                            fee=float(t.get("execFee") or 0),
                            fee_asset=t.get("feeCurrency") or quote,
                            executed_at=datetime.fromtimestamp(int(t["execTime"]) / 1000, tz=timezone.utc),
                        ))
                    cursor = result.get("nextPageCursor")
                    if not cursor or len(batch) < 100:
                        break
                    await asyncio.sleep(0.05)
                except Exception as e:
                    log.warning("Bybit trade fetch failed", category=category, error=str(e))
                    break
        return records

    async def btc_daily_returns(self, days: int = 365) -> list[float]:
        data = await asyncio.to_thread(
            self._s.get_kline,
            category="spot",
            symbol="BTCUSDT",
            interval="D",
            limit=days + 1,
        )
        prices = [float(k[4]) for k in data["result"]["list"]]
        prices.reverse()
        if len(prices) < 2:
            return []
        return [(prices[i] - prices[i - 1]) / prices[i - 1] for i in range(1, len(prices))]

    def to_trade_records(self, raw: list[dict], symbol: str) -> list[TradeRecord]:
        records = []
        quote = "USDT"
        for q in ("USDT", "USDC", "BTC", "ETH", "BNB"):
            if symbol.endswith(q):
                quote = q
                break
        base = symbol[: len(symbol) - len(quote)]
        for t in raw:
            records.append(TradeRecord(
                trade_id=t["execId"],
                symbol=symbol,
                base_asset=base,
                quote_asset=quote,
                side="buy" if t["side"].lower() == "buy" else "sell",
                price=float(t["execPrice"]),
                quantity=float(t["execQty"]),
                quote_quantity=float(t.get("execValue") or float(t["execPrice"]) * float(t["execQty"])),
                fee=float(t.get("execFee") or 0),
                fee_asset=t.get("feeCurrency") or quote,
                executed_at=datetime.fromtimestamp(int(t["execTime"]) / 1000, tz=timezone.utc),
            ))
        return records


# ── KuCoin ────────────────────────────────────────────────────────────────────

class _KucoinClient:
    def __init__(self, api_key: str, api_secret: str, passphrase: str):
        from kucoin_universal_sdk.api import DefaultClient
        from kucoin_universal_sdk.model import (
            ClientOptionBuilder,
            TransportOptionBuilder,
            GLOBAL_API_ENDPOINT,
            GLOBAL_FUTURES_API_ENDPOINT,
            GLOBAL_BROKER_API_ENDPOINT,
        )

        transport = (
            TransportOptionBuilder()
            .set_keep_alive(True)
            .set_max_pool_size(10)
            .set_max_connection_per_pool(10)
            .build()
        )
        option = (
            ClientOptionBuilder()
            .set_key(api_key)
            .set_secret(api_secret)
            .set_passphrase(passphrase)
            .set_spot_endpoint(GLOBAL_API_ENDPOINT)
            .set_futures_endpoint(GLOBAL_FUTURES_API_ENDPOINT)
            .set_broker_endpoint(GLOBAL_BROKER_API_ENDPOINT)
            .set_transport_option(transport)
            .build()
        )
        client = DefaultClient(option)
        rest = client.rest_service()
        self._account_svc = rest.get_account_service().get_account_api()
        spot_svc = rest.get_spot_service()
        self._order_api = spot_svc.get_order_api()
        self._market_api = spot_svc.get_market_api()

    @staticmethod
    def _to_symbol(asset: str) -> str:
        return f"{asset}-USDT"

    async def validate(self) -> bool:
        try:
            from kucoin_universal_sdk.generate.account.account.model_get_apikey_info_resp import GetApikeyInfoResp
            await asyncio.to_thread(self._account_svc.get_apikey_info)
            return True
        except Exception as e:
            msg = str(e).lower()
            if any(k in msg for k in ("api key", "invalid key", "400003", "400004", "401")):
                return False
            log.info("KuCoin validation non-auth error, accepting key", error=str(e))
            return True

    async def balances(self) -> list[dict]:
        from kucoin_universal_sdk.generate.account.account.model_get_spot_account_list_req import GetSpotAccountListReq
        coins: dict[str, dict] = {}
        # Fetch all account types (main + trade) so we don't miss funds
        for acct_type in ("main", "trade"):
            try:
                req = GetSpotAccountListReq(type=acct_type)
                resp = await asyncio.to_thread(self._account_svc.get_spot_account_list, req)
                for item in (resp.data or []):
                    asset = item.currency
                    bal = float(item.available or 0) + float(item.holds or 0)
                    if bal <= 0:
                        continue
                    if asset not in coins:
                        coins[asset] = {"asset": asset, "free": 0.0, "locked": 0.0, "total": 0.0}
                    coins[asset]["free"] += float(item.available or 0)
                    coins[asset]["locked"] += float(item.holds or 0)
                    coins[asset]["total"] += bal
            except Exception as e:
                log.warning("KuCoin balance fetch skipped", account_type=acct_type, error=str(e))
        log.info("KuCoin balances fetched", assets=list(coins.keys()))
        return list(coins.values())

    async def ticker_price(self, symbol: str) -> float:
        from kucoin_universal_sdk.generate.spot.market.model_get_ticker_req import GetTickerReq
        # symbol arrives as "BTCUSDT" — convert to "BTC-USDT"
        kc_sym = symbol if "-" in symbol else symbol[:-4] + "-USDT"
        req = GetTickerReq(symbol=kc_sym)
        resp = await asyncio.to_thread(self._market_api.get_ticker, req)
        return float(resp.price)

    async def my_trades(self, symbol: str, start_time_ms: int | None = None) -> list[dict]:
        from kucoin_universal_sdk.generate.spot.order.model_get_trade_history_req import GetTradeHistoryReq
        kc_sym = symbol if "-" in symbol else symbol[:-4] + "-USDT"
        all_trades: list[dict] = []
        last_id: int | None = None
        while True:
            req = GetTradeHistoryReq(
                symbol=kc_sym,
                limit=200,  # KuCoin max is 200
                start_at=start_time_ms,
                last_id=last_id,
            )
            resp = await asyncio.to_thread(self._order_api.get_trade_history, req)
            items = resp.items or []
            for t in items:
                all_trades.append({
                    "id": t.id,
                    "trade_id": t.trade_id,
                    "symbol": kc_sym,
                    "side": t.side,
                    "price": t.price,
                    "size": t.size,
                    "funds": t.funds,
                    "fee": t.fee,
                    "fee_currency": t.fee_currency,
                    "created_at": t.created_at,
                })
            if not items or len(items) < 500:
                break
            last_id = resp.last_id
            await asyncio.sleep(0.1)
        return all_trades

    async def btc_daily_returns(self, days: int = 365) -> list[float]:
        import time
        from kucoin_universal_sdk.generate.spot.market.model_get_klines_req import GetKlinesReq
        end_at = int(time.time())
        start_at = end_at - days * 86400
        req = GetKlinesReq(symbol="BTC-USDT", type="1day", start_at=start_at, end_at=end_at)
        resp = await asyncio.to_thread(self._market_api.get_klines, req)
        # KuCoin kline: [timestamp, open, close, high, low, volume, turnover]
        rows = sorted(resp.data or [], key=lambda r: int(r[0]))
        closes = [float(r[2]) for r in rows]
        if len(closes) < 2:
            return []
        return [(closes[i] - closes[i - 1]) / closes[i - 1] for i in range(1, len(closes))]

    def to_trade_records(self, raw: list[dict], symbol: str) -> list[TradeRecord]:
        records = []
        # KuCoin symbol format: "BTC-USDT"
        parts = symbol.split("-")
        base = parts[0] if len(parts) == 2 else symbol[:-4]
        quote = parts[1] if len(parts) == 2 else "USDT"
        for t in raw:
            records.append(TradeRecord(
                trade_id=str(t["id"]),
                symbol=symbol,
                base_asset=base,
                quote_asset=quote,
                side="buy" if t["side"].lower() == "buy" else "sell",
                price=float(t["price"]),
                quantity=float(t["size"]),
                quote_quantity=float(t.get("funds") or float(t["price"]) * float(t["size"])),
                fee=float(t.get("fee") or 0),
                fee_asset=t.get("fee_currency") or quote,
                executed_at=datetime.fromtimestamp(int(t["created_at"]) / 1000, tz=timezone.utc),
            ))
        return records


# ── Unified facade ────────────────────────────────────────────────────────────

class ExchangeService:
    def __init__(self, exchange: str, api_key: str, api_secret: str, passphrase: str | None = None):
        if exchange not in SUPPORTED_EXCHANGES:
            raise ExchangeError(f"Unsupported exchange: {exchange}. Supported: {', '.join(SUPPORTED_EXCHANGES)}")
        self.exchange_name = exchange
        if exchange == "binance":
            self._client: _BinanceClient | _BybitClient | _KucoinClient = _BinanceClient(api_key, api_secret)
        elif exchange == "bybit":
            self._client = _BybitClient(api_key, api_secret)
        else:
            if not passphrase:
                raise ExchangeError("KuCoin requires an API passphrase")
            self._client = _KucoinClient(api_key, api_secret, passphrase)

    @classmethod
    def from_account(cls, account: Any) -> "ExchangeService":
        passphrase = None
        if account.passphrase_encrypted:
            passphrase = decrypt_api_key(account.passphrase_encrypted)
        return cls(
            exchange=account.exchange,
            api_key=decrypt_api_key(account.api_key_encrypted),
            api_secret=decrypt_api_key(account.api_secret_encrypted),
            passphrase=passphrase,
        )

    # ── Validation ────────────────────────────────────────────────────────────

    async def validate_api_keys(self) -> bool:
        return await self._client.validate()

    # ── Balances ──────────────────────────────────────────────────────────────

    async def get_account_balances(self) -> list[dict]:
        try:
            return await self._client.balances()
        except Exception as e:
            raise ExchangeError(f"Failed to fetch balances from {self.exchange_name}: {e}")

    # ── Live holdings with prices ─────────────────────────────────────────────

    async def get_current_holdings_with_prices(self) -> dict[str, dict]:
        balances = await self.get_account_balances()
        result: dict[str, dict] = {}
        for b in balances:
            asset, qty = b["asset"], b["total"]
            if qty <= 0:
                continue
            if asset in ("USDT", "USDC", "BUSD", "DAI", "FDUSD", "TUSD"):
                result[asset] = {"qty": qty, "current_price": 1.0, "value_usd": qty}
                continue
            try:
                price = await self._client.ticker_price(f"{asset}USDT")
                if price > 0:
                    result[asset] = {"qty": qty, "current_price": price, "value_usd": qty * price}
            except Exception:
                pass
        return result

    # ── Trade fetch + FIFO P&L ────────────────────────────────────────────────

    async def fetch_all_user_trades(
        self,
        symbols: list[str],
        last_sync_ms: int | None = None,
    ) -> list[TradeRecord]:
        # Bybit: fetch all categories (spot + linear futures) in one pass — no symbol list needed
        if isinstance(self._client, _BybitClient):
            all_records = await self._client.all_trades(start_time_ms=last_sync_ms)
            all_records.sort(key=lambda r: r.executed_at)
            _compute_pnl_fifo(all_records)
            return all_records

        all_records: list[TradeRecord] = []
        for symbol in symbols:
            try:
                raw = await self._client.my_trades(symbol, start_time_ms=last_sync_ms)
                all_records.extend(self._client.to_trade_records(raw, symbol))
            except ExchangeError:
                raise
            except Exception as e:
                log.warning("Failed to fetch trades", symbol=symbol, exchange=self.exchange_name, error=str(e))
            await asyncio.sleep(0.05)

        all_records.sort(key=lambda r: r.executed_at)
        _compute_pnl_fifo(all_records)
        return all_records

    # ── BTC benchmark ─────────────────────────────────────────────────────────

    async def get_btc_daily_returns(self, days: int = 365) -> list[float]:
        try:
            return await self._client.btc_daily_returns(days)
        except Exception:
            return []


def _compute_pnl_fifo(trades: list[TradeRecord]) -> None:
    cost_basis: dict[str, deque] = {}
    for trade in trades:
        sym = trade.symbol
        if sym not in cost_basis:
            cost_basis[sym] = deque()
        if trade.side == "buy":
            cost_basis[sym].append((trade.price, trade.quantity))
        elif trade.side == "sell":
            pnl, remaining = 0.0, trade.quantity
            while remaining > 0 and cost_basis.get(sym):
                bp, bq = cost_basis[sym].popleft()
                matched = min(remaining, bq)
                pnl += matched * (trade.price - bp)
                remaining -= matched
                if bq - matched > 0:
                    cost_basis[sym].appendleft((bp, bq - matched))
            fee_quote = trade.fee if trade.fee_asset == trade.quote_asset else 0.0
            trade.realized_pnl = pnl - fee_quote
