import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id:             Mapped[uuid.UUID]  = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    auth_id:        Mapped[uuid.UUID]  = mapped_column(UUID(as_uuid=True), unique=True, nullable=False)
    username:       Mapped[str]        = mapped_column(String(50), unique=True, nullable=False)
    email:          Mapped[str]        = mapped_column(String(255), unique=True, nullable=False)
    display_name:   Mapped[str | None] = mapped_column(String(100))
    avatar_url:     Mapped[str | None] = mapped_column(Text)
    bio:            Mapped[str | None] = mapped_column(Text)
    country:        Mapped[str | None] = mapped_column(String(100))
    state_region:   Mapped[str | None] = mapped_column(String(100))
    city:           Mapped[str | None] = mapped_column(String(100))
    is_pro:         Mapped[bool]       = mapped_column(Boolean, default=False)
    is_verified:    Mapped[bool]       = mapped_column(Boolean, default=False)
    is_public:      Mapped[bool]       = mapped_column(Boolean, default=True)
    streak_days:    Mapped[int]        = mapped_column(Integer, default=0)
    total_predictions:   Mapped[int]   = mapped_column(Integer, default=0)
    correct_predictions: Mapped[int]   = mapped_column(Integer, default=0)
    created_at:     Mapped[datetime]   = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at:     Mapped[datetime]   = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    exchange_accounts = relationship("ExchangeAccount", back_populates="user", cascade="all, delete")
    trades            = relationship("Trade", back_populates="user", cascade="all, delete")
    portfolio_metrics = relationship("PortfolioMetrics", back_populates="user", uselist=False, cascade="all, delete")
    behavioral_metrics = relationship("BehavioralMetrics", back_populates="user", uselist=False, cascade="all, delete")
    ai_insights       = relationship("AiInsight", back_populates="user", cascade="all, delete")
    leaderboard_entries = relationship("LeaderboardEntry", back_populates="user", cascade="all, delete")
