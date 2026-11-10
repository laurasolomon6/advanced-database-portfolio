# Portfolio 2: Query Processing and Optimisation (Ace Bank)

## Overview
This portfolio tests how fast common Ace Bank queries run on a realistic amount of data, and how indexes improve them. I generated 20,000 customers, 30,000 accounts and 300,000 transactions in PostgreSQL, ran five banking queries, and compared execution plans before and after adding indexes.

## Files
| File | Purpose |
|---|---|
| generate_data.sql | Fills the database with simulated data using generate_series |
| queries.sql | Five banking queries (statement, top customers, monthly totals, balance audit, branch summary) |
| optimisation.sql | Four before/after index experiments using EXPLAIN (ANALYZE, BUFFERS) |
| results/ | Saved output and screenshots |

## How I ran it
1. `psql -d bankdb -f generate_data.sql` (loads the data; the last query prints row counts)
2. `psql -d bankdb -f queries.sql` (runs the five queries and shows results)
3. `psql -d bankdb -f optimisation.sql | tee results/optimisation_output.txt` (runs the experiments and saves the output)

## Results
Fill in the numbers from YOUR output. In each EXPLAIN ANALYZE result, look at the last lines: "Execution Time" is the time in milliseconds.

| Experiment | Index created | Plan before | Time before (ms) | Plan after | Time after (ms) |
|---|---|---|---|---|---|
| 1. Date range (last 7 days) | idx_txn_created_at | Seq Scan | ___ | ___ | ___ |
| 2. Account statement | idx_txn_account_created | ___ + Sort | ___ | ___ | ___ |
| 3. Customer name search | idx_customer_name | Seq Scan | ___ | ___ | ___ |
| 4. Failed transactions | idx_txn_failed_created (partial) | ___ | ___ | ___ | ___ |

Index sizes (from the output): partial index ___ vs full index ___; table size ___.

## Performance analysis
Write 4 to 6 sentences in your own words. These prompts can help:
- Which experiment showed the biggest improvement, and what changed in the plan (for example Seq Scan to Index Scan)?
- In Experiment 2, what happened to the Sort step, and why?
- Why is the partial index smaller than the full index, and when would you use one?
- Did any index NOT help, or help less than expected? Why might the planner choose a sequential scan even when an index exists?
- What is the cost of adding indexes? (Think about writes, storage and maintenance for a busy banking system.)

## Observations on the other queries
Q2 (top customers), Q3 (monthly totals) and Q5 (branch summary) read most of a table to calculate totals, so an index helps little there. Add a sentence or two of your own after looking at their execution plans (run `EXPLAIN ANALYZE` in front of them).

## Challenges and lessons learned
[2 or 3 honest sentences about what went wrong or surprised you, and what you learned.]

## References
- PostgreSQL documentation: Using EXPLAIN, and Indexes. https://www.postgresql.org/docs/current/
