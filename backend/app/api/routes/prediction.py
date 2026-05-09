from datetime import date, datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.database import get_db
from app.models.user import User
from app.schemas.news import PredictionResponse, SubmitPredictionRequest

router = APIRouter()


@router.get("/today", response_model=PredictionResponse)
async def get_todays_prediction(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.models.portfolio import AiInsight  # avoid circular
    # Use a simple table query
    today = date.today()

    # Get or create today's game
    from sqlalchemy import text
    result = await db.execute(
        text("SELECT id, game_date, asset_symbol, up_votes, down_votes, resolved, actual_direction, open_price, close_price FROM daily_predictions WHERE game_date = :d"),
        {"d": today},
    )
    row = result.mappings().first()

    if not row:
        await db.execute(
            text("INSERT INTO daily_predictions (game_date, asset_symbol) VALUES (:d, 'BTC') ON CONFLICT DO NOTHING"),
            {"d": today},
        )
        await db.commit()
        result = await db.execute(
            text("SELECT * FROM daily_predictions WHERE game_date = :d"), {"d": today}
        )
        row = result.mappings().first()

    pred_id = str(row["id"])
    total = row["up_votes"] + row["down_votes"]
    up_pct = row["up_votes"] / total if total > 0 else 0.5
    down_pct = row["down_votes"] / total if total > 0 else 0.5

    # Check user's prediction
    user_pred = await db.execute(
        text("SELECT direction, is_correct FROM user_predictions WHERE user_id = :uid AND prediction_id = :pid"),
        {"uid": str(user.id), "pid": pred_id},
    )
    user_row = user_pred.mappings().first()

    return PredictionResponse(
        id=pred_id,
        game_date=str(row["game_date"]),
        asset_symbol=row["asset_symbol"],
        up_votes=row["up_votes"],
        down_votes=row["down_votes"],
        total_votes=total,
        up_pct=up_pct,
        down_pct=down_pct,
        resolved=row["resolved"],
        actual_direction=row["actual_direction"],
        user_prediction=user_row["direction"] if user_row else None,
        is_correct=user_row["is_correct"] if user_row else None,
    )


@router.post("/submit", response_model=PredictionResponse)
async def submit_prediction(
    body: SubmitPredictionRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if body.direction not in ("up", "down"):
        raise HTTPException(status_code=400, detail="Direction must be 'up' or 'down'")

    from sqlalchemy import text
    today = date.today()

    # Get today's prediction game
    result = await db.execute(
        text("SELECT id, resolved FROM daily_predictions WHERE game_date = :d"), {"d": today}
    )
    row = result.mappings().first()
    if not row:
        raise HTTPException(status_code=404, detail="No prediction game for today")
    if row["resolved"]:
        raise HTTPException(status_code=400, detail="Today's prediction is already resolved")

    pred_id = str(row["id"])

    # Check if user already predicted
    existing = await db.execute(
        text("SELECT id FROM user_predictions WHERE user_id = :uid AND prediction_id = :pid"),
        {"uid": str(user.id), "pid": pred_id},
    )
    if existing.mappings().first():
        raise HTTPException(status_code=409, detail="You already submitted a prediction today")

    await db.execute(
        text("INSERT INTO user_predictions (user_id, prediction_id, direction) VALUES (:uid, :pid, :dir)"),
        {"uid": str(user.id), "pid": pred_id, "dir": body.direction},
    )
    await db.commit()

    return await get_todays_prediction(user=user, db=db)


@router.get("/history")
async def prediction_history(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
    limit: int = 30,
):
    from sqlalchemy import text
    result = await db.execute(
        text("""
            SELECT up.direction, up.is_correct, dp.game_date, dp.asset_symbol,
                   dp.actual_direction, dp.up_votes, dp.down_votes
            FROM user_predictions up
            JOIN daily_predictions dp ON dp.id = up.prediction_id
            WHERE up.user_id = :uid
            ORDER BY dp.game_date DESC
            LIMIT :lim
        """),
        {"uid": str(user.id), "lim": limit},
    )
    return result.mappings().all()
