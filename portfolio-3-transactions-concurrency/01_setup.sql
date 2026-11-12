-- =====================================================================
-- MIT 8103 - Portfolio 3: Transactions and Concurrency (Ace Bank)
-- 01_setup.sql : sets two test accounts to known balances and creates
--                a safe fund-transfer function.
--
-- Run:  psql -d bankdb -f 01_setup.sql
-- Safe to re-run. It resets the two test accounts each time.
--
-- Test accounts (created by generate_data.sql in Portfolio 2):
--   1000000001  starts with 100,000.00   ("Account A")
--   1000000002  starts with  50,000.00   ("Account B")
--   Total money in the two accounts is always 150,000.00
-- =====================================================================

-- 1. Reset the two test accounts to known values
UPDATE account SET balance = 100000.00, status = 'ACTIVE' WHERE account_id = 1000000001;
UPDATE account SET balance =  50000.00, status = 'ACTIVE' WHERE account_id = 1000000002;

-- 2. A reusable, safe transfer function
--    - checks the inputs
--    - locks BOTH accounts in id order (prevents deadlocks and lost updates)
--    - refuses the transfer if funds are insufficient
--    - debits, credits, writes the two ledger rows and the transfer row
--    If ANY step fails, PostgreSQL rolls back the whole function call,
--    so a transfer is all-or-nothing (atomic).
CREATE OR REPLACE FUNCTION transfer_funds(
    p_from   BIGINT,
    p_to     BIGINT,
    p_amount NUMERIC
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_bal    NUMERIC;
    v_to_bal      NUMERIC;
    v_from_status VARCHAR;
    v_to_status   VARCHAR;
    v_debit_id    BIGINT;
    v_credit_id   BIGINT;
    v_transfer_id BIGINT;
    v_ref         TEXT;
BEGIN
    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION 'Transfer amount must be positive';
    END IF;
    IF p_from = p_to THEN
        RAISE EXCEPTION 'Cannot transfer to the same account';
    END IF;

    -- Lock both rows, always in the same order (lowest account_id first)
    PERFORM 1 FROM account
    WHERE account_id IN (p_from, p_to)
    ORDER BY account_id
    FOR UPDATE;

    SELECT balance, status INTO v_from_bal, v_from_status
    FROM account WHERE account_id = p_from;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Source account % does not exist', p_from;
    END IF;

    SELECT balance, status INTO v_to_bal, v_to_status
    FROM account WHERE account_id = p_to;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Destination account % does not exist', p_to;
    END IF;

    IF v_from_status <> 'ACTIVE' OR v_to_status <> 'ACTIVE' THEN
        RAISE EXCEPTION 'Both accounts must be ACTIVE';
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION 'Insufficient funds: balance % is less than amount %',
                        v_from_bal, p_amount;
    END IF;

    -- Move the money
    UPDATE account SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE account SET balance = balance + p_amount WHERE account_id = p_to;

    -- Ledger rows (one per account) and the transfer record that links them
    v_ref := left(gen_random_uuid()::text, 12);

    INSERT INTO bank_transaction
        (account_id, txn_type, amount, balance_after, status, reference, narration)
    VALUES
        (p_from, 'TRANSFER_DEBIT', p_amount, v_from_bal - p_amount,
         'SUCCESS', 'TRF-D-' || v_ref, 'Transfer to ' || p_to)
    RETURNING txn_id INTO v_debit_id;

    INSERT INTO bank_transaction
        (account_id, txn_type, amount, balance_after, status, reference, narration)
    VALUES
        (p_to, 'TRANSFER_CREDIT', p_amount, v_to_bal + p_amount,
         'SUCCESS', 'TRF-C-' || v_ref, 'Transfer from ' || p_from)
    RETURNING txn_id INTO v_credit_id;

    INSERT INTO transfer
        (from_account_id, to_account_id, amount, debit_txn_id, credit_txn_id, status)
    VALUES
        (p_from, p_to, p_amount, v_debit_id, v_credit_id, 'COMPLETED')
    RETURNING transfer_id INTO v_transfer_id;

    RETURN v_transfer_id;
END;
$$;

-- 3. Show the starting state
\echo
\echo '=== Starting balances (should be 100000.00 and 50000.00) ==='
SELECT account_id, balance FROM account
WHERE account_id IN (1000000001, 1000000002) ORDER BY account_id;
