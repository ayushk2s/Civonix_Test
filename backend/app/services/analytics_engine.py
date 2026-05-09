"""
Civonix Analytics Engine
Computes 25+ professional portfolio metrics from raw trade data.
All calculations are deterministic and based on real computed data.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from typing import Sequence

import numpy as np

from app.config import settings


@dataclass
class TradeRecord:
    trade_id: str
    symbol: str
    base_asset: str
    quote_asset: str
    side: str           # 'buy' | 'sell'
    price: float
    quantity: float
    quote_quantity: float
    fee: float
    fee_asset: str
    executed_at: datetime
    realized_pnl: float | None = None


@dataclass
class SnapshotRecord:
    snapshot_date: date
    total_value_usd: float
    daily_return: float | None


@dataclass
class PortfolioMetricsResult:
    # Performance
    total_pnl_usd: float | None = None
    realized_pnl_usd: float | None = None
    unrealized_pnl_usd: float | None = None
    roi_daily: float | None = None
    roi_weekly: float | None = None
    roi_monthly: float | None = None
    roi_yearly: float | None = None
    roi_all_time: float | None = None
    cagr: float | None = None

    # Risk
    max_drawdown: float | None = None
    avg_drawdown: float | None = None
    volatility_daily: float | None = None
    volatility_annualized: float | None = None
    downside_deviation: float | None = None
    var_95: float | None = None
    var_99: float | None = None

    # Risk-Adjusted
    sharpe_ratio: float | None = None
    sortino_ratio: float | None = None
    calmar_ratio: float | None = None

    # Trade Quality
    total_trades: int | None = None
    winning_trades: int | None = None
    losing_trades: int | None = None
    win_rate: float | None = None
    loss_rate: float | None = None
    profit_factor: float | None = None
    expectancy_usd: float | None = None
    avg_win_usd: float | None = None
    avg_loss_usd: float | None = None
    avg_win_loss_ratio: float | None = None
    avg_holding_hours: float | None = None

    # Portfolio Structure
    diversification_score: float | None = None
    concentration_risk: float | None = None
    btc_exposure_pct: float | None = None
    eth_exposure_pct: float | None = None
    stablecoin_pct: float | None = None

    # Market Comparison
    beta_vs_btc: float | None = None
    alpha_vs_btc: float | None = None
    correlation_vs_btc: float | None = None
    fear_greed_score: int | None = None


STABLECOINS = {"USDT", "USDC", "BUSD", "DAI", "TUSD", "USDP", "FRAX", "LUSD"}
RISK_FREE_RATE_DAILY = settings.RISK_FREE_RATE / 365


class AnalyticsEngine:
    """
    Computes all portfolio metrics from trades + daily snapshots.

    Usage:
        engine = AnalyticsEngine(trades, snapshots, current_holdings, btc_returns)
        result = engine.compute()
    """

    def __init__(
        self,
        trades: Sequence[TradeRecord],
        snapshots: Sequence[SnapshotRecord],
        current_holdings: dict[str, dict],  # {symbol: {qty, value_usd, avg_cost}}
        btc_daily_returns: list[float] | None = None,
    ):
        self.trades = sorted(trades, key=lambda t: t.executed_at)
        self.snapshots = sorted(snapshots, key=lambda s: s.snapshot_date)
        self.current_holdings = current_holdings
        self.btc_daily_returns = btc_daily_returns or []

    # ── Entry Point ──────────────────────────────────────────────────────────

    def compute(self) -> PortfolioMetricsResult:
        result = PortfolioMetricsResult()
        daily_returns = self._daily_returns_array()

        # Performance
        result.total_pnl_usd = self._total_pnl()
        result.realized_pnl_usd = self._realized_pnl()
        result.unrealized_pnl_usd = self._unrealized_pnl()
        result.roi_daily = self._roi_for_window(1)
        result.roi_weekly = self._roi_for_window(7)
        result.roi_monthly = self._roi_for_window(30)
        result.roi_yearly = self._roi_for_window(365)
        result.roi_all_time = self._roi_all_time()
        result.cagr = self._cagr()

        # Risk (need at least 10 data points)
        if len(daily_returns) >= 10:
            result.max_drawdown = self._max_drawdown()
            result.avg_drawdown = self._avg_drawdown()
            result.volatility_daily = float(np.std(daily_returns, ddof=1))
            result.volatility_annualized = result.volatility_daily * math.sqrt(252)
            result.downside_deviation = self._downside_deviation(daily_returns)
            result.var_95 = self._value_at_risk(daily_returns, 0.95)
            result.var_99 = self._value_at_risk(daily_returns, 0.99)

            # Risk-Adjusted
            result.sharpe_ratio = self._sharpe_ratio(daily_returns, result.volatility_daily)
            result.sortino_ratio = self._sortino_ratio(daily_returns, result.downside_deviation)
            result.calmar_ratio = self._calmar_ratio(result.cagr, result.max_drawdown)

        # Trade Quality
        trade_stats = self._trade_quality_metrics()
        result.__dict__.update(trade_stats)

        # Portfolio Structure
        structure = self._portfolio_structure()
        result.__dict__.update(structure)

        # Market Comparison
        if len(daily_returns) >= 30 and len(self.btc_daily_returns) >= 30:
            market_stats = self._market_metrics(daily_returns)
            result.__dict__.update(market_stats)

        # Fear & Greed
        result.fear_greed_score = self._fear_greed_score(
            daily_returns, result.volatility_annualized
        )

        return result

    # ── Performance ──────────────────────────────────────────────────────────

    def _daily_returns_array(self) -> list[float]:
        returns = []
        for s in self.snapshots:
            if s.daily_return is not None:
                returns.append(float(s.daily_return))
        return returns

    def _total_pnl(self) -> float | None:
        rpnl = self._realized_pnl()
        upnl = self._unrealized_pnl()
        if rpnl is None and upnl is None:
            return None
        return (rpnl or 0.0) + (upnl or 0.0)

    def _realized_pnl(self) -> float | None:
        pnls = [t.realized_pnl for t in self.trades if t.realized_pnl is not None]
        return sum(pnls) if pnls else None

    def _unrealized_pnl(self) -> float | None:
        if not self.current_holdings:
            return None
        total = sum(
            h.get("value_usd", 0) - h.get("avg_cost", 0) * h.get("qty", 0)
            for h in self.current_holdings.values()
        )
        return total

    def _roi_for_window(self, days: int) -> float | None:
        if len(self.snapshots) < 2:
            return None
        cutoff = date.today() - timedelta(days=days)
        relevant = [s for s in self.snapshots if s.snapshot_date >= cutoff]
        if not relevant:
            return None
        start_val = relevant[0].total_value_usd
        end_val = relevant[-1].total_value_usd
        if start_val <= 0:
            return None
        return (end_val - start_val) / start_val

    def _roi_all_time(self) -> float | None:
        if len(self.snapshots) < 2:
            return None
        start_val = self.snapshots[0].total_value_usd
        end_val = self.snapshots[-1].total_value_usd
        if start_val <= 0:
            return None
        return (end_val - start_val) / start_val

    def _cagr(self) -> float | None:
        if len(self.snapshots) < 2:
            return None
        start = self.snapshots[0]
        end = self.snapshots[-1]
        if start.total_value_usd <= 0:
            return None
        days = (end.snapshot_date - start.snapshot_date).days
        if days < 30:
            return None
        years = days / 365.25
        ratio = end.total_value_usd / start.total_value_usd
        if ratio <= 0:
            return None
        return ratio ** (1.0 / years) - 1.0

    # ── Risk ─────────────────────────────────────────────────────────────────

    def _value_series(self) -> list[float]:
        return [s.total_value_usd for s in self.snapshots]

    def _max_drawdown(self) -> float | None:
        values = self._value_series()
        if len(values) < 2:
            return None
        peak = values[0]
        max_dd = 0.0
        for v in values:
            if v > peak:
                peak = v
            dd = (peak - v) / peak if peak > 0 else 0.0
            if dd > max_dd:
                max_dd = dd
        return max_dd if max_dd > 0 else None

    def _avg_drawdown(self) -> float | None:
        values = self._value_series()
        if len(values) < 2:
            return None
        peak = values[0]
        drawdowns = []
        in_drawdown = False
        current_dd = 0.0
        for v in values:
            if v > peak:
                if in_drawdown and current_dd > 0:
                    drawdowns.append(current_dd)
                peak = v
                in_drawdown = False
                current_dd = 0.0
            else:
                dd = (peak - v) / peak if peak > 0 else 0.0
                if dd > 0:
                    in_drawdown = True
                    current_dd = max(current_dd, dd)
        if in_drawdown and current_dd > 0:
            drawdowns.append(current_dd)
        return float(np.mean(drawdowns)) if drawdowns else None

    def _downside_deviation(self, daily_returns: list[float]) -> float | None:
        if not daily_returns:
            return None
        negative = [r - RISK_FREE_RATE_DAILY for r in daily_returns if r < RISK_FREE_RATE_DAILY]
        if not negative:
            return 0.0
        return float(np.sqrt(np.mean(np.square(negative))))

    def _value_at_risk(self, daily_returns: list[float], confidence: float) -> float | None:
        if len(daily_returns) < 20:
            return None
        arr = np.array(daily_returns)
        return float(np.percentile(arr, (1 - confidence) * 100))

    # ── Risk-Adjusted ─────────────────────────────────────────────────────────

    def _sharpe_ratio(self, daily_returns: list[float], vol: float | None) -> float | None:
        if not daily_returns or not vol or vol == 0:
            return None
        excess = np.mean(daily_returns) - RISK_FREE_RATE_DAILY
        return float(excess / vol * math.sqrt(252))

    def _sortino_ratio(self, daily_returns: list[float], downside_dev: float | None) -> float | None:
        if not daily_returns or downside_dev is None or downside_dev == 0:
            return None
        excess = np.mean(daily_returns) - RISK_FREE_RATE_DAILY
        return float(excess / downside_dev * math.sqrt(252))

    def _calmar_ratio(self, cagr: float | None, max_dd: float | None) -> float | None:
        if cagr is None or max_dd is None or max_dd == 0:
            return None
        return cagr / max_dd

    # ── Trade Quality ─────────────────────────────────────────────────────────

    def _trade_quality_metrics(self) -> dict:
        # Only sell trades (closed positions) have realized PnL
        closed = [t for t in self.trades if t.side == "sell" and t.realized_pnl is not None]
        if not closed:
            return {}

        wins = [t for t in closed if t.realized_pnl > 0]
        losses = [t for t in closed if t.realized_pnl < 0]
        total = len(closed)

        win_rate = len(wins) / total if total > 0 else 0.0
        loss_rate = len(losses) / total if total > 0 else 0.0

        gross_profit = sum(t.realized_pnl for t in wins)
        gross_loss = abs(sum(t.realized_pnl for t in losses))

        profit_factor = gross_profit / gross_loss if gross_loss > 0 else None
        avg_win = gross_profit / len(wins) if wins else None
        avg_loss = gross_loss / len(losses) if losses else None
        win_loss_ratio = avg_win / avg_loss if avg_win and avg_loss and avg_loss > 0 else None

        expectancy = (win_rate * (avg_win or 0)) - (loss_rate * (avg_loss or 0))

        # Average holding time (match buys to sells by symbol FIFO)
        avg_holding = self._avg_holding_hours()

        return {
            "total_trades": total,
            "winning_trades": len(wins),
            "losing_trades": len(losses),
            "win_rate": win_rate,
            "loss_rate": loss_rate,
            "profit_factor": profit_factor,
            "expectancy_usd": expectancy,
            "avg_win_usd": avg_win,
            "avg_loss_usd": avg_loss,
            "avg_win_loss_ratio": win_loss_ratio,
            "avg_holding_hours": avg_holding,
        }

    def _avg_holding_hours(self) -> float | None:
        """FIFO matching of buy→sell pairs to compute holding durations."""
        from collections import deque
        buy_queues: dict[str, deque] = {}
        holding_hours = []

        for trade in self.trades:
            symbol = trade.symbol
            if symbol not in buy_queues:
                buy_queues[symbol] = deque()

            if trade.side == "buy":
                buy_queues[symbol].append((trade.executed_at, trade.quantity))
            elif trade.side == "sell":
                remaining = trade.quantity
                while remaining > 0 and buy_queues.get(symbol):
                    buy_time, buy_qty = buy_queues[symbol].popleft()
                    matched = min(remaining, buy_qty)
                    hours = (trade.executed_at - buy_time).total_seconds() / 3600
                    holding_hours.append(hours)
                    remaining -= matched
                    leftover = buy_qty - matched
                    if leftover > 0:
                        buy_queues[symbol].appendleft((buy_time, leftover))

        return float(np.mean(holding_hours)) if holding_hours else None

    # ── Portfolio Structure ───────────────────────────────────────────────────

    def _portfolio_structure(self) -> dict:
        if not self.current_holdings:
            return {}

        total_usd = sum(h.get("value_usd", 0) for h in self.current_holdings.values())
        if total_usd <= 0:
            return {}

        allocations = {
            sym: h.get("value_usd", 0) / total_usd
            for sym, h in self.current_holdings.items()
        }

        # Herfindahl-Hirschman Index for concentration
        hhi = sum(w**2 for w in allocations.values())

        # Diversification score: normalized inverse of HHI
        n = len(allocations)
        min_hhi = 1.0 / n if n > 0 else 1.0
        diversification = (1 - hhi) / (1 - min_hhi) if n > 1 else 0.0

        btc_pct = allocations.get("BTC", 0.0) + allocations.get("WBTC", 0.0)
        eth_pct = allocations.get("ETH", 0.0) + allocations.get("WETH", 0.0)
        stable_pct = sum(
            alloc for sym, alloc in allocations.items() if sym in STABLECOINS
        )

        return {
            "diversification_score": max(0.0, min(1.0, diversification)),
            "concentration_risk": hhi,
            "btc_exposure_pct": btc_pct,
            "eth_exposure_pct": eth_pct,
            "stablecoin_pct": stable_pct,
        }

    # ── Market Metrics ────────────────────────────────────────────────────────

    def _market_metrics(self, portfolio_returns: list[float]) -> dict:
        if not self.btc_daily_returns:
            return {}

        # Align lengths
        n = min(len(portfolio_returns), len(self.btc_daily_returns))
        if n < 30:
            return {}

        p = np.array(portfolio_returns[-n:])
        m = np.array(self.btc_daily_returns[-n:])

        cov_matrix = np.cov(p, m)
        beta = cov_matrix[0, 1] / cov_matrix[1, 1] if cov_matrix[1, 1] != 0 else None

        # Alpha (Jensen's): Rp - [Rf + Beta * (Rm - Rf)]
        rp_annual = float(np.mean(p) * 252)
        rm_annual = float(np.mean(m) * 252)
        rf = settings.RISK_FREE_RATE
        alpha = rp_annual - (rf + (beta or 0) * (rm_annual - rf)) if beta else None

        # Correlation
        correlation = float(np.corrcoef(p, m)[0, 1])

        return {
            "beta_vs_btc": float(beta) if beta is not None else None,
            "alpha_vs_btc": alpha,
            "correlation_vs_btc": correlation,
        }

    # ── Fear & Greed ─────────────────────────────────────────────────────────

    def _fear_greed_score(
        self,
        daily_returns: list[float],
        vol_annualized: float | None,
    ) -> int | None:
        """
        Composite Fear & Greed Index (0=extreme fear, 100=extreme greed).

        Components:
        1. Volatility (25%) — low vol = greed
        2. Momentum (25%) — positive recent return = greed
        3. Portfolio trend (25%) — rising value = greed
        4. Win streak (25%) — more wins recently = greed
        """
        if not daily_returns or len(daily_returns) < 14:
            return None

        scores = []

        # 1. Volatility component: compare 30d vol to 90d vol
        if vol_annualized is not None:
            vol_30d = np.std(daily_returns[-30:], ddof=1) * math.sqrt(252) if len(daily_returns) >= 30 else vol_annualized
            vol_90d = np.std(daily_returns[-90:], ddof=1) * math.sqrt(252) if len(daily_returns) >= 90 else vol_annualized
            if vol_90d > 0:
                vol_ratio = vol_30d / vol_90d
                # Lower current vol vs historical = more greed
                vol_score = max(0, min(100, 100 * (1 - (vol_ratio - 0.5))))
                scores.append(vol_score)

        # 2. Momentum: 7-day return
        if len(daily_returns) >= 7:
            recent_7d = np.prod([1 + r for r in daily_returns[-7:]]) - 1
            momentum_score = 50 + recent_7d * 500  # map -10% to 10% → 0 to 100
            scores.append(max(0, min(100, momentum_score)))

        # 3. Portfolio trend: 30-day slope
        if len(daily_returns) >= 14:
            values = self._value_series()
            if len(values) >= 14:
                recent = values[-14:]
                x = np.arange(len(recent))
                slope = np.polyfit(x, recent, 1)[0]
                normalized_slope = slope / (recent[0] + 1e-9) * 100
                trend_score = 50 + normalized_slope * 50
                scores.append(max(0, min(100, trend_score)))

        # 4. Win rate component
        trade_stats = self._trade_quality_metrics()
        if "win_rate" in trade_stats and trade_stats["win_rate"] is not None:
            wr_score = trade_stats["win_rate"] * 100
            scores.append(wr_score)

        if not scores:
            return None
        return int(np.mean(scores))
