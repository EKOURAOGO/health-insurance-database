-- ============================================================
-- 02 — Policyholder & policy portfolio analytics
-- ============================================================
USE health_insurance_db;

-- P1. Active vs cancelled policies, by plan
SELECT pp.plan_name,
       SUM(CASE WHEN p.status = 'active' THEN 1 ELSE 0 END) AS active_policies,
       SUM(CASE WHEN p.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_policies,
       ROUND(SUM(CASE WHEN p.status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS cancellation_rate_pct
FROM policies p
JOIN policy_plans pp ON p.plan_id = pp.plan_id
GROUP BY pp.plan_id, pp.plan_name
ORDER BY cancellation_rate_pct DESC;

-- P2. Policyholder age distribution by plan (age computed as of 2024-12-31)
SELECT pp.plan_name,
       ROUND(AVG(TIMESTAMPDIFF(YEAR, ph.birth_date, '2024-12-31')), 1) AS avg_age,
       MIN(TIMESTAMPDIFF(YEAR, ph.birth_date, '2024-12-31')) AS min_age,
       MAX(TIMESTAMPDIFF(YEAR, ph.birth_date, '2024-12-31')) AS max_age
FROM policies p
JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
GROUP BY pp.plan_id, pp.plan_name;

-- P3. Loss ratio per plan: total reimbursed vs total premiums collected
WITH premiums AS (
    SELECT p.plan_id, SUM(pay.amount_paid) AS total_premiums
    FROM policies p
    JOIN premium_payments pay ON p.policy_id = pay.policy_id
    GROUP BY p.plan_id
),
claims_paid AS (
    SELECT p.plan_id, SUM(r.reimbursed_amount) AS total_reimbursed
    FROM policies p
    JOIN claims cl ON p.policy_id = cl.policy_id
    JOIN reimbursements r ON cl.claim_id = r.claim_id
    GROUP BY p.plan_id
)
SELECT pp.plan_name,
       ROUND(prem.total_premiums, 2) AS total_premiums_collected,
       ROUND(cp.total_reimbursed, 2) AS total_reimbursed,
       ROUND(cp.total_reimbursed * 100.0 / prem.total_premiums, 1) AS loss_ratio_pct
FROM policy_plans pp
JOIN premiums prem ON pp.plan_id = prem.plan_id
JOIN claims_paid cp ON pp.plan_id = cp.plan_id
ORDER BY loss_ratio_pct DESC;

-- P4. Policyholders with dependents, and dependent count
SELECT ph.full_name, pp.plan_name, COUNT(d.dependent_id) AS num_dependents
FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
LEFT JOIN dependents d ON p.policy_id = d.policy_id
GROUP BY ph.policyholder_id, ph.full_name, pp.plan_name
HAVING num_dependents > 0
ORDER BY num_dependents DESC;

-- P5. Policyholders who never filed a single claim
SELECT ph.policyholder_id, ph.full_name, pp.plan_name, p.start_date
FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
LEFT JOIN claims cl ON p.policy_id = cl.policy_id
WHERE cl.claim_id IS NULL;

-- P6. Top 10 policyholders by total claims filed (highest utilization)
SELECT ph.full_name, pp.plan_name,
       COUNT(cl.claim_id) AS num_claims,
       ROUND(SUM(cl.billed_amount), 2) AS total_billed
FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
JOIN claims cl ON p.policy_id = cl.policy_id
GROUP BY ph.policyholder_id, ph.full_name, pp.plan_name
ORDER BY num_claims DESC
LIMIT 10;

-- P7. City-level distribution of policyholders and their total reimbursements
SELECT ph.city,
       COUNT(DISTINCT ph.policyholder_id) AS num_policyholders,
       ROUND(COALESCE(SUM(r.reimbursed_amount), 0), 2) AS total_reimbursed
FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
LEFT JOIN claims cl ON p.policy_id = cl.policy_id
LEFT JOIN reimbursements r ON cl.claim_id = r.claim_id
GROUP BY ph.city
ORDER BY total_reimbursed DESC;

-- P8. Policies cancelled within their first year (early churn)
SELECT ph.full_name, pp.plan_name, p.start_date, p.end_date,
       DATEDIFF(p.end_date, p.start_date) AS days_active
FROM policies p
JOIN policyholders ph ON p.policyholder_id = ph.policyholder_id
JOIN policy_plans pp ON p.plan_id = pp.plan_id
WHERE p.status = 'cancelled'
  AND DATEDIFF(p.end_date, p.start_date) <= 365
ORDER BY days_active ASC;

-- P9. Premium revenue by plan, ranked
SELECT pp.plan_name,
       COUNT(DISTINCT p.policy_id) AS num_policies,
       ROUND(SUM(pay.amount_paid), 2) AS total_premium_revenue,
       RANK() OVER (ORDER BY SUM(pay.amount_paid) DESC) AS revenue_rank
FROM policy_plans pp
JOIN policies p ON pp.plan_id = p.plan_id
JOIN premium_payments pay ON p.policy_id = pay.policy_id
GROUP BY pp.plan_id, pp.plan_name;
