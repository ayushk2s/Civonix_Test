from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_current_user_optional
from app.database import get_db
from app.models.user import User
from app.schemas.leaderboard import LeaderboardResponse
from app.services.leaderboard_service import LeaderboardService

router = APIRouter()


@router.get("/{scope}", response_model=LeaderboardResponse)
async def get_leaderboard(
    scope: str = "global",
    scope_value: str = "global",
    limit: int = 100,
    user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    service = LeaderboardService(db)
    result = await service.get_leaderboard(
        scope=scope,
        scope_value=scope_value.lower(),
        limit=min(limit, 200),
        requesting_user_id=str(user.id) if user else None,
    )
    return result


@router.get("/compare/{user_id_a}/{user_id_b}")
async def compare_users(
    user_id_a: str,
    user_id_b: str,
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.portfolio import PortfolioMetrics

    results = {}
    for uid in [user_id_a, user_id_b]:
        r = await db.execute(
            select(PortfolioMetrics).where(PortfolioMetrics.user_id == uid)
        )
        m = r.scalar_one_or_none()
        if m:
            results[uid] = {
                "roi_monthly": float(m.roi_monthly or 0),
                "sharpe_ratio": float(m.sharpe_ratio or 0),
                "win_rate": float(m.win_rate or 0),
                "max_drawdown": float(m.max_drawdown or 0),
                "profit_factor": float(m.profit_factor or 0),
                "calmar_ratio": float(m.calmar_ratio or 0),
            }
        else:
            results[uid] = {}

    return {
        "user_a": results.get(user_id_a, {}),
        "user_b": results.get(user_id_b, {}),
        "comparison": {
            key: {
                "user_a": results.get(user_id_a, {}).get(key),
                "user_b": results.get(user_id_b, {}).get(key),
                "winner": (
                    "a" if (results.get(user_id_a, {}).get(key) or 0) > (results.get(user_id_b, {}).get(key) or 0)
                    else "b"
                ),
            }
            for key in ["roi_monthly", "sharpe_ratio", "win_rate"]
            if key in results.get(user_id_a, {}) or key in results.get(user_id_b, {})
        },
    }
