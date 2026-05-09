import traceback
from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import (
    auth,
    portfolio,
    analytics,
    ai_insights,
    leaderboard,
    news,
    prediction,
)
from app.config import settings

log = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Civonix API starting", env=settings.APP_ENV)
    from app.database import create_tables
    await create_tables()
    yield
    log.info("Civonix API shutting down")


app = FastAPI(
    title="Civonix API",
    description="Next-generation crypto portfolio intelligence platform",
    version="1.0.0",
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
    lifespan=lifespan,
)

# ── Middleware ────────────────────────────────────────────────────────────────

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)

# ── Routes ────────────────────────────────────────────────────────────────────

app.include_router(auth.router,        prefix="/api/v1/auth",        tags=["Auth"])
app.include_router(portfolio.router,   prefix="/api/v1/portfolio",   tags=["Portfolio"])
app.include_router(analytics.router,   prefix="/api/v1/analytics",   tags=["Analytics"])
app.include_router(ai_insights.router, prefix="/api/v1/ai",          tags=["AI Insights"])
app.include_router(leaderboard.router, prefix="/api/v1/leaderboard", tags=["Leaderboard"])
app.include_router(news.router,        prefix="/api/v1/news",        tags=["News"])
app.include_router(prediction.router,  prefix="/api/v1/prediction",  tags=["Prediction"])


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    tb = "".join(traceback.format_exception(type(exc), exc, exc.__traceback__))
    log.error("Unhandled exception", path=str(request.url), error=str(exc))
    print(f"\n{'='*60}\nUNHANDLED ERROR on {request.url}\n{tb}\n{'='*60}\n", flush=True)
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc), "type": type(exc).__name__},
    )


@app.get("/health", tags=["Health"])
async def health():
    return JSONResponse({"status": "ok", "version": "1.0.0"})
