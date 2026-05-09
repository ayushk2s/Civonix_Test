from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user_optional
from app.database import get_db
from app.models.portfolio import PortfolioSnapshot
from app.models.user import User
from app.redis_client import cache_get, cache_set
from app.schemas.news import NewsFeedResponse, NewsArticleResponse
from app.services.news_service import NewsService

router = APIRouter()


@router.get("/feed", response_model=NewsFeedResponse)
async def news_feed(
    page: int = 1,
    page_size: int = 20,
    sentiment: str | None = None,
    user: User | None = Depends(get_current_user_optional),
    db: AsyncSession = Depends(get_db),
):
    from app.models.portfolio import PortfolioSnapshot
    from sqlalchemy import select, desc

    cache_key = f"news:feed:{page}:{page_size}:{sentiment}"
    cached = await cache_get(cache_key)

    if not cached:
        service = NewsService()
        articles_raw = await service.fetch_all_news()
        enriched = await service.enrich_with_sentiment(articles_raw)
        await service.close()
        await cache_set(cache_key, enriched, ttl=900)  # 15 min cache
        cached = enriched

    # Get user holdings for personalization
    user_symbols = []
    if user:
        snap_result = await db.execute(
            select(PortfolioSnapshot)
            .where(PortfolioSnapshot.user_id == user.id)
            .order_by(PortfolioSnapshot.snapshot_date.desc())
            .limit(1)
        )
        snap = snap_result.scalar_one_or_none()
        if snap and snap.holdings:
            user_symbols = list(snap.holdings.keys())

    service = NewsService()
    articles = service.filter_by_holdings(cached, user_symbols)

    # Filter by sentiment
    if sentiment:
        articles = [a for a in articles if a.get("sentiment_label") == sentiment]

    total = len(articles)
    start = (page - 1) * page_size
    page_articles = articles[start: start + page_size]

    formatted = []
    for a in page_articles:
        formatted.append(NewsArticleResponse(
            id=a.get("external_id", ""),
            title=a["title"],
            summary=a.get("summary"),
            url=a["url"],
            source=a["source"],
            image_url=a.get("image_url"),
            sentiment=a.get("sentiment"),
            sentiment_label=a.get("sentiment_label"),
            affected_symbols=a.get("affected_symbols", []),
            portfolio_impact=a.get("portfolio_impact"),
            published_at=a["published_at"],
        ))

    return NewsFeedResponse(
        articles=formatted,
        total=total,
        page=page,
        page_size=page_size,
    )
