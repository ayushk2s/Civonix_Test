from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel


class NewsArticleResponse(BaseModel):
    id: str
    title: str
    summary: str | None
    url: str
    source: str
    image_url: str | None
    sentiment: Decimal | None
    sentiment_label: str | None
    affected_symbols: list[str]
    portfolio_impact: str | None   # computed per user
    published_at: datetime

    model_config = {"from_attributes": True}


class NewsFeedResponse(BaseModel):
    articles: list[NewsArticleResponse]
    total: int
    page: int
    page_size: int


class PredictionResponse(BaseModel):
    id: str
    game_date: str
    asset_symbol: str
    up_votes: int
    down_votes: int
    total_votes: int
    up_pct: float
    down_pct: float
    resolved: bool
    actual_direction: str | None
    user_prediction: str | None
    is_correct: bool | None


class SubmitPredictionRequest(BaseModel):
    direction: str  # 'up' or 'down'
