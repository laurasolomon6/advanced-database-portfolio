 # Portfolio 2: Query Processing and Optimisation (Ace Bank)

## Overview
This portfolio tests how fast common Ace Bank queries run on a realistic amount of data, and how indexes improve them. I generated 20,000 customers, 30,000 accounts and 300,000 transactions in PostgreSQL 18, ran five banking queries, and compared execution plans before and after adding indexes.

## Files
| File | Purpose |
|---|---|
| generate_data.sql | Fills the database with simulated data using generate_series |
| queries.sql | Five banking queries (statement, top customers, monthly totals, balance audit, branch summary) |
| optimisation.sql | Four before/after index experiments using EXPLAIN (ANALYZE, BUFFERS) |
| Screenshots (.png) | Evidence of the scripts running and of each execution plan |

## How I ran it
1. `psql -d bankdb -f generate_data.sql` (loads the data and prints row counts)
2. `psql -d bankdb -f queries.sql` (runs the five queries)
3. `psql -d bankdb -f optimisation.sql | tee results/optimisation_output.txt` (runs the experiments and saves the output)
4. Inside psql, I ran EXPLAIN ANALYZE on Q2, Q3 and Q5 to study their plans.

## Index experiments

| Experiment | Index created | Plan before | Time before (ms) | Plan after | Time after (ms) |
|---|---|---|---|---|---|
| 1. Date range (last 7 days) | idx_txn_created_at | Parallel Seq Scan | 63.093 | Bitmap Index Scan + Bitmap Heap Scan | 5.179 |
| 2. Account statement | idx_txn_account_created (account_id, created_at DESC) | Bitmap Index Scan on idx_txn_account + Sort | 0.136 | Bitmap Index Scan on the new index + Sort | 0.114 |
| 3. Customer name search | idx_customer_name (last_name, first_name) | Seq Scan | 1.904 | Bitmap Index Scan + Bitmap Heap Scan | 0.136 |
| 4. Failed transactions | idx_txn_failed_created (partial, WHERE status = 'FAILED') | Parallel Seq Scan + Sort | 35.962 | Bitmap Index Scan + Sort | 1.384 |

Index sizes: partial index 216 kB vs full index on created_at 6600 kB. The bank_transaction table is 39 MB.

## Performance analysis
Indexes made three of the four queries much faster. The date-range query improved from 63 ms to 5 ms (about 12 times faster) because PostgreSQL stopped reading all 300,000 rows and used a bitmap index scan to read only the matching ones. The customer name search improved from 1.9 ms to 0.14 ms. The biggest gain was Experiment 4, where the partial index cut the time from 36 ms to 1.4 ms. It was also about 30 times smaller than a full index on the same column (216 kB vs 6600 kB), because it only stores the roughly 3% of rows with status FAILED.

Experiment 2 did not improve in a meaningful way (0.136 ms vs 0.114 ms) and the plan still contains a Sort. Each account has only about 10 transactions on average, so sorting 10 rows is almost free, and the new composite index cost 9264 kB of storage for almost no gain. A composite index like this would matter more for a busy business account with thousands of transactions. This shows that an index is only worth adding when a query returns enough rows for it to matter.

The cost of indexes is that every insert and update must also update each index, and indexes use storage. In a busy banking system, where transactions are written constantly, only the indexes that match frequent queries should be kept.

All queries ran with data already in memory (every plan shows shared hit), so on slower disks the differences would probably be larger. The dataset is also small compared with a real bank.

## Observations on the other queries
Q2, Q3 and Q5 aggregate whole tables, so indexes do not help them.

- **Q2 (top customers, 67.9 ms):** scans all 30,000 accounts and 20,000 customers, joins them with a Hash Join, and groups them with a HashAggregate. The aggregate spilled about 208 kB to disk, and the final sort used a top-N heapsort, which keeps only 10 rows because of the LIMIT.
- **Q3 (monthly totals, 431 ms):** the slowest query. It reads about 291,000 of the 300,000 transaction rows, so an index would not help. The Sort spilled about 10.7 MB to disk (external merge). A summary table or materialized view would be a better fix for a report like this.
- **Q5 (branch summary, 26 ms):** scans all accounts and hashes the 10-row branch table. The existing index on account.branch_id was not used, because reading all 30,000 rows in order is cheaper. Nothing spilled to disk.

## Challenges and lessons learned
I think this was the hardest, when I tried to run my SQL scripts, Terminal kept saying “no such file or directory” because I was in the wrong folder. I fixed it by dragging my project folder into Terminal after typing cd, then using ls to confirm the files were there before running psql. I learned to check where I am with pwd and ls before running a command, because most of my early errors came from a wrong folder or a small typo, such as a stray full stop in mkdir -p results.
Also, Experiment 2 didn’t speed up as I expected, because each account only has about 10 transactions, so sorting them costs almost nothing.

## References
Claude ai was used to genrate sample data sets but i ran all the scripts and planning my self.
- PostgreSQL documentation: Using EXPLAIN, and Indexes. https://www.postgresql.org/docs/current/
