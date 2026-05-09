"""
Civonix News Service
Aggregates crypto news from multiple sources, analyzes sentiment,
and personalizes the feed based on user holdings.
"""
from __future__ import annotations

import asyncio
import hashlib
from datetime import datetime, timedelta, timezone

import aiohttp
import feedparser
import structlog

from app.config import settings
from app.services.ai_service import analyze_news_sentiment

log = structlog.get_logger()

RSS_FEEDS = [
    ("CoinDesk",      "https://www.coindesk.com/arc/outboundfeeds/rss/"),
    ("CoinTelegraph", "https://cointelegraph.com/rss"),
    ("The Block",     "https://www.theblock.co/rss.xml"),
    ("Decrypt",       "https://decrypt.co/feed"),
    ("Bitcoin Magazine", "https://bitcoinmagazine.com/feed"),
]


class NewsService:
    def __init__(self):
        self.session: aiohttp.ClientSession | None = None

    async def _get_session(self) -> aiohttp.ClientSession:
        if not self.session or self.session.closed:
            self.session = aiohttp.ClientSession(
                headers={"User-Agent": "Civonix/1.0 (crypto portfolio app)"},
                timeout=aiohttp.ClientTimeout(total=15),
            )
        return self.session

    async def fetch_rss_feed(self, source: str, url: str) -> list[dict]:
        try:
            session = await self._get_session()
            async with session.get(url) as resp:
                content = await resp.text()
            feed = feedparser.parse(content)
            articles = []
            for entry in feed.entries[:20]:
                published = entry.get("published_parsed")
                if published:
                    pub_dt = datetime(*published[:6], tzinfo=timezone.utc)
                else:
                    pub_dt = datetime.now(timezone.utc)

                # Skip older than 48h
                if datetime.now(timezone.utc) - pub_dt > timedelta(hours=48):
                    continue

                content_text = (
                    entry.get("summary", "")
                    or entry.get("content", [{}])[0].get("value", "")
                    or ""
                )

                external_id = hashlib.md5(entry.get("link", "").encode()).hexdigest()
                articles.append({
                    "external_id": external_id,
                    "title": entry.get("title", ""),
                    "url": entry.get("link", ""),
                    "source": source,
                    "content": content_text[:3000],
                    "image_url": self._extract_image(entry),
                    "published_at": pub_dt,
                })
        except Exception as e:
            log.warning("Failed to fetch RSS feed", source=source, url=url, error=str(e))
            articles = []
        return articles

    @staticmethod
    def _extract_image(entry: dict) -> str | None:
        if "media_thumbnail" in entry:
            thumbnails = entry["media_thumbnail"]
            if thumbnails:
                return thumbnails[0].get("url")
        if "links" in entry:
            for link in entry.get("links", []):
                if link.get("type", "").startswith("image"):
                    return link.get("href")
        return None

    async def fetch_all_news(self) -> list[dict]:
        """Fetch from all RSS feeds concurrently."""
        tasks = [self.fetch_rss_feed(source, url) for source, url in RSS_FEEDS]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        articles = []
        for batch in results:
            if isinstance(batch, list):
                articles.extend(batch)
        # Deduplicate by external_id
        seen = set()
        unique = []
        for a in articles:
            if a["external_id"] not in seen:
                seen.add(a["external_id"])
                unique.append(a)
        return sorted(unique, key=lambda x: x["published_at"], reverse=True)

    async def enrich_with_sentiment(self, articles: list[dict]) -> list[dict]:
        """Add sentiment analysis to each article using AI."""
        enriched = []
        semaphore = asyncio.Semaphore(5)  # max 5 concurrent AI calls

        async def analyze(article: dict) -> dict:
            async with semaphore:
                result = await analyze_news_sentiment(
                    article["title"],
                    article.get("content", ""),
                )
                article["sentiment"] = result.get("sentiment", 0.0)
                article["sentiment_label"] = result.get("sentiment_label", "neutral")
                article["affected_symbols"] = result.get("affected_symbols", [])
                article["summary"] = result.get("summary", article["title"])
                return article

        tasks = [analyze(a) for a in articles]
        enriched = await asyncio.gather(*tasks)
        return list(enriched)

    def filter_by_holdings(
        self,
        articles: list[dict],
        user_holdings: list[str],
    ) -> list[dict]:
        """Mark articles that affect user's holdings and compute impact."""
        for article in articles:
            affected = set(article.get("affected_symbols", []))
            user_set = set(h.upper() for h in user_holdings)
            overlap = affected & user_set
            if overlap:
                article["portfolio_impact"] = f"Affects your {', '.join(overlap)} holdings"
            else:
                article["portfolio_impact"] = None
        return articles

    async def close(self):
        if self.session and not self.session.closed:
            await self.session.close()
