from datetime import datetime

from pydantic import BaseModel


class AiInsightResponse(BaseModel):
    id: str
    category: str
    severity: str
    title: str
    body: str
    action_items: list[str]
    is_read: bool
    is_dismissed: bool
    expires_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


class WhyLosingMoneyReport(BaseModel):
    overall_assessment: str
    primary_issues: list[dict]
    behavioral_mistakes: list[dict]
    structural_problems: list[dict]
    actionable_steps: list[str]
    estimated_recoverable_loss_usd: float | None
    generated_at: datetime


class MarkInsightReadRequest(BaseModel):
    insight_ids: list[str]
