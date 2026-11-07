-- =====================================================================
-- MIT 8103 Advanced Database Systems - Portfolio 1
-- Case study: Simulated retail bank (core banking database)
-- DBMS: PostgreSQL 15+
-- Run with:  psql -U postgres -d bankdb -f schema.sql
-- =====================================================================

DROP TABLE IF EXISTS audit_log, loan_repayment, loan, card, transfer,
                     bank_transaction, account, account_type, customer, branch CASCADE;

-- ---------------------------------------------------------------------
-- BRANCH
-- ---------------------------------------------------------------------
CREATE TABLE branch (
    branch_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_name  VARCHAR(100) NOT NULL UNIQUE,
    city         VARCHAR(80)  NOT NULL,
    address      VARCHAR(200)
);

-- ---------------------------------------------------------------------
-- CUSTOMER
-- ---------------------------------------------------------------------
CREATE TABLE customer (
    customer_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(60)  NOT NULL,
    last_name     VARCHAR(60)  NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    phone         VARCHAR(20)  NOT NULL UNIQUE,
    national_id   VARCHAR(20)  NOT NULL UNIQUE,          -- e.g. BVN / NIN
    date_of_birth DATE         NOT NULL,
    address       VARCHAR(200),
    date_joined   DATE         NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT chk_customer_adult CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years'),
    CONSTRAINT chk_customer_email CHECK (email LIKE '%_@_%.__%')
);

-- ---------------------------------------------------------------------
-- ACCOUNT_TYPE (lookup: removes repeated interest/min balance data)
-- ---------------------------------------------------------------------
CREATE TABLE account_type (
    type_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name     VARCHAR(30)   NOT NULL UNIQUE,         -- Savings, Current, Fixed Deposit
    interest_rate NUMERIC(5,2)  NOT NULL DEFAULT 0 CHECK (interest_rate >= 0),
    min_balance   NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (min_balance >= 0)
);

-- ---------------------------------------------------------------------
-- ACCOUNT
-- ---------------------------------------------------------------------
CREATE TABLE account (
    account_id     BIGINT GENERATED ALWAYS AS IDENTITY (START WITH 1000000001) PRIMARY KEY,
    customer_id    INT           NOT NULL REFERENCES customer(customer_id)     ON DELETE RESTRICT,
    type_id        INT           NOT NULL REFERENCES account_type(type_id)     ON DELETE RESTRICT,
    branch_id      INT           NOT NULL REFERENCES branch(branch_id)         ON DELETE RESTRICT,
    balance        NUMERIC(15,2) NOT NULL DEFAULT 0,
    currency       CHAR(3)       NOT NULL DEFAULT 'NGN',
    status         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE',
    opened_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT chk_account_balance CHECK (balance >= 0),
    CONSTRAINT chk_account_status  CHECK (status IN ('ACTIVE','DORMANT','FROZEN','CLOSED'))
);

-- ---------------------------------------------------------------------
-- BANK_TRANSACTION (ledger of every money movement)
-- ---------------------------------------------------------------------
CREATE TABLE bank_transaction (
    txn_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id    BIGINT        NOT NULL REFERENCES account(account_id) ON DELETE RESTRICT,
    txn_type      VARCHAR(20)   NOT NULL,
    amount        NUMERIC(15,2) NOT NULL,
    balance_after NUMERIC(15,2) NOT NULL,
    status        VARCHAR(10)   NOT NULL DEFAULT 'SUCCESS',
    reference     VARCHAR(40)   NOT NULL UNIQUE,
    narration     VARCHAR(200),
    created_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_txn_amount CHECK (amount > 0),
    CONSTRAINT chk_txn_type   CHECK (txn_type IN
        ('DEPOSIT','WITHDRAWAL','TRANSFER_DEBIT','TRANSFER_CREDIT','FEE','INTEREST','REVERSAL')),
    CONSTRAINT chk_txn_status CHECK (status IN ('PENDING','SUCCESS','FAILED','REVERSED'))
);

-- ---------------------------------------------------------------------
-- TRANSFER (pairs the debit and credit legs of one transfer)
-- ---------------------------------------------------------------------
CREATE TABLE transfer (
    transfer_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    from_account_id BIGINT        NOT NULL REFERENCES account(account_id),
    to_account_id   BIGINT        NOT NULL REFERENCES account(account_id),
    amount          NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    debit_txn_id    BIGINT        UNIQUE REFERENCES bank_transaction(txn_id),
    credit_txn_id   BIGINT        UNIQUE REFERENCES bank_transaction(txn_id),
    status          VARCHAR(10)   NOT NULL DEFAULT 'PENDING',
    initiated_at    TIMESTAMP     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_transfer_diff   CHECK (from_account_id <> to_account_id),
    CONSTRAINT chk_transfer_status CHECK (status IN ('PENDING','COMPLETED','FAILED','REVERSED'))
);

-- ---------------------------------------------------------------------
-- CARD
-- ---------------------------------------------------------------------
CREATE TABLE card (
    card_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id   BIGINT      NOT NULL REFERENCES account(account_id) ON DELETE CASCADE,
    card_number  CHAR(16)    NOT NULL UNIQUE,     -- store tokenised/masked value in real systems
    card_type    VARCHAR(10) NOT NULL CHECK (card_type IN ('DEBIT','CREDIT','PREPAID')),
    expiry_date  DATE        NOT NULL,
    status       VARCHAR(10) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','BLOCKED','EXPIRED')),
    CONSTRAINT chk_card_expiry CHECK (expiry_date > CURRENT_DATE - INTERVAL '10 years')
);

-- ---------------------------------------------------------------------
-- LOAN and LOAN_REPAYMENT
-- ---------------------------------------------------------------------
CREATE TABLE loan (
    loan_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    INT           NOT NULL REFERENCES customer(customer_id),
    account_id     BIGINT        NOT NULL REFERENCES account(account_id),  -- disbursement account
    principal      NUMERIC(15,2) NOT NULL CHECK (principal > 0),
    interest_rate  NUMERIC(5,2)  NOT NULL CHECK (interest_rate >= 0),
    term_months    INT           NOT NULL CHECK (term_months BETWEEN 1 AND 360),
    start_date     DATE          NOT NULL DEFAULT CURRENT_DATE,
    status         VARCHAR(10)   NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING','ACTIVE','PAID','DEFAULTED'))
);

CREATE TABLE loan_repayment (
    repayment_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id       INT           NOT NULL REFERENCES loan(loan_id) ON DELETE CASCADE,
    amount_paid   NUMERIC(15,2) NOT NULL CHECK (amount_paid > 0),
    paid_at       TIMESTAMP     NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- AUDIT_LOG (compliance trail)
-- ---------------------------------------------------------------------
CREATE TABLE audit_log (
    audit_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR(40) NOT NULL,
    record_id   VARCHAR(40) NOT NULL,
    action      VARCHAR(10) NOT NULL CHECK (action IN ('INSERT','UPDATE','DELETE')),
    changed_by  VARCHAR(60) NOT NULL DEFAULT CURRENT_USER,
    changed_at  TIMESTAMP   NOT NULL DEFAULT NOW(),
    details     JSONB
);

-- ---------------------------------------------------------------------
-- Baseline indexes on foreign keys (PostgreSQL does not create these
-- automatically). Further tuning is done in Portfolio 2.
-- ---------------------------------------------------------------------
CREATE INDEX idx_account_customer ON account(customer_id);
CREATE INDEX idx_account_branch   ON account(branch_id);
CREATE INDEX idx_txn_account      ON bank_transaction(account_id);
CREATE INDEX idx_card_account     ON card(account_id);
CREATE INDEX idx_loan_customer    ON loan(customer_id);
CREATE INDEX idx_repay_loan       ON loan_repayment(loan_id);

-- ---------------------------------------------------------------------
-- Minimal seed data to confirm the schema works
-- ---------------------------------------------------------------------
INSERT INTO branch (branch_name, city) VALUES ('Ikeja Main', 'Lagos'), ('Wuse II', 'Abuja');
INSERT INTO account_type (type_name, interest_rate, min_balance)
VALUES ('Savings', 3.50, 1000), ('Current', 0.00, 5000), ('Fixed Deposit', 9.00, 100000);
