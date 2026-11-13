# Portfolio 4: MongoDB Queries (Ace Bank)

Database: `acebank` Collections: `customers` (5 documents), `transactions` (12 documents)

## How to run these in MongoDB Atlas
- **Filter queries:** open your cluster, click **Browse Collections**, choose the collection, paste the filter into the **Filter** box and click **Apply** (or Find).
- **Aggregation queries:** open the collection, click the **Aggregation** tab, then **Add Stage**, choose the stage name (for example `$match`), and paste the stage's body. For the full pipeline, use the **text view** option (the `{}` or "Text" toggle) and paste the whole array.

Take a screenshot of each query and its result.

---

## Part A: Find queries

**Q1. Customers living in Lagos** (collection: customers)
```json
{ "city": "Lagos" }
```
Expected: Chidi Okafor and Ngozi Adeyemi.

**Q2. Customers who have a Savings account** (collection: customers)
```json
{ "accounts.type": "Savings" }
```
Expected: 4 customers. This searches inside the embedded `accounts` array without a join.

**Q3. Customers with a loan** (collection: customers)
```json
{ "loans": { "$exists": true } }
```
Expected: only Amaka Eze. Only some customers have this field, because the document model does not force every document to have the same fields.

**Q4. All failed transactions** (collection: transactions)
```json
{ "status": "FAILED" }
```
Expected: TXN-0005 and TXN-0010, each with a `failure_reason`.

**Q5. Mobile transactions from Android devices** (collection: transactions)
```json
{ "channel": "MOBILE", "device.os": "Android" }
```
Expected: TXN-0003, TXN-0004 and TXN-0011. The `device` details only exist on mobile transactions.

---

## Part B: Aggregation pipelines

**Q6. Total and count of successful transactions per type** (collection: transactions)
```json
[
  { "$match": { "status": "SUCCESS" } },
  { "$group": { "_id": "$type", "total_amount": { "$sum": "$amount" }, "count": { "$sum": 1 } } },
  { "$sort": { "total_amount": -1 } }
]
```
Expected: DEPOSIT first with a total of 825,000 across 3 transactions.

**Q7. Total successful amount per channel** (collection: transactions)
```json
[
  { "$match": { "status": "SUCCESS" } },
  { "$group": { "_id": "$channel", "total_amount": { "$sum": "$amount" }, "count": { "$sum": 1 } } },
  { "$sort": { "total_amount": -1 } }
]
```

**Q8. Total balance per customer across their embedded accounts** (collection: customers)
```json
[
  { "$project": { "first_name": 1, "last_name": 1, "total_balance": { "$sum": "$accounts.balance" } } },
  { "$sort": { "total_balance": -1 } }
]
```
Expected: Ibrahim Bello first with 7,300,000. This is the MongoDB version of the relational "top customers by total balance" query from Portfolio 2, and it needs no join.

---

## Part C: Index and explain plan

1. In the `transactions` collection, open the **Indexes** tab and click **Create Index**.
2. Use the fields `{ "account_id": 1, "created_at": -1 }` and create it.
3. Go to the **Explain Plan** tab, enter the filter `{ "account_id": 1000000001 }`, and click Explain.
4. Check that the plan uses the index (`IXSCAN`) and not a full collection scan (`COLLSCAN`). Screenshot the result.

With only 12 documents the speed difference is tiny, so the point is to show that the index is used.
