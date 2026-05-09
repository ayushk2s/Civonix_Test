"""
Civonix Leaderboard Service
Maintains real-time competitive rankings using Redis sorted sets.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import structlog
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.portfolio import LeaderboardEntry, PortfolioMetrics
from app.models.user import User
from app.redis_client import (
    cache_get,
    cache_set,
    leaderboard_add,
    leaderboard_rank,
    leaderboard_top,
)

log = structlog.get_logger()

BOARDS = ["global", "country", "state"]
BOARD_KEY = "leaderboard:{scope}:{value}"


class LeaderboardService:
    def __init__(self, db: AsyncSession):
        self.db = db

    # ── Update user's leaderboard scores ─────────────────────────────────────

    async def update_user_ranking(self, user: User, metrics: PortfolioMetrics) -> None:
        """Called after metrics recalculation. Updates Redis + DB."""
        if not user.is_public or metrics.roi_monthly is None:
            return

        # Composite score: blend ROI, Sharpe, win_rate (all normalized)
        score = self._compute_composite_score(metrics)

        # Update Redis sorted sets
        member = str(user.id)
        await leaderboard_add(BOARD_KEY.format(scope="global", value="global"), member, score)

        if user.country:
            await leaderboard_add(
                BOARD_KEY.format(scope="country", value=user.country.lower()),
                member,
                score,
            )
        if user.state_region:
            await leaderboard_add(
                BOARD_KEY.format(scope="state", value=user.state_region.lower()),
                member,
                score,
            )

        # Persist to DB (upsert)
        await self._upsert_entry(user, metrics, score)
        log.info("Leaderboard updated", user_id=str(user.id), score=score)

    @staticmethod
    def _compute_composite_score(metrics: PortfolioMetrics) -> float:
        """
        Composite score for ranking (higher = better):
        40% ROI (monthly), 30% Sharpe ratio, 20% win rate, 10% consistency bonus
        """
        roi = float(metrics.roi_monthly or 0) * 100        # convert to percentage
        sharpe = float(metrics.sharpe_ratio or 0)
        win_rate = float(metrics.win_rate or 0) * 100

        # Normalize: Sharpe (-5 to 5 → 0 to 100)
        sharpe_norm = max(0, min(100, (sharpe + 5) * 10))

        score = (roi * 0.40) + (sharpe_norm * 0.30) + (win_rate * 0.20)
        return round(score, 4)

    async def _upsert_entry(
        self,
        user: User,
        metrics: PortfolioMetrics,
        score: float,
    ) -> None:
        """Upsert the leaderboard_entries row for the user (global scope)."""
        result = await self.db.execute(
            select(LeaderboardEntry).where(
                LeaderboardEntry.user_id == user.id,
                LeaderboardEntry.scope == "global",
                LeaderboardEntry.scope_value == "global",
            )
        )
        entry = result.scalar_one_or_none()

        global_rank = await leaderboard_rank(
            BOARD_KEY.format(scope="global", value="global"),
            str(user.id),
        )

        data = {
            "roi_30d": metrics.roi_monthly,
            "sharpe_ratio": metrics.sharpe_ratio,
            "win_rate": metrics.win_rate,
            "total_pnl_usd": metrics.total_pnl_usd,
            "consistency_score": score,
            "rank": global_rank,
            "updated_at": datetime.now(timezone.utc),
        }

        if entry:
            for k, v in data.items():
                setattr(entry, k, v)
        else:
            new_entry = LeaderboardEntry(
                user_id=user.id,
                scope="global",
                scope_value="global",
                **data,
            )
            self.db.add(new_entry)

        await self.db.commit()

    # ── Read leaderboard ──────────────────────────────────────────────────────

    async def get_leaderboard(
        self,
        scope: str = "global",
        scope_value: str = "global",
        limit: int = 100,
        requesting_user_id: str | None = None,
    ) -> dict:
        cache_key = f"lb:{scope}:{scope_value}:{limit}"
        cached = await cache_get(cache_key)
        if cached:
            if requesting_user_id:
                cached["your_rank"] = await leaderboard_rank(
                    BOARD_KEY.format(scope=scope, value=scope_value),
                    requesting_user_id,
                )
            return cached

        # Fetch from DB with user join
        result = await self.db.execute(
            select(LeaderboardEntry, User)
            .join(User, User.id == LeaderboardEntry.user_id)
            .where(
                LeaderboardEntry.scope == scope,
                LeaderboardEntry.scope_value == scope_value,
                User.is_public == True,
            )
            .order_by(LeaderboardEntry.consistency_score.desc())
            .limit(limit)
        )
        rows = result.all()

        entries = []
        for i, (entry, user) in enumerate(rows, start=1):
            entries.append({
                "rank": i,
                "user_id": str(user.id),
                "username": user.username,
                "display_name": user.display_name,
                "avatar_url": user.avatar_url,
                "country": user.country,
                "roi_30d": float(entry.roi_30d) if entry.roi_30d else None,
                "sharpe_ratio": float(entry.sharpe_ratio) if entry.sharpe_ratio else None,
                "win_rate": float(entry.win_rate) if entry.win_rate else None,
                "total_pnl_usd": float(entry.total_pnl_usd) if entry.total_pnl_usd else None,
                "winning_streak": entry.winning_streak,
                "consistency_score": float(entry.consistency_score) if entry.consistency_score else None,
            })

        total_query = await self.db.execute(
            select(LeaderboardEntry).where(
                LeaderboardEntry.scope == scope,
                LeaderboardEntry.scope_value == scope_value,
            )
        )
        total = len(total_query.scalars().all())

        response = {
            "scope": scope,
            "scope_value": scope_value,
            "total_participants": total,
            "entries": entries,
            "your_rank": None,
        }

        await cache_set(cache_key, response, ttl=60)

        if requesting_user_id:
            response["your_rank"] = await leaderboard_rank(
                BOARD_KEY.format(scope=scope, value=scope_value),
                requesting_user_id,
            )

        return response

    async def get_streak(self, user_id: uuid.UUID) -> dict:
        """Returns current winning/losing streak based on daily PnL."""
        result = await self.db.execute(
            select(LeaderboardEntry).where(
                LeaderboardEntry.user_id == user_id,
                LeaderboardEntry.scope == "global",
            )
        )
        entry = result.scalar_one_or_none()
        if not entry:
            return {"winning_streak": 0, "losing_streak": 0}
        return {
            "winning_streak": entry.winning_streak,
            "losing_streak": entry.losing_streak,
        }
