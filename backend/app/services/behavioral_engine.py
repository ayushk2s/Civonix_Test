"""
Civonix Behavioral Engine
Detects psychological trading mistakes from raw trade history.
Every detection is evidence-based: no guessing, no generic advice.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Sequence

import numpy as np

from app.services.analytics_engine import TradeRecord


@dataclass
class BehavioralFlag:
    flag_type: str            # 'revenge_trade' | 'fomo_buy' | 'panic_sell' | 'overtrading'
    trade_id: str
    symbol: str
    executed_at: datetime
    context: dict             # evidence for the flag
    estimated_loss_usd: float | None = None


@dataclass
class BehavioralResult:
    # Overtrading
    overtrading_score: float = 0.0           # 0–100
    avg_trades_per_day: float = 0.0
    overtrading_threshold: float = 0.0       # trades/day above which score rises

    # Revenge Trading
    revenge_trades: list[BehavioralFlag] = field(default_factory=list)
    revenge_trade_count: int = 0
    revenge_trade_loss_usd: float = 0.0

    # FOMO Buying
    fomo_trades: list[BehavioralFlag] = field(default_factory=list)
    fomo_trade_count: int = 0
    fomo_trade_loss_usd: float = 0.0

    # Panic Selling
    panic_sells: list[BehavioralFlag] = field(default_factory=list)
    panic_sell_count: int = 0
    panic_sell_loss_usd: float = 0.0

    # Time Analysis
    pnl_by_hour: dict[int, float] = field(default_factory=dict)   # hour (UTC) → avg pnl
    pnl_by_day: dict[int, float] = field(default_factory=dict)    # 0=Mon → avg pnl
    best_performing_hour: int | None = None
    worst_performing_hour: int | None = None
    best_performing_day: int | None = None
    worst_performing_day: int | None = None

    # Discipline Score
    discipline_score: float = 100.0


class BehavioralEngine:
    """
    Parameters
    ----------
    trades          : chronologically sorted list of trades
    price_history   : {symbol: [(timestamp, price), ...]} – 1-hour OHLC close prices
    """

    # Thresholds (configurable but sensible defaults)
    REVENGE_WINDOW_MINUTES = 60        # re-entry within 60 min of a loss
    REVENGE_LOSS_THRESHOLD_USD = 10    # loss must be at least $10 to qualify
    REVENGE_SIZE_MULTIPLIER = 1.3      # next trade is ≥30% larger
    FOMO_PRICE_SPIKE_PCT = 0.04        # 4% price increase triggers FOMO check
    FOMO_WINDOW_HOURS = 4              # look-back window for price spike
    PANIC_PRICE_DROP_PCT = 0.04        # 4% price drop triggers panic check
    PANIC_WINDOW_HOURS = 4
    PANIC_MIN_HOLD_HOURS = 12          # must have held ≥12h to distinguish from strategy
    OVERTRADING_BASE_THRESHOLD = 5     # trades/day above this = overtrading risk

    def __init__(
        self,
        trades: Sequence[TradeRecord],
        price_history: dict[str, list[tuple[datetime, float]]] | None = None,
    ):
        self.trades = sorted(trades, key=lambda t: t.executed_at)
        self.price_history = price_history or {}

    # ── Entry Point ──────────────────────────────────────────────────────────

    def analyze(self) -> BehavioralResult:
        result = BehavioralResult()

        self._overtrading(result)
        self._revenge_trading(result)
        self._fomo_trading(result)
        self._panic_selling(result)
        self._time_pattern_analysis(result)
        self._compute_discipline_score(result)

        return result

    # ── Overtrading ───────────────────────────────────────────────────────────

    def _overtrading(self, result: BehavioralResult) -> None:
        if not self.trades:
            return

        total_days = max(
            (self.trades[-1].executed_at - self.trades[0].executed_at).days, 1
        )
        avg_per_day = len(self.trades) / total_days
        result.avg_trades_per_day = avg_per_day
        result.overtrading_threshold = self.OVERTRADING_BASE_THRESHOLD

        # Score: 0–100, starts rising above threshold
        if avg_per_day <= self.OVERTRADING_BASE_THRESHOLD:
            result.overtrading_score = 0.0
        else:
            excess_ratio = (avg_per_day - self.OVERTRADING_BASE_THRESHOLD) / self.OVERTRADING_BASE_THRESHOLD
            result.overtrading_score = min(100.0, excess_ratio * 50)

    # ── Revenge Trading ───────────────────────────────────────────────────────

    def _revenge_trading(self, result: BehavioralResult) -> None:
        """
        Revenge trade: a buy that occurs within REVENGE_WINDOW_MINUTES after
        a losing sell on the same or related symbol, with a larger position size.
        """
        closed_sells = [t for t in self.trades if t.side == "sell" and t.realized_pnl is not None]

        for sell in closed_sells:
            if sell.realized_pnl >= -self.REVENGE_LOSS_THRESHOLD_USD:
                continue

            cutoff = sell.executed_at + timedelta(minutes=self.REVENGE_WINDOW_MINUTES)
            # Look for buys of the same base asset within the window
            subsequent_buys = [
                t for t in self.trades
                if t.side == "buy"
                and t.base_asset == sell.base_asset
                and sell.executed_at < t.executed_at <= cutoff
            ]

            for buy in subsequent_buys:
                # Check if position is larger than the losing trade
                if buy.quote_quantity >= sell.quote_quantity * self.REVENGE_SIZE_MULTIPLIER:
                    flag = BehavioralFlag(
                        flag_type="revenge_trade",
                        trade_id=buy.trade_id,
                        symbol=buy.symbol,
                        executed_at=buy.executed_at,
                        context={
                            "trigger_sell_id": sell.trade_id,
                            "trigger_loss_usd": sell.realized_pnl,
                            "minutes_after_loss": (buy.executed_at - sell.executed_at).seconds / 60,
                            "position_size_usd": float(buy.quote_quantity),
                            "previous_position_usd": float(sell.quote_quantity),
                            "size_increase_pct": (buy.quote_quantity / sell.quote_quantity - 1) * 100,
                        },
                        estimated_loss_usd=None,  # will be computed when trade closes
                    )
                    result.revenge_trades.append(flag)
                    break  # one flag per trigger sell

        result.revenge_trade_count = len(result.revenge_trades)
        result.revenge_trade_loss_usd = sum(
            abs(t.realized_pnl)
            for flag in result.revenge_trades
            for t in self.trades
            if t.trade_id == flag.trade_id
            and t.realized_pnl is not None
            and t.realized_pnl < 0
        )

    # ── FOMO Buying ───────────────────────────────────────────────────────────

    def _fomo_trading(self, result: BehavioralResult) -> None:
        """
        FOMO trade: a buy executed after the price has already spiked
        FOMO_PRICE_SPIKE_PCT or more in the past FOMO_WINDOW_HOURS.
        """
        buy_trades = [t for t in self.trades if t.side == "buy"]

        for trade in buy_trades:
            symbol = trade.symbol
            if symbol not in self.price_history:
                continue

            prices = self.price_history[symbol]
            window_start = trade.executed_at - timedelta(hours=self.FOMO_WINDOW_HOURS)

            # Get prices in the window before this trade
            window_prices = [
                p for ts, p in prices
                if window_start <= ts <= trade.executed_at
            ]
            if len(window_prices) < 2:
                continue

            low_in_window = min(window_prices)
            price_at_buy = float(trade.price)

            if low_in_window <= 0:
                continue

            spike_pct = (price_at_buy - low_in_window) / low_in_window
            if spike_pct >= self.FOMO_PRICE_SPIKE_PCT:
                flag = BehavioralFlag(
                    flag_type="fomo_buy",
                    trade_id=trade.trade_id,
                    symbol=symbol,
                    executed_at=trade.executed_at,
                    context={
                        "price_at_buy": price_at_buy,
                        "low_in_window": low_in_window,
                        "spike_pct": spike_pct * 100,
                        "window_hours": self.FOMO_WINDOW_HOURS,
                        "position_size_usd": float(trade.quote_quantity),
                    },
                )
                result.fomo_trades.append(flag)

        result.fomo_trade_count = len(result.fomo_trades)
        # Estimate FOMO loss: trades that were bought high and later closed at a loss
        fomo_ids = {f.trade_id for f in result.fomo_trades}
        result.fomo_trade_loss_usd = sum(
            abs(t.realized_pnl)
            for t in self.trades
            if t.trade_id in fomo_ids
            and t.realized_pnl is not None
            and t.realized_pnl < 0
        )

    # ── Panic Selling ─────────────────────────────────────────────────────────

    def _panic_selling(self, result: BehavioralResult) -> None:
        """
        Panic sell: a sell executed during a sharp price drop, after holding
        the position for at least PANIC_MIN_HOLD_HOURS.
        Only consider sells with a realized loss.
        """
        sell_trades = [
            t for t in self.trades
            if t.side == "sell"
            and t.realized_pnl is not None
            and t.realized_pnl < 0
        ]

        # Build FIFO buy map to know holding time
        from collections import deque
        buy_queues: dict[str, deque] = {}
        for t in self.trades:
            if t.side == "buy":
                if t.symbol not in buy_queues:
                    buy_queues[t.symbol] = deque()
                buy_queues[t.symbol].append((t.executed_at, t.quantity, t.price))

        for sell in sell_trades:
            if sell.symbol not in self.price_history:
                continue

            # Estimate holding time from FIFO queue
            symbol_buys = list(buy_queues.get(sell.symbol, []))
            if not symbol_buys:
                continue
            earliest_buy_time = symbol_buys[0][0]
            hold_hours = (sell.executed_at - earliest_buy_time).total_seconds() / 3600
            if hold_hours < self.PANIC_MIN_HOLD_HOURS:
                continue

            # Check if price dropped significantly before this sell
            prices = self.price_history[sell.symbol]
            window_start = sell.executed_at - timedelta(hours=self.PANIC_WINDOW_HOURS)
            window_prices = [
                p for ts, p in prices
                if window_start <= ts <= sell.executed_at
            ]
            if len(window_prices) < 2:
                continue

            high_in_window = max(window_prices)
            price_at_sell = float(sell.price)
            if high_in_window <= 0:
                continue

            drop_pct = (high_in_window - price_at_sell) / high_in_window
            if drop_pct >= self.PANIC_PRICE_DROP_PCT:
                flag = BehavioralFlag(
                    flag_type="panic_sell",
                    trade_id=sell.trade_id,
                    symbol=sell.symbol,
                    executed_at=sell.executed_at,
                    estimated_loss_usd=abs(float(sell.realized_pnl)),
                    context={
                        "price_at_sell": price_at_sell,
                        "high_in_window": high_in_window,
                        "drop_pct": drop_pct * 100,
                        "holding_hours": hold_hours,
                        "realized_loss_usd": float(sell.realized_pnl),
                    },
                )
                result.panic_sells.append(flag)

        result.panic_sell_count = len(result.panic_sells)
        result.panic_sell_loss_usd = sum(
            f.estimated_loss_usd or 0.0 for f in result.panic_sells
        )

    # ── Time Pattern Analysis ─────────────────────────────────────────────────

    def _time_pattern_analysis(self, result: BehavioralResult) -> None:
        closed = [t for t in self.trades if t.side == "sell" and t.realized_pnl is not None]
        if not closed:
            return

        hour_pnl: dict[int, list[float]] = {}
        day_pnl: dict[int, list[float]] = {}

        for t in closed:
            h = t.executed_at.hour
            d = t.executed_at.weekday()  # 0=Monday
            hour_pnl.setdefault(h, []).append(float(t.realized_pnl))
            day_pnl.setdefault(d, []).append(float(t.realized_pnl))

        result.pnl_by_hour = {h: float(np.mean(v)) for h, v in hour_pnl.items()}
        result.pnl_by_day  = {d: float(np.mean(v)) for d, v in day_pnl.items()}

        if result.pnl_by_hour:
            result.best_performing_hour  = max(result.pnl_by_hour, key=result.pnl_by_hour.get)
            result.worst_performing_hour = min(result.pnl_by_hour, key=result.pnl_by_hour.get)
        if result.pnl_by_day:
            result.best_performing_day  = max(result.pnl_by_day, key=result.pnl_by_day.get)
            result.worst_performing_day = min(result.pnl_by_day, key=result.pnl_by_day.get)

    # ── Discipline Score ──────────────────────────────────────────────────────

    def _compute_discipline_score(self, result: BehavioralResult) -> None:
        """
        Discipline score 0–100. Starts at 100, deducted for bad behaviors.
        """
        score = 100.0
        total_trades = len([t for t in self.trades if t.side == "sell"])

        if total_trades == 0:
            result.discipline_score = 100.0
            return

        # Deduct for revenge trading
        if total_trades > 0:
            revenge_rate = result.revenge_trade_count / total_trades
            score -= min(30, revenge_rate * 150)

        # Deduct for FOMO buying
        buy_trades = len([t for t in self.trades if t.side == "buy"])
        if buy_trades > 0:
            fomo_rate = result.fomo_trade_count / buy_trades
            score -= min(20, fomo_rate * 100)

        # Deduct for panic selling
        if total_trades > 0:
            panic_rate = result.panic_sell_count / total_trades
            score -= min(25, panic_rate * 125)

        # Deduct for overtrading
        score -= min(25, result.overtrading_score * 0.25)

        result.discipline_score = max(0.0, score)
