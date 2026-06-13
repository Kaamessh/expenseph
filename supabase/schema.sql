-- EXTENSIVE EXPENSE & DEBT TRACKER - SUPABASE DATABASE SCHEMA (MIGRATION SAFE)
-- This file contains SQL definitions for users, transactions, and debts.

-- 1. Users Table
-- Stores user credentials for authentication.
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    mobile_number TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexing for quick lookups by email and mobile number
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_mobile ON users(mobile_number);

-- 2. Transactions Table
-- Tracks income (gain) and expenses (spend).
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('gain', 'spend')),
    amount NUMERIC NOT NULL CHECK (amount >= 0),
    description TEXT NULL,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Safely add user_id relation if it doesn't exist (important for existing tables)
ALTER TABLE transactions 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Indexing for user-scoped queries by time
CREATE INDEX IF NOT EXISTS idx_transactions_user_timestamp ON transactions(user_id, timestamp DESC);

-- 3. Debts Table
-- Track individual debt profiles.
CREATE TABLE IF NOT EXISTS debts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_name TEXT NOT NULL,
    original_amount NUMERIC NOT NULL CHECK (original_amount >= 0),
    interest_rate NUMERIC NOT NULL CHECK (interest_rate >= 0), -- Annual interest rate in %
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Safely add user_id relation if it doesn't exist (important for existing tables)
ALTER TABLE debts 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id) ON DELETE CASCADE;

-- Indexing for lookup of user-scoped debts
CREATE INDEX IF NOT EXISTS idx_debts_user_person ON debts(user_id, person_name);

-- 4. Row Level Security (RLS) Configuration
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE debts ENABLE ROW LEVEL SECURITY;

-- Standard permissive policies for API communication
-- Dropping first to prevent duplicate definition errors

DROP POLICY IF EXISTS "Allow public backend read on users" ON users;
DROP POLICY IF EXISTS "Allow public backend insert on users" ON users;
CREATE POLICY "Allow public backend read on users" ON users FOR SELECT USING (true);
CREATE POLICY "Allow public backend insert on users" ON users FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public backend read on transactions" ON transactions;
DROP POLICY IF EXISTS "Allow public backend insert on transactions" ON transactions;
DROP POLICY IF EXISTS "Allow public backend delete on transactions" ON transactions;
CREATE POLICY "Allow public backend read on transactions" ON transactions FOR SELECT USING (true);
CREATE POLICY "Allow public backend insert on transactions" ON transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public backend delete on transactions" ON transactions FOR DELETE USING (true);

DROP POLICY IF EXISTS "Allow public backend read on debts" ON debts;
DROP POLICY IF EXISTS "Allow public backend insert on debts" ON debts;
DROP POLICY IF EXISTS "Allow public backend update on debts" ON debts;
DROP POLICY IF EXISTS "Allow public backend delete on debts" ON debts;
CREATE POLICY "Allow public backend read on debts" ON debts FOR SELECT USING (true);
CREATE POLICY "Allow public backend insert on debts" ON debts FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public backend update on debts" ON debts FOR UPDATE USING (true);
CREATE POLICY "Allow public backend delete on debts" ON debts FOR DELETE USING (true);
