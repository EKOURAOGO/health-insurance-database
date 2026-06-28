-- ============================================================
-- 01 — Claims & reimbursement analytics
-- ============================================================
USE health_insurance_db;

-- Q1. Overall claims summary: total billed, total reimbursed, approval rate
SELECT
    COUNT(*) AS total_claims,
    SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) AS paid_claims,
    SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) AS rejected_claims,
    ROUND(SUM(CASE WHEN status = 'paid' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS approval_rate_pct,
    ROUND(SUM(billed_amount), 2) AS total_billed
FROM claims;

-- Q2. Total reimbursed amount per month, with month-over-month change
WITH monthly AS (
    SELECT DATE_FORMAT(payment_date, '%Y-%m') AS month,
           SUM(reimbursed_amount) AS total_reimbursed
    FROM reimbursements
    GROUP BY month
)
SELECT month, ROUND(total_reimbursed, 2) AS total_reimbursed,
       ROUND(total_reimbursed - LAG(total_reimbursed) OVER (ORDER BY month), 2) AS change_vs_prev_month
FROM monthly
ORDER BY month;

-- Q3. Rejection reasons breakdown
SELECT rejection_reason, COUNT(*) AS num_claims,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct_of_rejections
FROM claims
WHERE status = 'rejected'
GROUP BY rejection_reason
ORDER BY num_claims DESC;

-- Q4. Average reimbursement rate achieved per care category (actual vs nominal rate)
SELECT cc.category_name, cc.reimbursement_rate AS nominal_rate,
       ROUND(AVG(r.reimbursed_amount * 100.0 / cl.billed_amount), 1) AS actual_avg_rate_pct,
       COUNT(*) AS num_paid_claims
FROM claims cl
JOIN reimbursements r ON cl.claim_id = r.claim_id
JOIN care_categories cc ON cl.category_id = cc.category_id
WHERE cl.status = 'paid'
GROUP BY cc.category_id, cc.category_name, cc.reimbursement_rate
ORDER BY actual_avg_rate_pct DESC;

-- Q5. Policies that reached or exceeded their annual reimbursement cap
SELECT p.policy_id, ph.full_name, pp.plan_name, pp.annual_reimbursement_cap,
       ROUND(SUM(r.reimbursed_amount), 2) AS total_reimbursed_2024
FROM policies p
JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
JOIN claims cl ON p.policy_id = cl.policy_id
JOIN reimbursements r ON cl.claim_id = r.claim_id
GROUP BY p.policy_id, ph.full_name, pp.plan_name, pp.annual_reimbursement_cap
HAVING total_reimbursed_2024 >= pp.annual_reimbursement_cap * 0.9
ORDER BY total_reimbursed_2024 DESC;

-- Q6. Top 10 care categories by total billed amount
SELECT cc.category_name,
       COUNT(*) AS num_claims,
       ROUND(SUM(cl.billed_amount), 2) AS total_billed,
       ROUND(AVG(cl.billed_amount), 2) AS avg_billed_per_claim
FROM claims cl
JOIN care_categories cc ON cl.category_id = cc.category_id
GROUP BY cc.category_id, cc.category_name
ORDER BY total_billed DESC;

-- Q7. Claims filed for dependents vs the policyholder themselves
SELECT
    CASE WHEN dependent_id IS NULL THEN 'Policyholder' ELSE 'Dependent' END AS claimant_type,
    COUNT(*) AS num_claims,
    ROUND(SUM(billed_amount), 2) AS total_billed
FROM claims
GROUP BY claimant_type;

-- Q8. Average number of days between care date and claim submission
SELECT ROUND(AVG(DATEDIFF(submitted_date, care_date)), 1) AS avg_days_to_submit,
       MIN(DATEDIFF(submitted_date, care_date)) AS min_days,
       MAX(DATEDIFF(submitted_date, care_date)) AS max_days
FROM claims;

-- Q9. Seasonal pattern: claims volume by month
SELECT DATE_FORMAT(care_date, '%Y-%m') AS month, COUNT(*) AS num_claims
FROM claims
GROUP BY month
ORDER BY month;

-- Q10. Providers with the highest rejection rate (potential audit candidates)
SELECT pr.provider_name, pr.specialty,
       COUNT(*) AS total_claims,
       SUM(CASE WHEN cl.status = 'rejected' THEN 1 ELSE 0 END) AS rejected_claims,
       ROUND(SUM(CASE WHEN cl.status = 'rejected' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS rejection_rate_pct
FROM claims cl
JOIN providers pr ON cl.provider_id = pr.provider_id
GROUP BY pr.provider_id, pr.provider_name, pr.specialty
HAVING total_claims >= 5
ORDER BY rejection_rate_pct DESC
LIMIT 10;
