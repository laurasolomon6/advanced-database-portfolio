# Portfolio 3: Transactions and Concurrency (Ace Bank)

## Overview
This portfolio shows how PostgreSQL keeps Ace Bank's money safe when transfers succeed, fail, or happen at the same time. I used two test accounts with known balances (Account A = 1000000001 with 100,000 and Account B = 1000000002 with 50,000), so the total money (150,000) could be checked at every step.

## Files
| File | Purpose |
|---|---|
| 01_setup.sql | Resets the two test accounts and creates the transfer_funds() function |
| 02_commit_rollback.sql | Demonstrates COMMIT, ROLLBACK, a constraint failure, a successful transfer and a refused transfer |
| concurrency_demo.md | Step-by-step two-window demos (I ran Demo 1 and Demo 2) |
| Screenshots (.png) | Evidence of each demo running |

## How I ran it
1. `psql -d bankdb -f 01_setup.sql` to reset the balances and create the function.
2. `psql -d bankdb -f 02_commit_rollback.sql` for the commit and rollback demos.
3. For the concurrency demos I opened two Terminal windows, each connected with `psql -d bankdb`, and followed the steps in concurrency_demo.md, running each line in the order shown.

## Part 1: Commit and rollback
- **COMMIT (Demo 1):** I moved 10,000 from A to B inside a transaction. After COMMIT the balances were A = 90,000 and B = 60,000, and the change stayed saved.
- **ROLLBACK (Demo 2):** I moved 20,000 inside a transaction, and the balances changed to 70,000 and 80,000. After ROLLBACK they went back to 90,000 and 60,000, so both updates were undone together.
- **Constraint failure (Demo 3):** I tried to take more money out of A than it had. The CHECK constraint chk_account_balance rejected it, and PostgreSQL then refused further commands until I ran ROLLBACK. The +5,000 I had added to B earlier in the same transaction was also undone, and B stayed at 60,000.
- **Why it matters:** a transfer is two updates (debit one account, credit another). It must never be half done, or money would disappear or appear from nowhere. Transactions make the two updates succeed or fail as one unit (atomicity).
## Part 2: The transfer_funds() function
The function checks the inputs, locks both accounts in id order, refuses the transfer if the balance is too low, moves the money, and writes two linked ledger rows and a transfer record. If any step fails, the whole call is rolled back.
- **Success (Demo 4):** I transferred 5,000 from A to B. The balances became A = 85,000 and B = 65,000, and the transfer table linked the debit and credit rows.
- **Failure (Demo 5):** B tried to send 9,999,999 with only 65,000. The function raised "Insufficient funds". The balances and the number of transfers did not change.
- **Audit (Demo 6):** the total in the two accounts was 150,000.00, so no money was created or lost.

## Part 3: Concurrency
| Demo | What happened | Final balance | Expected |
|---|---|---|---|
| 1. Lost update (no lock) | Two tellers both read 100,000. Teller 1 wrote 70,000 and committed. Teller 2 then wrote 80,000 and committed. | 80,000 | 50,000 |
| 2. Fix with SELECT ... FOR UPDATE | Teller 1 locked the row. Teller 2's SELECT waited until Teller 1 committed, then read 70,000 and wrote 50,000. | 50,000 | 50,000 |

**Analysis**
In Demo 1 a withdrawal was lost. Both tellers read the same starting balance (100,000) and each calculated a new balance in their own session, so the second write overwrote the first. This is called a lost update, and for a bank it is serious because the customer's account would be wrong. In Demo 2, SELECT ... FOR UPDATE locked the account row. The second teller had to wait until the first had committed, and then read the up-to-date balance of 70,000, so the final balance was correct. The cost of a lock is that the second user has to wait, which could slow things down if many people use the same account. The transfer_funds() function uses the same locking idea, and it locks both accounts in id order so that two transfers in opposite directions cannot block each other forever (a deadlock).

## Challenges and lessons learned
I ran the commit and rollback script the second time without restting the balances because i was trying to take screenshots and then the numbers didn't add up, i had to work out why by restarting and opening two new terminals with new scripts.
Both tellers satrted with a balance of 100,000 but ended up with a balance of 80000 so for teller 1, the withdrawal was 30000 and for teller 2, the withdrawal was 20000. teller 1 withdrawal got lost so teller 2 worked with old balance of 100000 instead of 70000, so that was what i fixed by opening two new terminals and the balance became 50000 as it should have been.

## References
- PostgreSQL documentation: Transaction Isolation, and Explicit Locking. https://www.postgresql.org/docs/current/mvcc.html
I used claude to generate scripts to fix the balance error on this portfolio
