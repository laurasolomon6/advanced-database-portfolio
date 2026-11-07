# Portfolio 1: Normalisation Explanation

## Starting point: unnormalised design

A naive bank spreadsheet or single table might look like this:

```
BANK_RECORD(customer_name, customer_email, customer_phone,
            account_no, account_type, interest_rate, min_balance,
            branch_name, branch_city,
            txn_id, txn_type, txn_amount, txn_date,
            card_numbers[], loan_ids[])
```

**Problems (anomalies)**
- **Update anomaly:** a customer changes phone number, so every transaction row must be updated.
- **Insert anomaly:** a new branch or account type cannot be stored until an account uses it.
- **Delete anomaly:** deleting a customer's last transaction also deletes the only copy of the customer's details.
- **Redundancy:** interest rate and branch city repeat on thousands of rows.

## First Normal Form (1NF)

Rule: every column holds a single atomic value and there are no repeating groups.

- `card_numbers[]` and `loan_ids[]` are repeating groups. They are split out so each card and each loan is its own row (`CARD`, `LOAN`).
- Each row is identified by a primary key.

## Second Normal Form (2NF)

Rule: in 1NF, and no non-key attribute depends on only part of a composite key.

If a combined table is keyed on (account_no, txn_id), then `account_type`, `interest_rate`, and `branch_city` depend only on `account_no`, and `txn_type`, `txn_amount`, and `txn_date` depend on `txn_id`. These are partial dependencies.

Fix: separate into `ACCOUNT` (one row per account) and `BANK_TRANSACTION` (one row per movement, with `account_id` as a foreign key). Customer attributes move to `CUSTOMER`.

## Third Normal Form (3NF)

Rule: in 2NF, and no non-key attribute depends on another non-key attribute (no transitive dependencies).

| Transitive dependency | Fix |
|---|---|
| account_id → type_id → interest_rate, min_balance | `ACCOUNT_TYPE` lookup table |
| account_id → branch_id → branch_city | `BRANCH` table |
| account_id → customer_id → name, email, phone | `CUSTOMER` table |

After this, every non-key attribute depends on "the key, the whole key, and nothing but the key".

## BCNF check

Each table's determinants are candidate keys. For example, in `CUSTOMER`, `email`, `phone`, and `national_id` are all unique and each determines the rest of the row, so they are candidate keys. No table violates BCNF.

## Deliberate design decisions

1. **`balance_after` in `bank_transaction`** is a controlled denormalisation. The balance could be recomputed from the ledger, but storing it speeds up statements and makes audits easy. This is a documented trade-off, not an accident.
2. **`account.balance`** is also stored (rather than always summed) for fast lookups. It must always equal the latest `balance_after`, which Portfolio 3 enforces through transactions.
3. **`transfer` table** links the debit and credit legs, so a transfer is traceable and reversible.
4. **`NUMERIC(15,2)`** is used for money, never `FLOAT`, to avoid rounding errors.
5. **`ON DELETE RESTRICT`** on financial tables stops history being deleted by accident. Status values (`CLOSED`) are used instead of deleting accounts.

## Constraint summary

| Type | Examples |
|---|---|
| Primary keys | Identity columns on every table |
| Foreign keys | account→customer/branch/type, transaction→account, card→account, loan→customer, repayment→loan |
| UNIQUE | email, phone, national_id, card_number, txn reference, branch_name |
| CHECK | balance >= 0, amount > 0, status and type value lists, from_account <> to_account, customer age >= 18 |
| NOT NULL / DEFAULT | Core fields required; defaults for status, dates, currency |
