import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Trade(Base):
    __tablename__ = "trades"

    id:                  Mapped[uuid.UUID]        = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id:             Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exchange_account_id: Mapped[uuid.UUID]         = mapped_column(UUID(as_uuid=True), ForeignKey("exchange_accounts.id", ondelete="CASCADE"), nullable=False)
    exchange_trade_id:   Mapped[str]               = mapped_column(String(100), nullable=False)
    symbol:              Mapped[str]               = mapped_column(String(20), nullable=False)
    base_asset:          Mapped[str]               = mapped_column(String(20), nullable=False)
    quote_asset:         Mapped[str]               = mapped_column(String(20), nullable=False)
    side:                Mapped[str]               = mapped_column(String(10), nullable=False)
    order_type:          Mapped[str]               = mapped_column(String(20), default="market")
    status:              Mapped[str]               = mapped_column(String(20), default="filled")
    price:               Mapped[Decimal]           = mapped_column(Numeric(28, 10), nullable=False)
    quantity:            Mapped[Decimal]           = mapped_column(Numeric(28, 10), nullable=False)
    quote_quantity:      Mapped[Decimal]           = mapped_column(Numeric(28, 10), nullable=False)
    fee:                 Mapped[Decimal]           = mapped_column(Numeric(28, 10), default=0)
    fee_asset:           Mapped[str | None]        = mapped_column(String(20))
    realized_pnl:        Mapped[Decimal | None]    = mapped_column(Numeric(28, 10))
    executed_at:         Mapped[datetime]          = mapped_column(DateTime(timezone=True), nullable=False)
    created_at:          Mapped[datetime]          = mapped_column(DateTime(timezone=True), server_default=func.now())

    user             = relationship("User", back_populates="trades")
    exchange_account = relationship("ExchangeAccount", back_populates="trades")
