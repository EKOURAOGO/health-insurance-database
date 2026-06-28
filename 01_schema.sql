-- ============================================================
-- Health Insurance Database — Schema
-- MySQL 8.0+ / MariaDB 10.5+
-- ============================================================

DROP DATABASE IF EXISTS health_insurance_db;
CREATE DATABASE health_insurance_db CHARACTER SET utf8mb4;
USE health_insurance_db;

-- ------------------------------------------------------------
-- policy_plans — catalogue of insurance plans offered
-- ------------------------------------------------------------
CREATE TABLE policy_plans (
    plan_id             INT PRIMARY KEY AUTO_INCREMENT,
    plan_name           VARCHAR(100) NOT NULL,
    monthly_premium     DECIMAL(8,2) NOT NULL,
    annual_reimbursement_cap DECIMAL(10,2) NOT NULL,
    deductible          DECIMAL(8,2) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- policyholders — the person who owns/pays for the contract
-- ------------------------------------------------------------
CREATE TABLE policyholders (
    policyholder_id     INT PRIMARY KEY AUTO_INCREMENT,
    full_name           VARCHAR(100) NOT NULL,
    birth_date          DATE NOT NULL,
    city                VARCHAR(80),
    email               VARCHAR(120)
);

-- ------------------------------------------------------------
-- policies — a contract linking a policyholder to a plan
-- ------------------------------------------------------------
CREATE TABLE policies (
    policy_id           INT PRIMARY KEY AUTO_INCREMENT,
    policyholder_id     INT NOT NULL,
    plan_id             INT NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE,                  -- NULL = still active
    status              VARCHAR(20) NOT NULL DEFAULT 'active',  -- active, cancelled, expired
    FOREIGN KEY (policyholder_id) REFERENCES policyholders(policyholder_id),
    FOREIGN KEY (plan_id) REFERENCES policy_plans(plan_id)
);

-- ------------------------------------------------------------
-- dependents — family members covered under a policy
-- ------------------------------------------------------------
CREATE TABLE dependents (
    dependent_id        INT PRIMARY KEY AUTO_INCREMENT,
    policy_id           INT NOT NULL,
    full_name           VARCHAR(100) NOT NULL,
    birth_date          DATE NOT NULL,
    relationship        VARCHAR(30) NOT NULL,  -- spouse, child
    FOREIGN KEY (policy_id) REFERENCES policies(policy_id)
);

-- ------------------------------------------------------------
-- providers — healthcare providers (doctors, clinics, pharmacies)
-- ------------------------------------------------------------
CREATE TABLE providers (
    provider_id         INT PRIMARY KEY AUTO_INCREMENT,
    provider_name       VARCHAR(120) NOT NULL,
    specialty           VARCHAR(80) NOT NULL,
    city                VARCHAR(80)
);

-- ------------------------------------------------------------
-- care_categories — types of care (consultation, hospitalisation, optique...)
-- ------------------------------------------------------------
CREATE TABLE care_categories (
    category_id         INT PRIMARY KEY AUTO_INCREMENT,
    category_name       VARCHAR(80) NOT NULL,
    reimbursement_rate  DECIMAL(5,2) NOT NULL  -- % reimbursed by the insurer, e.g. 70.00
);

-- ------------------------------------------------------------
-- claims — a healthcare claim filed by a policyholder or dependent
-- ------------------------------------------------------------
CREATE TABLE claims (
    claim_id            INT PRIMARY KEY AUTO_INCREMENT,
    policy_id           INT NOT NULL,
    dependent_id        INT,                   -- NULL = claim is for the policyholder themself
    provider_id         INT NOT NULL,
    category_id         INT NOT NULL,
    care_date            DATE NOT NULL,
    submitted_date       DATE NOT NULL,
    billed_amount        DECIMAL(10,2) NOT NULL,
    status               VARCHAR(20) NOT NULL DEFAULT 'submitted', -- submitted, approved, rejected, paid
    rejection_reason      VARCHAR(150),
    FOREIGN KEY (policy_id) REFERENCES policies(policy_id),
    FOREIGN KEY (dependent_id) REFERENCES dependents(dependent_id),
    FOREIGN KEY (provider_id) REFERENCES providers(provider_id),
    FOREIGN KEY (category_id) REFERENCES care_categories(category_id)
);

-- ------------------------------------------------------------
-- reimbursements — actual payment made against an approved claim
-- ------------------------------------------------------------
CREATE TABLE reimbursements (
    reimbursement_id    INT PRIMARY KEY AUTO_INCREMENT,
    claim_id            INT NOT NULL,
    reimbursed_amount   DECIMAL(10,2) NOT NULL,
    payment_date        DATE NOT NULL,
    FOREIGN KEY (claim_id) REFERENCES claims(claim_id)
);

-- ------------------------------------------------------------
-- premium_payments — monthly premium payments made by policyholders
-- ------------------------------------------------------------
CREATE TABLE premium_payments (
    payment_id          INT PRIMARY KEY AUTO_INCREMENT,
    policy_id           INT NOT NULL,
    payment_date         DATE NOT NULL,
    amount_paid          DECIMAL(8,2) NOT NULL,
    FOREIGN KEY (policy_id) REFERENCES policies(policy_id)
);

-- ------------------------------------------------------------
-- Indexes for analytical query performance
-- ------------------------------------------------------------
CREATE INDEX idx_claims_policy ON claims(policy_id);
CREATE INDEX idx_claims_care_date ON claims(care_date);
CREATE INDEX idx_claims_status ON claims(status);
CREATE INDEX idx_policies_holder ON policies(policyholder_id);
CREATE INDEX idx_reimbursements_claim ON reimbursements(claim_id);
