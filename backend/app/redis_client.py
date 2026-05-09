import json
from typing import Any

import redis.asyncio as aioredis
import structlog

from app.config import settings

log = structlog.get_logger()

_redis: aioredis.Redis | None = None


async def get_redis() -> aioredis.Redis | None:
    global _redis
    if _redis is None:
        try:
            client = aioredis.from_url(settings.REDIS_URL, decode_responses=True, socket_connect_timeout=2)
            await client.ping()
            _redis = client
        except Exception as e:
            log.warning("Redis unavailable — caching disabled", error=str(e))
            return None
    return _redis


async def cache_set(key: str, value: Any, ttl: int = settings.REDIS_CACHE_TTL) -> None:
    r = await get_redis()
    if r is None:
        return
    try:
        await r.setex(key, ttl, json.dumps(value, default=str))
    except Exception:
        pass


async def cache_get(key: str) -> Any | None:
    global _redis
    r = await get_redis()
    if r is None:
        return None
    try:
        raw = await r.get(key)
        return json.loads(raw) if raw else None
    except Exception:
        _redis = None  # force reconnect next time
        return None


async def cache_delete(key: str) -> None:
    r = await get_redis()
    if r is None:
        return
    try:
        await r.delete(key)
    except Exception:
        pass


async def cache_delete_pattern(pattern: str) -> None:
    r = await get_redis()
    if r is None:
        return
    try:
        keys = await r.keys(pattern)
        if keys:
            await r.delete(*keys)
    except Exception:
        pass


# ── Sorted set helpers for leaderboard ──────────────────────────────────────

async def leaderboard_add(board: str, member: str, score: float) -> None:
    r = await get_redis()
    if r is None:
        return
    try:
        await r.zadd(board, {member: score})
    except Exception:
        pass


async def leaderboard_rank(board: str, member: str) -> int | None:
    r = await get_redis()
    if r is None:
        return None
    try:
        rank = await r.zrevrank(board, member)
        return rank + 1 if rank is not None else None
    except Exception:
        return None


async def leaderboard_top(board: str, n: int = 100) -> list[tuple[str, float]]:
    r = await get_redis()
    if r is None:
        return []
    try:
        return await r.zrevrange(board, 0, n - 1, withscores=True)
    except Exception:
        return []
