-- =====================================================================
-- MIT 8103 - Portfolio 2: Query Processing and Optimisation (Ace Bank)
-- queries.sql : five realistic banking queries and their results
--
-- Run:  psql -d bankdb -f queries.sql
-- =====================================================================

\timing on

-- ---------------------------------------------------------------------
-- Q1. Account statement: the 20 most recent transactions for one account
-- ---------------------------------------------------------------------
SELECT txn_id, txn_type, amount, balance_after, status, created_at
FROM bank_transaction
WHERE account_id = 1000000500
ORDER BY created_at DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q2. Top 10 customers by total balance across all their accounts
--     (JOIN + GROUP BY + ORDER BY)
-- ---------------------------------------------------------------------
SELECT c.customer_id, c.first_name, c.last_name,
       COUNT(a.account_id) AS num_accounts,
       SUM(a.balance)      AS total_balance
FROM customer c
JOIN account a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name
ORDER BY total_balance DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q3. Monthly transaction totals by type for successful transactions
--     (aggregation over the whole ledger)
-- ---------------------------------------------------------------------
SELECT date_trunc('month', created_at) AS month,
       txn_type,
       COUNT(*)    AS num_transactions,
       SUM(amount) AS total_amount
FROM bank_transaction
WHERE status = 'SUCCESS'
GROUP BY date_trunc('month', created_at), txn_type
ORDER BY month, txn_type;

-- ---------------------------------------------------------------------
-- Q4. Audit: ACTIVE accounts that are below their account type's minimum
--     balance (JOIN across account, account_type and customer)
-- ---------------------------------------------------------------------
SELECT a.account_id, c.first_name, c.last_name,
       t.type_name, t.min_balance, a.balance
FROM account a
JOIN account_type t ON t.type_id = a.type_id
JOIN customer c     ON c.customer_id = a.customer_id
WHERE a.status = 'ACTIVE'
  AND a.balance < t.min_balance
ORDER BY a.balance
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q5. Branch summary: number of accounts and total deposits per branch
-- ---------------------------------------------------------------------
SELECT b.branch_name, b.city,
       COUNT(a.account_id) AS num_accounts,
       SUM(a.balance)      AS total_balance
FROM branch b
LEFT JOIN account a ON a.branch_id = b.branch_id
GROUP BY b.branch_id, b.branch_name, b.city
ORDER BY total_balance DESC;
