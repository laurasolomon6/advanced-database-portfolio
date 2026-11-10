-- =====================================================================
-- MIT 8103 - Portfolio 2: Query Processing and Optimisation (Ace Bank)
-- optimisation.sql : four before/after index experiments
--
-- Run (and keep a copy of the output as evidence):
--     mkdir -p results
--     psql -d bankdb -f optimisation.sql | tee results/optimisation_output.txt
--
-- Each experiment:  (a) drops its index so the "before" is a fair
-- baseline, (b) runs EXPLAIN (ANALYZE, BUFFERS) BEFORE, (c) creates the
-- index and refreshes statistics, (d) runs the same EXPLAIN AFTER.
--
-- NOTE: EXPLAIN ANALYZE really executes the query. These are all
-- SELECT statements, so no data is changed.
-- =====================================================================

\timing on

-- Reset: remove all experimental indexes so every run starts clean.
-- (idx_txn_account and other baseline indexes from schema.sql are kept.)
DROP INDEX IF EXISTS idx_txn_created_at;
DROP INDEX IF EXISTS idx_txn_account_created;
DROP INDEX IF EXISTS idx_customer_name;
DROP INDEX IF EXISTS idx_txn_failed_created;
ANALYZE;

-- =====================================================================
-- EXPERIMENT 1: Date-range search on the transaction ledger
-- Question: all transactions in the last 7 days (about 2% of the table).
-- Expected: sequential scan before, index/bitmap scan after.
-- =====================================================================
\echo
\echo '=== EXPERIMENT 1: date range query - BEFORE index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, account_id, txn_type, amount, created_at
FROM bank_transaction
WHERE created_at >= NOW() - INTERVAL '7 days';

CREATE INDEX idx_txn_created_at ON bank_transaction (created_at);
ANALYZE bank_transaction;

\echo
\echo '=== EXPERIMENT 1: date range query - AFTER index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, account_id, txn_type, amount, created_at
FROM bank_transaction
WHERE created_at >= NOW() - INTERVAL '7 days';

SELECT 'idx_txn_created_at' AS index_name,
       pg_size_pretty(pg_relation_size('idx_txn_created_at')) AS index_size;

-- =====================================================================
-- EXPERIMENT 2: Account statement (filter by account, sort by date)
-- Baseline already has idx_txn_account (account_id only), so the
-- database finds the rows quickly but must still SORT them.
-- A composite index (account_id, created_at DESC) can return the rows
-- already in order, so the sort step should disappear.
-- =====================================================================
\echo
\echo '=== EXPERIMENT 2: account statement - BEFORE composite index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, txn_type, amount, balance_after, status, created_at
FROM bank_transaction
WHERE account_id = 1000000500
ORDER BY created_at DESC
LIMIT 20;

CREATE INDEX idx_txn_account_created
    ON bank_transaction (account_id, created_at DESC);
ANALYZE bank_transaction;

\echo
\echo '=== EXPERIMENT 2: account statement - AFTER composite index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, txn_type, amount, balance_after, status, created_at
FROM bank_transaction
WHERE account_id = 1000000500
ORDER BY created_at DESC
LIMIT 20;

SELECT 'idx_txn_account_created' AS index_name,
       pg_size_pretty(pg_relation_size('idx_txn_account_created')) AS index_size;

-- =====================================================================
-- EXPERIMENT 3: Customer search by full name
-- No index exists on names, so PostgreSQL scans all 20,000 customers.
-- A composite index on (last_name, first_name) should make it fast.
-- =====================================================================
\echo
\echo '=== EXPERIMENT 3: customer name search - BEFORE index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email, phone
FROM customer
WHERE last_name = 'Okafor' AND first_name = 'Amaka';

CREATE INDEX idx_customer_name ON customer (last_name, first_name);
ANALYZE customer;

\echo
\echo '=== EXPERIMENT 3: customer name search - AFTER index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, first_name, last_name, email, phone
FROM customer
WHERE last_name = 'Okafor' AND first_name = 'Amaka';

SELECT 'idx_customer_name' AS index_name,
       pg_size_pretty(pg_relation_size('idx_customer_name')) AS index_size;

-- =====================================================================
-- EXPERIMENT 4: Partial index for failed transactions
-- Compliance staff often look at FAILED transactions, which are only
-- about 3% of rows. A PARTIAL index stores only those rows, so it is
-- much smaller than a full index on the same column.
-- (idx_txn_created_at from Experiment 1 is dropped first so that the
-- "before" really has no helpful index.)
-- =====================================================================
DROP INDEX IF EXISTS idx_txn_created_at;
ANALYZE bank_transaction;

\echo
\echo '=== EXPERIMENT 4: failed transactions - BEFORE partial index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, account_id, amount, created_at
FROM bank_transaction
WHERE status = 'FAILED'
  AND created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

CREATE INDEX idx_txn_failed_created
    ON bank_transaction (created_at DESC)
    WHERE status = 'FAILED';
ANALYZE bank_transaction;

\echo
\echo '=== EXPERIMENT 4: failed transactions - AFTER partial index ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT txn_id, account_id, amount, created_at
FROM bank_transaction
WHERE status = 'FAILED'
  AND created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

-- Size comparison: partial index vs a full index on the same column
CREATE INDEX idx_txn_created_at ON bank_transaction (created_at);
SELECT 'idx_txn_failed_created (partial)' AS index_name,
       pg_size_pretty(pg_relation_size('idx_txn_failed_created')) AS index_size
UNION ALL
SELECT 'idx_txn_created_at (full)',
       pg_size_pretty(pg_relation_size('idx_txn_created_at'));

-- =====================================================================
-- Table size for reference
-- =====================================================================
SELECT pg_size_pretty(pg_relation_size('bank_transaction')) AS table_size;
