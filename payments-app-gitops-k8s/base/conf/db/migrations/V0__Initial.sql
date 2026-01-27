-- 1. THE EVENT STORE (Write Side - Source of Truth)
CREATE TABLE event_store (
    id BIGSERIAL PRIMARY KEY,

    aggregate_id VARCHAR(255) NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    version INT NOT NULL, -- The sequence number for this aggregate
    payload JSONB NOT NULL, -- The event data
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- CONSTRAINT: This matches the "Optimistic Locking" logic.
    -- It prevents two events with Version 5 from ever existing for the same account.
    CONSTRAINT unique_aggregate_version UNIQUE (aggregate_id, version)
);

-- 2. SNAPSHOTS (Optimization)
CREATE TABLE snapshots (
    aggregate_id VARCHAR(255) PRIMARY KEY,
    version INT NOT NULL,
    state JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. READ MODELS (Query Side - Projections)
-- These are updated asynchronously after events are committed.

-- A generic accounts view for fast balance checks
CREATE TABLE accounts_view (
    account_id VARCHAR(255) PRIMARY KEY,
    balance NUMERIC(20, 4) NOT NULL DEFAULT 0,
    last_updated_version INT NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- An audit log of all ledger lines for reporting
CREATE TABLE ledger_entries_view (
    id BIGSERIAL PRIMARY KEY,
    transaction_id UUID NOT NULL,
    account_id VARCHAR(255) NOT NULL,
    amount NUMERIC(20, 4) NOT NULL,
    direction VARCHAR(10) NOT NULL, -- 'DEBIT' or 'CREDIT'
    reference VARCHAR(255),
    posted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_ledger_account ON ledger_entries_view(account_id);
