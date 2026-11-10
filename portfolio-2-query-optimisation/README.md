Experiment	Plan before	Time before	Plan after	Time after
1. Date range (last 7 days)	Parallel Seq Scan	63.093 ms	Bitmap Index Scan, then Bitmap Heap Scan	5.179 ms
2. Account statement	Bitmap Index Scan (idx_txn_account) + Sort	0.136 ms	Bitmap Index Scan (idx_txn_account_created) + Sort	0.114 ms
3. Customer name search	Seq Scan	1.904 ms	Bitmap Index Scan, then Bitmap Heap Scan	0.136 ms
4. Failed transactions	Parallel Seq Scan + Sort	35.962 ms	Bitmap Index Scan (partial index) + Sort	1.384 ms

Index sizes: the partial index is 216 kB and the full index on created_at is 6600 kB. The bank_transaction table is 39 MB.

What the numbers say

Experiment 1: about 12 times faster. The database stopped reading all 300,000 rows (about 4,981 buffers) and only read the matching ones (about 3,372).
Experiment 3: about 14 times faster, and the buffers dropped from 309 to 39.
Experiment 4: about 26 times faster. The partial index is roughly 30 times smaller than the full one, because it stores only the failed rows, about 3% of the table.
Experiment 2 came as a surprise: I predicted the Sort would disappear, and it didn’t. Both plans still have a Sort, and the time barely changed (0.136 ms vs 0.114 ms, which is within normal noise). The reason is that each account has only about 10 transactions (300,000 spread over 30,000 accounts), so sorting 10 rows costs almost nothing, and the planner didn’t see the new index as worth using for ordering. The new index also cost 9,264 kB for no real gain. 
Note: Indexes made three of the four queries much faster. The date-range query dropped from 63 ms to 5 ms because PostgreSQL switched from scanning all 300,000 rows to a bitmap index scan. The partial index for failed transactions gave the biggest gain (36 ms to 1.4 ms) and was about 30 times smaller than a full index, because it only stores the roughly 3% of rows with status FAILED. The composite index in Experiment 2 did not help. Each account has only about 10 transactions, so the Sort step was already trivial and the planner kept it. This shows that an index is only worth its storage and write cost when the query returns enough rows for it to matter. For a busy banking system, every extra index also slows inserts, so I would only keep indexes that match frequent queries. All the data was already in memory, so on slower disks, the gpas would be larger and this dataset is small compared to a real bank.
