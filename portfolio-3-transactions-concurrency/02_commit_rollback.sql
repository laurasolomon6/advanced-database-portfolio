-- =====================================================================
-- MIT 8103 - Portfolio 3: Transactions and Concurrency (Ace Bank)
-- 02_commit_rollback.sql : atomicity, commit, rollback, constraints
--
-- Run:  psql -d bankdb -f 01_setup.sql          (first, to reset balances)
--       psql -d bankdb -f 02_commit_rollback.sql
--
-- Account A = 1000000001 (starts 100,000)   Account B = 1000000002 (starts 50,000)
-- Total money must always stay at 150,000.00
-- Some statements below FAIL ON PURPOSE. Those errors are the demo.
-- =====================================================================

-- ---------------------------------------------------------------------
-- DEMO 1: COMMIT. A transfer made of two updates saved as one unit
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 1: explicit transaction ending in COMMIT (move 10,000 from A to B) ==='
BEGIN;
UPDATE account SET balance = balance - 10000 WHERE account_id = 1000000001;
UPDATE account SET balance = balance + 10000 WHERE account_id = 1000000002;
\echo '--- inside the transaction, before COMMIT ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;
COMMIT;
\echo '--- after COMMIT: expected A = 90000.00, B = 60000.00 ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;

-- ---------------------------------------------------------------------
-- DEMO 2: ROLLBACK. The same changes are undone
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 2: transaction ending in ROLLBACK (try to move 20,000 from A to B) ==='
BEGIN;
UPDATE account SET balance = balance - 20000 WHERE account_id = 1000000001;
UPDATE account SET balance = balance + 20000 WHERE account_id = 1000000002;
\echo '--- inside the transaction: balances have changed ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;
ROLLBACK;
\echo '--- after ROLLBACK: expected A = 90000.00, B = 60000.00 again ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;

-- ---------------------------------------------------------------------
-- DEMO 3: A constraint failure forces the transaction to be abandoned
--         (the CHECK constraint chk_account_balance forbids negative balances)
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 3: overdraw attempt fails; transaction must be rolled back ==='
BEGIN;
UPDATE account SET balance = balance + 5000 WHERE account_id = 1000000002;   -- this part works
UPDATE account SET balance = balance - 999999 WHERE account_id = 1000000001; -- this breaks the CHECK constraint
\echo '--- the next command is rejected because the transaction is now in an aborted state ---'
SELECT balance FROM account WHERE account_id = 1000000002;
ROLLBACK;
\echo '--- after ROLLBACK: the +5000 on B was also undone (B should still be 60000.00) ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;

-- ---------------------------------------------------------------------
-- DEMO 4: The safe transfer function, SUCCESS case
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 4: transfer_funds() success (5,000 from A to B) ==='
SELECT transfer_funds(1000000001, 1000000002, 5000) AS transfer_id;
\echo '--- expected A = 85000.00, B = 65000.00 ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;
\echo '--- the transfer left a linked pair of ledger rows ---'
SELECT t.transfer_id, t.from_account_id, t.to_account_id, t.amount, t.status,
       d.txn_type AS debit_type, d.balance_after AS debit_balance_after,
       c.txn_type AS credit_type, c.balance_after AS credit_balance_after
FROM transfer t
JOIN bank_transaction d ON d.txn_id = t.debit_txn_id
JOIN bank_transaction c ON c.txn_id = t.credit_txn_id
ORDER BY t.transfer_id DESC
LIMIT 1;

-- ---------------------------------------------------------------------
-- DEMO 5: The safe transfer function, FAILURE case (insufficient funds)
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 5: transfer_funds() fails (B tries to send 9,999,999 but has 65,000) ==='
SELECT COUNT(*) AS transfers_before FROM transfer;
SELECT transfer_funds(1000000002, 1000000001, 9999999);
\echo '--- the error above is expected. Nothing should have changed: ---'
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;
SELECT COUNT(*) AS transfers_after FROM transfer;

-- ---------------------------------------------------------------------
-- DEMO 6: Audit check. No money was created or destroyed
-- ---------------------------------------------------------------------
\echo
\echo '=== DEMO 6: audit check (total must equal 150000.00) ==='
SELECT SUM(balance) AS total_money
FROM account WHERE account_id IN (1000000001, 1000000002);
