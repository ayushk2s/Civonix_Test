import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ExchangeAccount(Base):
    __tablename__ = "exchange_accounts"

    id:                   Mapped[uuid.UUID]       = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:              Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exchange:             Mapped[str]              = mapped_column(String(50), nullable=False)
    label:                Mapped[str]              = mapped_column(String(100), default="My Account")
    api_key_encrypted:        Mapped[str]              = mapped_column(Text, nullable=False)
    api_secret_encrypted:     Mapped[str]              = mapped_column(Text, nullable=False)
    passphrase_encrypted:     Mapped[str | None]       = mapped_column(Text)  # required for OKX
    is_active:            Mapped[bool]             = mapped_column(Boolean, default=True)
    last_synced_at:       Mapped[datetime | None]  = mapped_column(DateTime(timezone=True))
    sync_error:           Mapped[str | None]       = mapped_column(Text)
    created_at:           Mapped[datetime]         = mapped_column(DateTime(timezone=True), server_default=func.now())

    user   = relationship("User", back_populates="exchange_accounts")
    trades = relationship("Trade", back_populates="exchange_account", cascade="all, delete")
