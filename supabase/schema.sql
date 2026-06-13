-- EXTENSIVE EXPENSE & DEBT TRACKER - SUPABASE DATABASE SCHEMA
-- This file contains SQL definitions for transactions and debts.

-- 1. Transactions Table
-- Tracks income (gain) and expenses (spend).
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('gain', 'spend')),
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    description TEXT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing for quick querying of transactions by timestamp
CREATE INDEX IF NOT EXISTS idx_transactions_timestamp ON transactions(timestamp DESC);

-- 2. Debts Table
-- Dedicated registry for tracking person-by-person debt liabilities and interest rates.
CREATE TABLE IF NOT EXISTS debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_name TEXT NOT NULL,
    original_amount NUMERIC NOT NULL CHECK (original_amount >= 0),
    interest_rate NUMERIC NOT NULL CHECK (interest_rate >= 0), -- Annual interest rate in % (e.g. 5.5 for 5.5%)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing for lookup of debts by person name
CREATE INDEX IF NOT EXISTS idx_debts_person_name ON debts(person_name);

-- 3. Row Level Security (RLS) Configuration (Optional / Standard Supabase Setup)
-- Enable Row Level Security if required. For standard API bridging, we can allow public access or require API key:
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE debts ENABLE ROW LEVEL SECURITY;

-- Simple permissive policies allowing access from backend API
-- Replace these with authenticated user checks if using Supabase Auth directly in the future.
CREATE POLICY "Allow public backend read on transactions" ON transactions FOR SELECT USING (true);
CREATE POLICY "Allow public backend insert on transactions" ON transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public backend delete on transactions" ON transactions FOR DELETE USING (true);

CREATE POLICY "Allow public backend read on debts" ON debts FOR SELECT USING (true);
CREATE POLICY "Allow public backend insert on debts" ON debts FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public backend update on debts" ON debts FOR UPDATE USING (true);
CREATE POLICY "Allow public backend delete on debts" ON debts FOR DELETE USING (true);
