"""
Civonix AI Insights Service
Generates structured, evidence-based AI insights from computed metrics.
Uses Google Gemini with real data — NEVER generic or hallucinated advice.
"""
from __future__ import annotations

import json
from typing import Any

import google.generativeai as genai
import structlog

from app.config import settings
from app.services.analytics_engine import PortfolioMetricsResult
from app.services.behavioral_engine import BehavioralResult

log = structlog.get_logger()

genai.configure(api_key=settings.GOOGLE_API_KEY)

_main_model = genai.GenerativeModel(
    model_name=settings.GEMINI_MODEL,
    system_instruction=(
        "You are Civonix AI, a professional quantitative analyst and trading psychologist. "
        "You analyze a trader's REAL computed portfolio metrics (NOT hypothetical) and provide: "
        "1. Honest, specific diagnoses of what is causing losses. "
        "2. Concrete, actionable improvement steps with expected impact. "
        "Rules: Base EVERY claim on the provided metric data. Quote specific numbers. "
        "Never give generic advice without referencing actual metric values. "
        "Be direct and honest. Prioritize the biggest impact issues first. "
        "Output must be valid JSON only — no markdown, no extra text, no code fences."
    ),
)

_fast_model = genai.GenerativeModel(model_name="gemini-2.0-flash")


def _fmt(v: Any, pct: bool = False, decimals: int = 2) -> str:
    if v is None:
        return "N/A"
    if pct:
        return f"{float(v) * 100:.{decimals}f}%"
    return f"{float(v):.{decimals}f}"


def _build_metrics_summary(
    metrics: PortfolioMetricsResult,
    behavioral: BehavioralResult,
) -> str:
    return f"""
## PORTFOLIO METRICS (computed from real trade data)

### Performance
- Total PnL: ${_fmt(metrics.total_pnl_usd)} USD
- Realized PnL: ${_fmt(metrics.realized_pnl_usd)} USD
- ROI (daily/weekly/monthly/yearly): {_fmt(metrics.roi_daily, pct=True)} / {_fmt(metrics.roi_weekly, pct=True)} / {_fmt(metrics.roi_monthly, pct=True)} / {_fmt(metrics.roi_yearly, pct=True)}
- CAGR: {_fmt(metrics.cagr, pct=True)}

### Risk
- Max Drawdown: {_fmt(metrics.max_drawdown, pct=True)}
- Avg Drawdown: {_fmt(metrics.avg_drawdown, pct=True)}
- Volatility (annualized): {_fmt(metrics.volatility_annualized, pct=True)}
- Downside Deviation: {_fmt(metrics.downside_deviation, pct=True)}
- VaR 95%: {_fmt(metrics.var_95, pct=True)}

### Risk-Adjusted Returns
- Sharpe Ratio: {_fmt(metrics.sharpe_ratio)}
- Sortino Ratio: {_fmt(metrics.sortino_ratio)}
- Calmar Ratio: {_fmt(metrics.calmar_ratio)}

### Trade Quality
- Total Trades: {metrics.total_trades}
- Win Rate: {_fmt(metrics.win_rate, pct=True)}
- Profit Factor: {_fmt(metrics.profit_factor)}
- Expectancy: ${_fmt(metrics.expectancy_usd)} per trade
- Avg Win: ${_fmt(metrics.avg_win_usd)} | Avg Loss: ${_fmt(metrics.avg_loss_usd)}
- Avg Holding Time: {_fmt(metrics.avg_holding_hours)} hours

### Portfolio Structure
- Diversification Score: {_fmt(metrics.diversification_score)} (0=concentrated, 1=diversified)
- Concentration Risk (HHI): {_fmt(metrics.concentration_risk)}
- BTC Exposure: {_fmt(metrics.btc_exposure_pct, pct=True)}
- Stablecoin %: {_fmt(metrics.stablecoin_pct, pct=True)}

### Market Comparison
- Beta vs BTC: {_fmt(metrics.beta_vs_btc)}
- Alpha vs BTC: {_fmt(metrics.alpha_vs_btc, pct=True)} (annualized)
- Correlation vs BTC: {_fmt(metrics.correlation_vs_btc)}
- Fear & Greed Score: {metrics.fear_greed_score}/100

## BEHAVIORAL ANALYSIS
- Discipline Score: {_fmt(behavioral.discipline_score)}/100
- Overtrading Score: {_fmt(behavioral.overtrading_score)}/100
- Avg Trades/Day: {_fmt(behavioral.avg_trades_per_day)}
- Revenge Trades: {behavioral.revenge_trade_count} (estimated loss: ${_fmt(behavioral.revenge_trade_loss_usd)})
- FOMO Buys: {behavioral.fomo_trade_count} (estimated loss: ${_fmt(behavioral.fomo_trade_loss_usd)})
- Panic Sells: {behavioral.panic_sell_count} (estimated loss: ${_fmt(behavioral.panic_sell_loss_usd)})
- Best Trading Hour (UTC): {behavioral.best_performing_hour}:00
- Worst Trading Hour (UTC): {behavioral.worst_performing_hour}:00
""".strip()


_WHY_LOSING_PROMPT = """
Based on the trader's metrics below, generate a "Why You Are Losing Money" report.

{metrics_summary}

Respond in this EXACT JSON format (no markdown, no code fences, raw JSON only):
{{
  "overall_assessment": "2-3 sentence honest summary of the trader's biggest problem",
  "primary_issues": [
    {{
      "issue": "short title",
      "severity": "critical|warning|info",
      "evidence": "cite the specific metric that proves this",
      "impact_usd": estimated_dollar_impact_or_null,
      "explanation": "1-2 sentence explanation of why this hurts"
    }}
  ],
  "behavioral_mistakes": [
    {{
      "mistake": "short title",
      "count": number_of_occurrences,
      "estimated_loss_usd": number_or_null,
      "how_to_fix": "specific, actionable 1-sentence fix"
    }}
  ],
  "structural_problems": [
    {{
      "problem": "e.g. over-concentration in BTC",
      "current_value": "the metric value",
      "target_value": "recommended range",
      "explanation": "why this is a problem"
    }}
  ],
  "actionable_steps": [
    "Specific action 1 with expected outcome",
    "Specific action 2 with expected outcome"
  ],
  "estimated_recoverable_loss_usd": number_or_null
}}

Include only real issues backed by the data. If a metric is healthy, don't fabricate a problem.
"""

_INSIGHT_PROMPT = """
Given these portfolio metrics, identify the TOP 3 most important actionable insights.

{metrics_summary}

Respond in this EXACT JSON format (array of 3 items, raw JSON only, no markdown):
[
  {{
    "category": "behavioral|risk|performance|opportunity",
    "severity": "critical|warning|info",
    "title": "short title (max 60 chars)",
    "body": "2-3 sentence evidence-based explanation citing specific numbers",
    "action_items": ["specific action 1", "specific action 2"]
  }}
]

Only report real issues. Do not invent problems if the metrics are healthy.
"""

_NEWS_SENTIMENT_PROMPT = """
Analyze the following crypto news article for sentiment and affected assets.

Title: {title}
Content: {content}

Respond in EXACT JSON (raw, no markdown, no code fences):
{{
  "sentiment": float_between_-1_and_1,
  "sentiment_label": "bullish|bearish|neutral",
  "affected_symbols": ["BTC", "ETH"],
  "summary": "1-2 sentence neutral factual summary"
}}
"""


def _clean_json(text: str) -> str:
    """Strip markdown code fences if Gemini adds them despite instructions."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[-1]
        text = text.rsplit("```", 1)[0]
    return text.strip()


async def generate_why_losing_money_report(
    metrics: PortfolioMetricsResult,
    behavioral: BehavioralResult,
) -> dict:
    summary = _build_metrics_summary(metrics, behavioral)
    prompt = _WHY_LOSING_PROMPT.format(metrics_summary=summary)
    raw = ""
    try:
        response = await _main_model.generate_content_async(prompt)
        raw = _clean_json(response.text)
        return json.loads(raw)
    except json.JSONDecodeError as e:
        log.error("AI response was not valid JSON", error=str(e), raw=raw)
        return {"error": "Failed to parse AI response"}
    except Exception as e:
        log.error("AI service error", error=str(e))
        return {"error": str(e)}


async def generate_portfolio_insights(
    metrics: PortfolioMetricsResult,
    behavioral: BehavioralResult,
) -> list[dict]:
    summary = _build_metrics_summary(metrics, behavioral)
    prompt = _INSIGHT_PROMPT.format(metrics_summary=summary)
    try:
        response = await _main_model.generate_content_async(prompt)
        raw = _clean_json(response.text)
        return json.loads(raw)
    except Exception as e:
        log.error("AI insight generation failed", error=str(e))
        return []


async def analyze_news_sentiment(title: str, content: str) -> dict:
    prompt = _NEWS_SENTIMENT_PROMPT.format(title=title, content=content[:2000])
    try:
        response = await _fast_model.generate_content_async(prompt)
        raw = _clean_json(response.text)
        return json.loads(raw)
    except Exception as e:
        log.warning("News sentiment analysis failed", error=str(e))
        return {"sentiment": 0.0, "sentiment_label": "neutral", "affected_symbols": [], "summary": title}
