-- ============================================================
-- LizSwap PostgreSQL Initial Schema
-- ============================================================
-- File này tự động chạy khi PostgreSQL container khởi tạo lần đầu.
-- Đặt trong /docker-entrypoint-initdb.d/
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- 1. Bảng tokens
-- ============================================================
CREATE TABLE IF NOT EXISTS tokens (
    address         VARCHAR(42)     PRIMARY KEY,
    name            VARCHAR(100)    NOT NULL,
    symbol          VARCHAR(20)     NOT NULL,
    decimals        SMALLINT        NOT NULL DEFAULT 18,
    logo_url        TEXT,
    is_active       BOOLEAN         NOT NULL DEFAULT true,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tokens_symbol ON tokens (symbol);
CREATE INDEX IF NOT EXISTS idx_tokens_is_active ON tokens (is_active) WHERE is_active = true;

-- ============================================================
-- 2. Bảng pools
-- ============================================================
CREATE TABLE IF NOT EXISTS pools (
    pair_address    VARCHAR(42)     PRIMARY KEY,
    token0_address  VARCHAR(42)     NOT NULL REFERENCES tokens(address),
    token1_address  VARCHAR(42)     NOT NULL REFERENCES tokens(address),
    reserve0        NUMERIC(38,18)  NOT NULL DEFAULT 0,
    reserve1        NUMERIC(38,18)  NOT NULL DEFAULT 0,
    tvl_usd         NUMERIC(24,2)   NOT NULL DEFAULT 0,
    volume_24h_usd  NUMERIC(24,2)   NOT NULL DEFAULT 0,
    fee_24h_usd     NUMERIC(24,2)   NOT NULL DEFAULT 0,
    apr             NUMERIC(8,2)    NOT NULL DEFAULT 0,
    tx_count_24h    INT             NOT NULL DEFAULT 0,
    total_supply_lp NUMERIC(38,18)  NOT NULL DEFAULT 0,
    created_at      BIGINT          NOT NULL,
    last_updated    TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pools_token0 ON pools (token0_address);
CREATE INDEX IF NOT EXISTS idx_pools_token1 ON pools (token1_address);
CREATE INDEX IF NOT EXISTS idx_pools_tvl ON pools (tvl_usd DESC);

-- ============================================================
-- 3. Bảng ohlcv_candles
-- ============================================================
CREATE TABLE IF NOT EXISTS ohlcv_candles (
    id              BIGSERIAL       PRIMARY KEY,
    pair_address    VARCHAR(42)     NOT NULL,
    token0          VARCHAR(42)     NOT NULL,
    token1          VARCHAR(42)     NOT NULL,
    interval        VARCHAR(4)      NOT NULL,
    open_time       BIGINT          NOT NULL,
    open            NUMERIC(38,18)  NOT NULL,
    high            NUMERIC(38,18)  NOT NULL,
    low             NUMERIC(38,18)  NOT NULL,
    close           NUMERIC(38,18)  NOT NULL,
    volume          NUMERIC(38,18)  NOT NULL DEFAULT 0,
    tx_count        INT             NOT NULL DEFAULT 0,

    CONSTRAINT uq_candle UNIQUE (pair_address, interval, open_time)
);

CREATE INDEX IF NOT EXISTS idx_candles_query ON ohlcv_candles (pair_address, interval, open_time);

-- ============================================================
-- 4. Bảng activity_log
-- ============================================================
CREATE TABLE IF NOT EXISTS activity_log (
    id              BIGSERIAL       PRIMARY KEY,
    tx_hash         VARCHAR(66)     NOT NULL,
    event_type      VARCHAR(20)     NOT NULL,
    pair_address    VARCHAR(42)     NOT NULL,
    wallet_address  VARCHAR(42)     NOT NULL,
    amount0_in      NUMERIC(38,18)  DEFAULT 0,
    amount1_in      NUMERIC(38,18)  DEFAULT 0,
    amount0_out     NUMERIC(38,18)  DEFAULT 0,
    amount1_out     NUMERIC(38,18)  DEFAULT 0,
    liquidity       NUMERIC(38,18)  DEFAULT 0,
    block_number    BIGINT          NOT NULL,
    timestamp       BIGINT          NOT NULL,
    indexed_at      TIMESTAMP       NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_event_type CHECK (event_type IN ('swap', 'mint', 'burn'))
);

CREATE INDEX IF NOT EXISTS idx_activity_pair_time ON activity_log (pair_address, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_activity_event_type ON activity_log (event_type);
CREATE INDEX IF NOT EXISTS idx_activity_wallet ON activity_log (wallet_address);
CREATE INDEX IF NOT EXISTS idx_activity_tx_hash ON activity_log (tx_hash);
CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON activity_log (timestamp DESC);

-- ============================================================
-- 5. Bảng user_roles
-- ============================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('manager', 'staff');
    END IF;
END$$;

CREATE TABLE IF NOT EXISTS user_roles (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_address  VARCHAR(42)     NOT NULL UNIQUE,
    role            user_role       NOT NULL DEFAULT 'staff',
    created_by      UUID            REFERENCES user_roles(id) ON DELETE SET NULL,
    is_active       BOOLEAN         NOT NULL DEFAULT true,
    created_at      TIMESTAMP       NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_roles_active ON user_roles (is_active) WHERE is_active = true;

-- ============================================================
-- 6. Bảng system_config
-- ============================================================
CREATE TABLE IF NOT EXISTS system_config (
    key             VARCHAR(100)    PRIMARY KEY,
    value           JSONB           NOT NULL,
    updated_by      VARCHAR(42)     NOT NULL,
    updated_at      TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 7. Seed Data – Initial Manager
-- ============================================================
-- Manager wallet address được truyền qua biến môi trường MANAGER_WALLET
-- Docker entrypoint sẽ thay thế placeholder trước khi chạy
INSERT INTO user_roles (wallet_address, role, created_by, is_active)
VALUES ('0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4', 'manager', NULL, true)
ON CONFLICT (wallet_address) DO NOTHING;

-- ============================================================
-- 8. Seed Data – Default System Config
-- ============================================================
INSERT INTO system_config (key, value, updated_by) VALUES
    ('protocol_fee_enabled', 'true', '0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4'),
    ('fee_to_address', '"0x0000000000000000000000000000000000000000"', '0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4'),
    ('reward_per_block', '"0.5"', '0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4'),
    ('indexer_poll_interval_ms', '2000', '0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4'),
    ('maintenance_mode', 'false', '0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- Done
-- ============================================================
DO $$
BEGIN
    RAISE NOTICE 'LizSwap schema initialized successfully!';
    RAISE NOTICE 'Manager wallet: 0x070714e05b45f236FeAe2A87Cb1A740fAfA047B4';
END$$;
