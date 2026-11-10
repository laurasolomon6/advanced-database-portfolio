-- =====================================================================
-- MIT 8103 - Portfolio 2: Query Processing and Optimisation (Ace Bank)
-- generate_data.sql : fills the Ace Bank database with simulated data
--
-- Volumes: 20,000 customers | 10 branches | 30,000 accounts
--          300,000 transactions
--
-- Run AFTER schema.sql:
--     psql -d bankdb -f generate_data.sql
--
-- This script is safe to re-run: it empties the data tables first
-- (but keeps the account_type lookup rows from schema.sql).
-- =====================================================================

\timing on

-- Reset data (RESTART IDENTITY makes ids start from 1 again)
TRUNCATE audit_log, loan_repayment, loan, card, transfer,
         bank_transaction, account, customer, branch
         RESTART IDENTITY CASCADE;

-- ---------------------------------------------------------------------
-- 1. Branches (10 in total, ids 1 to 10)
-- ---------------------------------------------------------------------
INSERT INTO branch (branch_name, city) VALUES
    ('Ikeja Main',    'Lagos'),
    ('Wuse II',       'Abuja'),
    ('Garden City',   'Port Harcourt'),
    ('Sabon Gari',    'Kano'),
    ('Dugbe',         'Ibadan'),
    ('Independence Layout', 'Enugu'),
    ('Kawo',          'Kaduna'),
    ('Ring Road',     'Benin City'),
    ('Lekki Phase 1', 'Lagos'),
    ('Maitama',       'Abuja');

-- ---------------------------------------------------------------------
-- 2. Customers (20,000)
-- ---------------------------------------------------------------------
INSERT INTO customer (first_name, last_name, email, phone, national_id,
                      date_of_birth, address, date_joined)
SELECT
    (ARRAY['Chidi','Amaka','Tunde','Ngozi','Emeka','Funke','Ibrahim','Aisha','Segun','Zainab',
           'Obinna','Folake','Musa','Chioma','Kunle','Hauwa','Uche','Bisi','Yusuf','Ifeoma',
           'Dayo','Halima','Femi','Nneka','Sani'])[1 + floor(random() * 25)::int],
    (ARRAY['Okafor','Adeyemi','Bello','Eze','Balogun','Nwosu','Abubakar','Ojo','Danjuma','Okonkwo',
           'Lawal','Ibe','Olawale','Yakubu','Chukwu','Ogunleye','Garba','Nnamdi','Salami','Umeh',
           'Adebayo','Mohammed','Igwe','Fashola','Oyelaran'])[1 + floor(random() * 25)::int],
    'customer' || g || '@acebank.example',
    '080' || lpad(g::text, 8, '0'),
    lpad((22000000000 + g)::text, 11, '0'),
    DATE '1960-01-01' + floor(random() * 15000)::int,   -- all adults
    'Address ' || g,
    CURRENT_DATE - floor(random() * 1500)::int
FROM generate_series(1, 20000) AS g;

-- ---------------------------------------------------------------------
-- 3. Accounts (30,000). Every customer gets at least one account.
--    account_id values run 1000000001 ... 1000030000
-- ---------------------------------------------------------------------
INSERT INTO account (customer_id, type_id, branch_id, balance, status, opened_date)
SELECT
    1 + ((g - 1) % 20000),
    1 + floor(random() * 3)::int,
    1 + floor(random() * 10)::int,
    round((random() * 5000000)::numeric, 2),
    CASE WHEN random() < 0.90 THEN 'ACTIVE'
         WHEN random() < 0.60 THEN 'DORMANT'
         ELSE 'FROZEN' END,
    CURRENT_DATE - floor(random() * 1500)::int
FROM generate_series(1, 30000) AS g;

-- ---------------------------------------------------------------------
-- 4. Transactions (300,000) spread across the last 365 days.
--    About 3% are FAILED. Values are simulated, so balance_after is
--    random here. Portfolio 3 handles real balance-consistent transfers.
-- ---------------------------------------------------------------------
INSERT INTO bank_transaction (account_id, txn_type, amount, balance_after,
                              status, reference, narration, created_at)
SELECT
    1000000001 + floor(random() * 30000)::bigint,
    (ARRAY['DEPOSIT','WITHDRAWAL','TRANSFER_DEBIT','TRANSFER_CREDIT','FEE'])[1 + floor(random() * 5)::int],
    round((100 + random() * 200000)::numeric, 2),
    round((random() * 5000000)::numeric, 2),
    CASE WHEN random() < 0.03 THEN 'FAILED' ELSE 'SUCCESS' END,
    'REF' || lpad(g::text, 10, '0'),
    'Simulated transaction ' || g,
    NOW() - random() * INTERVAL '365 days'
FROM generate_series(1, 300000) AS g;

-- ---------------------------------------------------------------------
-- 5. Refresh planner statistics so execution plans are realistic
-- ---------------------------------------------------------------------
ANALYZE;

-- Quick check of the row counts
SELECT 'customer' AS table_name, COUNT(*) AS rows FROM customer
UNION ALL SELECT 'branch', COUNT(*) FROM branch
UNION ALL SELECT 'account', COUNT(*) FROM account
UNION ALL SELECT 'bank_transaction', COUNT(*) FROM bank_transaction;
