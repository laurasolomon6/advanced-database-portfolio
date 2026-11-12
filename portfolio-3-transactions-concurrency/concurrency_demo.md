# Portfolio 3: Concurrency Demonstrations (Ace Bank)

These demos need **two Terminal windows** open side by side, both connected to the database:

```
psql -d bankdb
```

Call them **Session A** (left window) and **Session B** (right window). Run each line on its own, in the order shown. The order and the pauses matter, because the point is what happens when two people use the same account at the same time.

Accounts: **1000000001** is the account used in every demo. Reset it before each demo with this command (in either window):

```sql
UPDATE account SET balance = 100000 WHERE account_id = 1000000001;
```

Take a screenshot of both windows at the end of each demo.

---

## DEMO 1: The lost update problem

**Scenario:** Two tellers withdraw from the same account at the same moment. Both read the balance, calculate the new balance in their own program, then write it back. The balance should end at 50,000 (100,000 - 30,000 - 20,000).

| Step | Session A (withdraw 30,000) | Session B (withdraw 20,000) |
|---|---|---|
| 0 | Reset the balance (command above) | |
| 1 | `BEGIN;` | `BEGIN;` |
| 2 | `SELECT balance FROM account WHERE account_id = 1000000001;` (sees 100000) | `SELECT balance FROM account WHERE account_id = 1000000001;` (also sees 100000) |
| 3 | `UPDATE account SET balance = 70000 WHERE account_id = 1000000001;` | |
| 4 | `COMMIT;` | |
| 5 | | `UPDATE account SET balance = 80000 WHERE account_id = 1000000001;` |
| 6 | | `COMMIT;` |
| 7 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |

**Result:** the balance is **80000**, not 50000. Session A's 30,000 withdrawal was overwritten and lost. Both sessions calculated their new balance from the same old number (100,000) because neither knew about the other.

---

## DEMO 2: Fixing it with a row lock (SELECT ... FOR UPDATE)

Reset the balance to 100000 first.

| Step | Session A (withdraw 30,000) | Session B (withdraw 20,000) |
|---|---|---|
| 1 | `BEGIN;` | |
| 2 | `SELECT balance FROM account WHERE account_id = 1000000001 FOR UPDATE;` (sees 100000, locks the row) | |
| 3 | | `BEGIN;` |
| 4 | | `SELECT balance FROM account WHERE account_id = 1000000001 FOR UPDATE;` **This hangs and waits.** Take a screenshot of it waiting. |
| 5 | `UPDATE account SET balance = 70000 WHERE account_id = 1000000001;` | |
| 6 | `COMMIT;` | Session B now wakes up and shows **70000** |
| 7 | | `UPDATE account SET balance = 50000 WHERE account_id = 1000000001;` |
| 8 | | `COMMIT;` |
| 9 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |

**Result:** the balance is **50000**, which is correct. Session B had to wait for Session A to finish, and then it read the up-to-date balance. This is **pessimistic locking**, and it's what my `transfer_funds()` function does internally.

A simpler fix is to avoid calculating in the application at all: `UPDATE account SET balance = balance - 30000 WHERE ...` is a single atomic step, so the database always starts from the current balance.

---

## DEMO 3: Isolation levels. Non-repeatable read vs REPEATABLE READ

### 3a. READ COMMITTED (PostgreSQL's default)

Reset the balance to 100000 first.

| Step | Session A | Session B |
|---|---|---|
| 1 | `BEGIN ISOLATION LEVEL READ COMMITTED;` | |
| 2 | `SELECT balance FROM account WHERE account_id = 1000000001;` (100000) | |
| 3 | | `UPDATE account SET balance = balance - 10000 WHERE account_id = 1000000001;` (commits automatically) |
| 4 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |
| 5 | `COMMIT;` | |

**Result:** in step 4, Session A sees **90000**. The same query gave a different answer inside one transaction. This is a **non-repeatable read**.

### 3b. REPEATABLE READ

Reset the balance to 100000 first.

| Step | Session A | Session B |
|---|---|---|
| 1 | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | |
| 2 | `SELECT balance FROM account WHERE account_id = 1000000001;` (100000) | |
| 3 | | `UPDATE account SET balance = balance - 10000 WHERE account_id = 1000000001;` |
| 4 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |
| 5 | `COMMIT;` | |
| 6 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |

**Result:** in step 4, Session A still sees **100000**, because it works from a snapshot taken at the start of its transaction. After the COMMIT in step 5, step 6 shows the real balance, **90000**.

---

## DEMO 4: REPEATABLE READ stops a conflicting write

Reset the balance to 100000 first.

| Step | Session A | Session B |
|---|---|---|
| 1 | `BEGIN ISOLATION LEVEL REPEATABLE READ;` | |
| 2 | `SELECT balance FROM account WHERE account_id = 1000000001;` | |
| 3 | | `UPDATE account SET balance = balance - 10000 WHERE account_id = 1000000001;` |
| 4 | `UPDATE account SET balance = balance - 30000 WHERE account_id = 1000000001;` | |
| 5 | `ROLLBACK;` | |

**Result:** step 4 fails with `ERROR: could not serialize access due to concurrent update`. PostgreSQL refuses to let Session A overwrite a row that changed after its snapshot. The application must then roll back and retry. This protects the account but means the application needs retry logic.

---

## Finish

Run the audit check and reset the demo account:

```sql
UPDATE account SET balance = 100000 WHERE account_id = 1000000001;
SELECT account_id, balance FROM account WHERE account_id IN (1000000001, 1000000002);
```

Type `\q` in both windows to leave psql.
