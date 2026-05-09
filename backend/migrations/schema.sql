-- ═══════════════════════════════════════════════════════════════════════
-- Civonix Database Schema v1.0
-- PostgreSQL / Supabase
-- ═══════════════════════════════════════════════════════════════════════

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─────────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────────

CREATE TYPE exchange_type AS ENUM ('binance', 'coinbase', 'kraken', 'bybit', 'okx', 'kucoin');
CREATE TYPE trade_side AS ENUM ('buy', 'sell');
CREATE TYPE order_type AS ENUM ('market', 'limit', 'stop_loss', 'take_profit', 'stop_limit');
CREATE TYPE trade_status AS ENUM ('filled', 'partial', 'cancelled');
CREATE TYPE insight_severity AS ENUM ('info', 'warning', 'critical');
CREATE TYPE insight_category AS ENUM ('behavioral', 'risk', 'performance', 'opportunity');
CREATE TYPE prediction_direction AS ENUM ('up', 'down');
CREATE TYPE leaderboard_scope AS ENUM ('district', 'state', 'country', 'global');

-- ─────────────────────────────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_id       UUID UNIQUE NOT NULL,          -- Supabase auth.users.id
    username      TEXT UNIQUE NOT NULL,
    email         TEXT UNIQUE NOT NULL,
    display_name  TEXT,
    avatar_url    TEXT,
    bio           TEXT,
    country       TEXT,
    state_region  TEXT,
    city          TEXT,
    is_pro        BOOLEAN NOT NULL DEFAULT FALSE,
    is_verified   BOOLEAN NOT NULL DEFAULT FALSE,
    is_public     BOOLEAN NOT NULL DEFAULT TRUE,  -- public profile for leaderboard
    streak_days   INT NOT NULL DEFAULT 0,
    total_predictions INT NOT NULL DEFAULT 0,
    correct_predictions INT NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_auth_id ON users(auth_id);
CREATE INDEX idx_users_country ON users(country);
CREATE INDEX idx_users_state   ON users(state_region);

-- ─────────────────────────────────────────────────────────────────
-- EXCHANGE ACCOUNTS (encrypted API keys)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE exchange_accounts (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exchange          exchange_type NOT NULL,
    label             TEXT NOT NULL DEFAULT 'My Account',
    api_key_encrypted TEXT NOT NULL,   -- AES-256 encrypted
    api_secret_encrypted TEXT NOT NULL,
    is_active         BOOLEAN NOT NULL DEFAULT TRUE,
    last_synced_at    TIMESTAMPTZ,
    sync_error        TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exchange_accounts_user ON exchange_accounts(user_id);

-- ─────────────────────────────────────────────────────────────────
-- ASSETS (market data reference)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE assets (
    symbol        TEXT PRIMARY KEY,   -- e.g. BTC, ETH, SOL
    name          TEXT NOT NULL,
    logo_url      TEXT,
    coingecko_id  TEXT,
    market_cap_rank INT,
    is_stablecoin BOOLEAN NOT NULL DEFAULT FALSE,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO assets (symbol, name, coingecko_id, market_cap_rank) VALUES
    ('BTC',  'Bitcoin',    'bitcoin',  1),
    ('ETH',  'Ethereum',   'ethereum', 2),
    ('USDT', 'Tether',     'tether',   3),
    ('BNB',  'BNB',        'binancecoin', 4),
    ('SOL',  'Solana',     'solana',   5),
    ('USDC', 'USD Coin',   'usd-coin', 6),
    ('XRP',  'XRP',        'ripple',   7),
    ('ADA',  'Cardano',    'cardano',  8),
    ('AVAX', 'Avalanche',  'avalanche-2', 9),
    ('DOGE', 'Dogecoin',   'dogecoin', 10);

-- ─────────────────────────────────────────────────────────────────
-- TRADES (raw trade ledger — source of truth)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE trades (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exchange_account_id UUID NOT NULL REFERENCES exchange_accounts(id) ON DELETE CASCADE,
    exchange_trade_id TEXT NOT NULL,   -- ID from the exchange
    symbol            TEXT NOT NULL,  -- e.g. BTCUSDT
    base_asset        TEXT NOT NULL,  -- BTC
    quote_asset       TEXT NOT NULL,  -- USDT
    side              trade_side NOT NULL,
    order_type        order_type NOT NULL DEFAULT 'market',
    status            trade_status NOT NULL DEFAULT 'filled',
    price             NUMERIC(28, 10) NOT NULL,
    quantity          NUMERIC(28, 10) NOT NULL,
    quote_quantity    NUMERIC(28, 10) NOT NULL,  -- price * quantity
    fee               NUMERIC(28, 10) NOT NULL DEFAULT 0,
    fee_asset         TEXT,
    realized_pnl      NUMERIC(28, 10),            -- computed post-sync
    executed_at       TIMESTAMPTZ NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (exchange_account_id, exchange_trade_id)
);

CREATE INDEX idx_trades_user       ON trades(user_id);
CREATE INDEX idx_trades_executed   ON trades(user_id, executed_at DESC);
CREATE INDEX idx_trades_symbol     ON trades(user_id, symbol);
CREATE INDEX idx_trades_exchange   ON trades(exchange_account_id);

-- ─────────────────────────────────────────────────────────────────
-- PORTFOLIO SNAPSHOTS (daily balance snapshots for return series)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE portfolio_snapshots (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    snapshot_date   DATE NOT NULL,
    total_value_usd NUMERIC(20, 4) NOT NULL,
    btc_price_usd   NUMERIC(20, 4),
    daily_return    NUMERIC(12, 8),       -- (today - yesterday) / yesterday
    holdings        JSONB NOT NULL DEFAULT '{}',  -- {symbol: {qty, value_usd}}
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, snapshot_date)
);

CREATE INDEX idx_snapshots_user_date ON portfolio_snapshots(user_id, snapshot_date DESC);

-- ─────────────────────────────────────────────────────────────────
-- PORTFOLIO METRICS (computed analytics cache)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE portfolio_metrics (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    computed_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    period_days           INT NOT NULL DEFAULT 365,  -- rolling window

    -- Performance
    total_pnl_usd         NUMERIC(20, 4),
    realized_pnl_usd      NUMERIC(20, 4),
    unrealized_pnl_usd    NUMERIC(20, 4),
    roi_daily             NUMERIC(12, 8),
    roi_weekly            NUMERIC(12, 8),
    roi_monthly           NUMERIC(12, 8),
    roi_yearly            NUMERIC(12, 8),
    roi_all_time          NUMERIC(12, 8),
    cagr                  NUMERIC(12, 8),

    -- Risk
    max_drawdown          NUMERIC(12, 8),
    avg_drawdown          NUMERIC(12, 8),
    volatility_daily      NUMERIC(12, 8),
    volatility_annualized NUMERIC(12, 8),
    downside_deviation    NUMERIC(12, 8),
    var_95                NUMERIC(12, 8),   -- Value at Risk 95%
    var_99                NUMERIC(12, 8),

    -- Risk-Adjusted
    sharpe_ratio          NUMERIC(12, 6),
    sortino_ratio         NUMERIC(12, 6),
    calmar_ratio          NUMERIC(12, 6),

    -- Trade Quality
    total_trades          INT,
    winning_trades        INT,
    losing_trades         INT,
    win_rate              NUMERIC(8, 6),
    loss_rate             NUMERIC(8, 6),
    profit_factor         NUMERIC(12, 6),
    expectancy_usd        NUMERIC(20, 4),
    avg_win_usd           NUMERIC(20, 4),
    avg_loss_usd          NUMERIC(20, 4),
    avg_win_loss_ratio    NUMERIC(12, 6),
    avg_holding_hours     NUMERIC(12, 4),

    -- Portfolio Structure
    diversification_score NUMERIC(8, 6),   -- 0-1
    concentration_risk    NUMERIC(8, 6),   -- HHI index
    btc_exposure_pct      NUMERIC(8, 6),
    eth_exposure_pct      NUMERIC(8, 6),
    stablecoin_pct        NUMERIC(8, 6),

    -- Market Comparison
    beta_vs_btc           NUMERIC(12, 6),
    alpha_vs_btc          NUMERIC(12, 6),
    correlation_vs_btc    NUMERIC(12, 6),
    fear_greed_score      INT,             -- 0-100

    UNIQUE (user_id)  -- keep only latest
);

CREATE INDEX idx_metrics_user ON portfolio_metrics(user_id);

-- ─────────────────────────────────────────────────────────────────
-- BEHAVIORAL METRICS
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE behavioral_metrics (
    id                       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    computed_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    overtrading_score        NUMERIC(8, 4),   -- 0-100
    avg_trades_per_day       NUMERIC(8, 4),
    revenge_trade_count      INT DEFAULT 0,
    revenge_trade_loss_usd   NUMERIC(20, 4) DEFAULT 0,
    fomo_trade_count         INT DEFAULT 0,
    fomo_trade_loss_usd      NUMERIC(20, 4) DEFAULT 0,
    panic_sell_count         INT DEFAULT 0,
    panic_sell_loss_usd      NUMERIC(20, 4) DEFAULT 0,
    best_performing_hour     INT,  -- 0-23 UTC
    worst_performing_hour    INT,
    best_performing_day      INT,  -- 0=Mon, 6=Sun
    worst_performing_day     INT,
    discipline_score         NUMERIC(8, 4),  -- 0-100

    UNIQUE (user_id)
);

-- ─────────────────────────────────────────────────────────────────
-- AI INSIGHTS
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE ai_insights (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category      insight_category NOT NULL,
    severity      insight_severity NOT NULL DEFAULT 'info',
    title         TEXT NOT NULL,
    body          TEXT NOT NULL,
    action_items  JSONB NOT NULL DEFAULT '[]',   -- list of actionable strings
    metrics_used  JSONB NOT NULL DEFAULT '{}',   -- snapshot of metrics that triggered this
    is_read       BOOLEAN NOT NULL DEFAULT FALSE,
    is_dismissed  BOOLEAN NOT NULL DEFAULT FALSE,
    expires_at    TIMESTAMPTZ,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_insights_user        ON ai_insights(user_id, created_at DESC);
CREATE INDEX idx_insights_unread      ON ai_insights(user_id) WHERE is_read = FALSE;

-- ─────────────────────────────────────────────────────────────────
-- LEADERBOARD (denormalized for fast reads)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE leaderboard_entries (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scope             leaderboard_scope NOT NULL,
    scope_value       TEXT NOT NULL,   -- country code, state name, or 'global'
    rank              INT,
    roi_30d           NUMERIC(12, 8),
    sharpe_ratio      NUMERIC(12, 6),
    win_rate          NUMERIC(8, 6),
    total_pnl_usd     NUMERIC(20, 4),
    winning_streak    INT DEFAULT 0,
    losing_streak     INT DEFAULT 0,
    consistency_score NUMERIC(8, 4),  -- custom composite score
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, scope, scope_value)
);

CREATE INDEX idx_leaderboard_scope ON leaderboard_entries(scope, scope_value, rank);
CREATE INDEX idx_leaderboard_user  ON leaderboard_entries(user_id);

-- ─────────────────────────────────────────────────────────────────
-- NEWS ARTICLES (cached, personalized)
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE news_articles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_id     TEXT UNIQUE,
    title           TEXT NOT NULL,
    summary         TEXT,
    url             TEXT NOT NULL,
    source          TEXT NOT NULL,
    image_url       TEXT,
    sentiment       NUMERIC(5, 4),    -- -1.0 (bearish) to +1.0 (bullish)
    sentiment_label TEXT,             -- 'bullish', 'bearish', 'neutral'
    affected_symbols TEXT[],          -- ['BTC', 'ETH']
    published_at    TIMESTAMPTZ NOT NULL,
    fetched_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_news_published    ON news_articles(published_at DESC);
CREATE INDEX idx_news_symbols      ON news_articles USING GIN(affected_symbols);

-- ─────────────────────────────────────────────────────────────────
-- DAILY PREDICTION GAME
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE daily_predictions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    game_date       DATE UNIQUE NOT NULL,
    asset_symbol    TEXT NOT NULL DEFAULT 'BTC',
    open_price      NUMERIC(20, 4),
    close_price     NUMERIC(20, 4),
    actual_direction prediction_direction,
    up_votes        INT NOT NULL DEFAULT 0,
    down_votes      INT NOT NULL DEFAULT 0,
    resolved        BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_predictions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    prediction_id   UUID NOT NULL REFERENCES daily_predictions(id) ON DELETE CASCADE,
    direction       prediction_direction NOT NULL,
    is_correct      BOOLEAN,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, prediction_id)
);

CREATE INDEX idx_user_predictions_user ON user_predictions(user_id);
CREATE INDEX idx_user_predictions_date ON user_predictions(prediction_id);

-- ─────────────────────────────────────────────────────────────────
-- BADGES
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE badges (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug        TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    description TEXT,
    icon        TEXT,
    criteria    JSONB NOT NULL DEFAULT '{}'
);

INSERT INTO badges (slug, name, description, icon, criteria) VALUES
    ('first_trade',       'First Blood',      'Connected first exchange',       '🎯', '{"type": "trade_count", "value": 1}'),
    ('win_streak_5',      'Hot Streak',       '5 winning trades in a row',      '🔥', '{"type": "win_streak", "value": 5}'),
    ('win_streak_10',     'Unstoppable',      '10 winning trades in a row',     '⚡', '{"type": "win_streak", "value": 10}'),
    ('sharpe_above_2',    'Risk Master',      'Sharpe ratio above 2.0',         '🧠', '{"type": "sharpe_ratio", "min": 2.0}'),
    ('prediction_10',     'Oracle',           '10 correct daily predictions',   '🔮', '{"type": "correct_predictions", "value": 10}'),
    ('top_10_global',     'Elite Trader',     'Top 10 global leaderboard',      '👑', '{"type": "global_rank", "max": 10}'),
    ('no_revenge_30d',    'Ice Cold',         '30 days with no revenge trades', '🧊', '{"type": "no_revenge_days", "value": 30}');

CREATE TABLE user_badges (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id    UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, badge_id)
);

-- ─────────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY (Supabase RLS)
-- ─────────────────────────────────────────────────────────────────

ALTER TABLE users                ENABLE ROW LEVEL SECURITY;
ALTER TABLE exchange_accounts    ENABLE ROW LEVEL SECURITY;
ALTER TABLE trades               ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_snapshots  ENABLE ROW LEVEL SECURITY;
ALTER TABLE portfolio_metrics    ENABLE ROW LEVEL SECURITY;
ALTER TABLE behavioral_metrics   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_insights          ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_predictions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_badges          ENABLE ROW LEVEL SECURITY;

-- Users: own profile + public read for leaderboard
CREATE POLICY "Users: read own"   ON users FOR SELECT USING (auth.uid() = auth_id);
CREATE POLICY "Users: update own" ON users FOR UPDATE USING (auth.uid() = auth_id);
CREATE POLICY "Users: read public" ON users FOR SELECT USING (is_public = TRUE);

-- Exchange accounts: private
CREATE POLICY "Exchange: own only" ON exchange_accounts FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Trades: private
CREATE POLICY "Trades: own only" ON trades FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Portfolio snapshots: private
CREATE POLICY "Snapshots: own only" ON portfolio_snapshots FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Metrics: own + read-only public (for leaderboard comparison)
CREATE POLICY "Metrics: own only" ON portfolio_metrics FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Behavioral: private
CREATE POLICY "Behavioral: own only" ON behavioral_metrics FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- AI Insights: private
CREATE POLICY "Insights: own only" ON ai_insights FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- Leaderboard: public read, own write
CREATE POLICY "Leaderboard: public read" ON leaderboard_entries FOR SELECT USING (TRUE);
CREATE POLICY "Leaderboard: service write" ON leaderboard_entries FOR ALL
    USING (user_id = (SELECT id FROM users WHERE auth_id = auth.uid()));

-- ─────────────────────────────────────────────────────────────────
-- FUNCTIONS & TRIGGERS
-- ─────────────────────────────────────────────────────────────────

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Daily prediction vote counter
CREATE OR REPLACE FUNCTION update_prediction_vote()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.direction = 'up' THEN
            UPDATE daily_predictions SET up_votes = up_votes + 1 WHERE id = NEW.prediction_id;
        ELSE
            UPDATE daily_predictions SET down_votes = down_votes + 1 WHERE id = NEW.prediction_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prediction_vote
    AFTER INSERT ON user_predictions
    FOR EACH ROW EXECUTE FUNCTION update_prediction_vote();

-- ─────────────────────────────────────────────────────────────────
-- INDEXES FOR PERFORMANCE
-- ─────────────────────────────────────────────────────────────────

CREATE INDEX idx_trades_user_date_symbol ON trades(user_id, executed_at DESC, symbol);
CREATE INDEX idx_news_sentiment ON news_articles(sentiment, published_at DESC);
CREATE INDEX idx_leaderboard_global_roi ON leaderboard_entries(roi_30d DESC)
    WHERE scope = 'global';
