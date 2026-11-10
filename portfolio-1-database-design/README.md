# Portfolio 1: Database Design and Modelling (Ace Bank)

## Overview
This folder contains the database design for Ace Bank, a simulated retail bank. The database stores customers, accounts, transactions, transfers, cards, loans and audit records, and is built in PostgreSQL.

## Files
| File | Purpose |
|---|---|
| schema.sql | Creates all the tables, keys, constraints and indexes, and adds a small amount of seed data |
| er_diagram.mermaid | The ER diagram showing how the tables relate |
| normalisation.md | Explains how the design was normalised from an unnormalised table to 3NF |
| screenshot images (.png) | Evidence that the schema was run and tested |

## Design summary
The database has ten tables: customer, branch, account_type, account, bank_transaction, transfer, card, loan, loan_repayment and audit_log. One customer can own many accounts, and one account can have many transactions. Account types and branches are kept in their own tables so their details are stored once instead of being repeated on every account.

## Key design choices
- **NUMERIC for money:** I used NUMERIC(15,2) for amounts instead of FLOAT, because FLOAT can cause small rounding errors that are unacceptable with money.
- **Constraints:** CHECK constraints stop bad data, for example negative balances, zero or negative transaction amounts, and transfers from an account to itself.
- **ON DELETE RESTRICT:** Financial records cannot be deleted by accident. Accounts are marked CLOSED instead of being removed.
- **balance_after column:** I stored the balance after each transaction on purpose. It breaks strict normalisation, but it makes statements and audits faster. This trade-off is explained in normalisation.md.

## How I ran and tested it
1. Installed PostgreSQL using Postgres.app on macOS (PostgreSQL 18).
2. Created the database with `createdb bankdb`.
3. Ran the script with `psql -d bankdb -f schema.sql`.
4. Checked the results inside psql:
   - `\dt` lists all ten tables (screenshot: tables.png)
   - `\d account` shows the columns, keys and constraints (screenshot: account-structure.png and account structure.png)
   - `SELECT * FROM branch;` returns the two seed branches, Ikeja Main and Wuse II (screenshot: branch data.png)

## Challenges and what I learned
I had difficulty taking inputing a command, i learned that i have to press enter first before another line of command can work because i initially put in 2 diffrent commands on one line and it did not run.
i had trouble finding the file path in Terminal so i dragged and dropped it so it just appeared in full and i was able to continue, i think was the first issue i encountered but i was able to figure it out.
## References
- PostgreSQL documentation: https://www.postgresql.org/docs/
