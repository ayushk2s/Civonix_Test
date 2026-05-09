from decimal import Decimal

from pydantic import BaseModel


class LeaderboardUserEntry(BaseModel):
    rank: int
    user_id: str
    username: str
    display_name: str | None
    avatar_url: str | None
    country: str | None
    roi_30d: Decimal | None
    sharpe_ratio: Decimal | None
    win_rate: Decimal | None
    total_pnl_usd: Decimal | None
    winning_streak: int
    consistency_score: Decimal | None

    model_config = {"from_attributes": True}


class LeaderboardResponse(BaseModel):
    scope: str
    scope_value: str
    total_participants: int
    your_rank: int | None
    entries: list[LeaderboardUserEntry]


class CompareUsersRequest(BaseModel):
    user_id_a: str
    user_id_b: str


class CompareUsersResponse(BaseModel):
    user_a: dict
    user_b: dict
    metrics_comparison: dict
