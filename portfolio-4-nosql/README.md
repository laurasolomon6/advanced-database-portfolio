Portfolio 4: NoSQL and Advanced Data Models (Ace Bank)
Overview
This portfolio models part of the Ace Bank database as a document database using MongoDB, hosted on MongoDB Atlas (free tier). It uses the same bank as Portfolios 1 to 3. PostgreSQL stays the system of record for money movement, and MongoDB is used where flexible, nested or high-volume data fits better.

Files
File	Purpose
customers.json	5 customer documents with embedded accounts, cards and preferences
transactions.json	12 transaction documents with channel-specific fields
queries.md	The find queries and aggregation pipelines I ran
Screenshots (.png)	Evidence from Atlas
The data model
Type used: document database (MongoDB).

customers collection: one document per customer. Their accounts, cards and preferences are embedded inside the document, so a customer profile can be read in one lookup, with no joins. Different customers can have different fields: only some have loans, and only business customers have business_profile.

transactions collection: one document per transaction, with the account, amount, status and time. Extra fields depend on the channel: ATM transactions store the ATM id and location, mobile transactions store device details (OS, app version, IP), and POS transactions store merchant details.

Relational vs document (Ace Bank)

Relational (Portfolio 1)	Document (this portfolio)
customer, account and card tables joined by keys	one customer document with embedded accounts and cards
same columns for every transaction (many NULLs for channel details)	each transaction stores only the fields that apply to it
fixed schema, changed with ALTER TABLE	flexible schema, new fields can be added to new documents
How I implemented it
Created a free MongoDB Atlas account and a free cluster.
Created a database user and added my IP address to the access list.
Created the database acebank with the collections customers and transactions.
Inserted the documents from the two JSON files using Insert Document in Browse Collections.
Ran the queries in queries.md (filter queries and an aggregation pipeline) and took screenshots.
Results
Customers in Lagos: 2 customers (Chidi Okafor and Ngozi Adeyemi).
Customers with a Savings account: 4 customers. This searched inside the embedded accounts array with no join.
Customers with a loan: 1 customer (Amaka Eze). Only some documents have a loans field.
Failed transactions: 2 (TXN-0005 and TXN-0010), each with a failure_reason.
Android mobile transactions: 3. The device field exists only on mobile transactions.
Aggregation: grouping successful transactions by type, DEPOSIT had the largest total, 825,000 across 3 transactions.
Why a document database suits this part of the bank
Flexible structure: transactions from ATMs, mobile apps and POS terminals carry different details. Each MongoDB document keeps only the fields it needs, instead of many empty columns.
Fast profile reads: a customer's accounts, cards and preferences are in one document, so an app screen can load with a single query.
Easy to scale out: documents can be split across servers (sharding) by a key such as customer or account, which helps with very large transaction logs.
Where it is not suitable
Money movement: transfers need strict consistency and multi-step transactions (Portfolio 3). PostgreSQL's constraints and locking are better for this, so balances and transfers should stay in the relational database.
Duplicated data: account balances copied into the customer document can go out of date if they are not kept in sync with the relational database.
Complex joins and reporting: queries combining many tables are easier in SQL.
Money type: my sample data stores amounts as ordinary numbers. A real system should use MongoDB's Decimal128 type to avoid rounding errors.
Challenges and lessons learned
I had issues with Atlas asking for payment at first, but i was able to find a way around it. 
I had a connection failure and the add stage on the aggregation screen was difficult to locate but i was able to figure that out.

References
MongoDB Atlas documentation: Deploy a Free Cluster. https://www.mongodb.com/docs/atlas/tutorial/deploy-free-tier-cluster
MongoDB Manual: Data Modeling, and Aggregation. https://www.mongodb.com/docs/manual/
