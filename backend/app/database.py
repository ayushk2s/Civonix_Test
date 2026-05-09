import structlog
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

log = structlog.get_logger()

engine = create_async_engine(
    settings.DATABASE_URL,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    pool_pre_ping=True,
    echo=settings.APP_DEBUG,
    connect_args={"sslmode": "require"},
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    pass


async def get_db() -> AsyncSession:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            try:
                await session.rollback()
            except Exception:
                pass
            raise


async def create_tables() -> None:
    from sqlalchemy import text
    from app.models import user, exchange, trade, portfolio  # noqa: F401
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            # Idempotent migrations — fix enum columns created by schema.sql
            # and add any missing columns. Each runs independently.
            migrations = [
                "ALTER TABLE exchange_accounts ADD COLUMN IF NOT EXISTS passphrase_encrypted TEXT",
                "ALTER TABLE exchange_accounts ALTER COLUMN exchange TYPE TEXT USING exchange::TEXT",
                "ALTER TABLE trades ALTER COLUMN side TYPE TEXT USING side::TEXT",
                "ALTER TABLE trades ALTER COLUMN order_type TYPE TEXT USING order_type::TEXT",
                "ALTER TABLE trades ALTER COLUMN status TYPE TEXT USING status::TEXT",
                "ALTER TABLE ai_insights ALTER COLUMN category TYPE TEXT USING category::TEXT",
                "ALTER TABLE ai_insights ALTER COLUMN severity TYPE TEXT USING severity::TEXT",
                "ALTER TABLE leaderboard_entries ALTER COLUMN scope TYPE TEXT USING scope::TEXT",
            ]
            for sql in migrations:
                try:
                    await conn.execute(text(sql))
                    log.info("Migration OK", sql=sql[:80])
                except Exception as e:
                    print(f"[MIGRATION SKIPPED] {sql[:80]} => {e}", flush=True)
        log.info("Database tables created/verified")
    except Exception as e:
        log.error("Failed to create tables — check DATABASE_URL and SSL", error=str(e))
        print(f"\n[DB ERROR] create_tables failed: {e}\n", flush=True)
        raise
