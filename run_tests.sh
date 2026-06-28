#!/bin/bash
# ============================================================
# Health Insurance Database — Automated test suite
# Verifies query correctness with concrete assertions
# computed independently from the seed data.
# ============================================================

set -uo pipefail

DB="health_insurance_db"
PASS=0
FAIL=0

run_query() {
    mysql -u root -N -B "$DB" -e "$1" 2>&1
}

assert_eq() {
    local description="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" == "$expected" ]; then
        echo "  PASS  $description"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description (expected '$expected', got '$actual')"
        FAIL=$((FAIL+1))
    fi
}

assert_gt() {
    local description="$1"
    local actual="$2"
    local threshold="$3"
    if (( $(echo "$actual > $threshold" | bc -l) )); then
        echo "  PASS  $description ($actual > $threshold)"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description ($actual is not > $threshold)"
        FAIL=$((FAIL+1))
    fi
}

assert_le() {
    local description="$1"
    local actual="$2"
    local threshold="$3"
    if (( $(echo "$actual <= $threshold" | bc -l) )); then
        echo "  PASS  $description ($actual <= $threshold)"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description ($actual is not <= $threshold)"
        FAIL=$((FAIL+1))
    fi
}

echo "============================================================"
echo "Running Health Insurance Database test suite"
echo "============================================================"

# ------------------------------------------------------------
echo ""
echo "-- Data integrity --"

result=$(run_query "SELECT COUNT(*) FROM policy_plans;")
assert_eq "4 policy plans loaded" "$result" "4"

result=$(run_query "SELECT COUNT(*) FROM policyholders;")
assert_eq "200 policyholders loaded" "$result" "200"

result=$(run_query "SELECT COUNT(*) FROM policies;")
assert_eq "200 policies loaded (one per policyholder)" "$result" "200"

result=$(run_query "SELECT COUNT(*) FROM claims c LEFT JOIN policies p ON c.policy_id = p.policy_id WHERE p.policy_id IS NULL;")
assert_eq "Zero orphan claims (all reference a valid policy)" "$result" "0"

result=$(run_query "SELECT COUNT(*) FROM reimbursements r LEFT JOIN claims c ON r.claim_id = c.claim_id WHERE c.claim_id IS NULL;")
assert_eq "Zero orphan reimbursements (all reference a valid claim)" "$result" "0"

result=$(run_query "SELECT COUNT(*) FROM reimbursements r JOIN claims c ON r.claim_id = c.claim_id WHERE c.status != 'paid';")
assert_eq "Zero reimbursements linked to a non-paid claim" "$result" "0"

result=$(run_query "SELECT COUNT(*) FROM claims WHERE status NOT IN ('paid','rejected','submitted','approved');")
assert_eq "All claims have a valid status value" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "-- Business rule: annual reimbursement cap --"

result=$(run_query "
SELECT COUNT(*) FROM (
    SELECT p.policy_id, pp.annual_reimbursement_cap, SUM(r.reimbursed_amount) AS total_reimb
    FROM policies p
    JOIN policy_plans pp ON p.plan_id = pp.plan_id
    JOIN claims cl ON p.policy_id = cl.policy_id
    JOIN reimbursements r ON cl.claim_id = r.claim_id
    GROUP BY p.policy_id, pp.annual_reimbursement_cap
    HAVING total_reimb > pp.annual_reimbursement_cap + 0.01
) over_cap;
")
assert_eq "No policy was reimbursed beyond its annual cap (rule strictly enforced)" "$result" "0"

result=$(run_query "
SELECT COUNT(*) FROM claims WHERE rejection_reason = 'Plafond annuel de remboursement atteint';
")
assert_gt "At least some claims were rejected for exceeding the annual cap" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "-- Claims analytics --"

result=$(run_query "SELECT COUNT(*) FROM claims;")
assert_eq "1147 claims loaded" "$result" "1147"

result=$(run_query "SELECT COUNT(*) FROM claims WHERE status = 'paid';")
assert_eq "1014 claims have status paid" "$result" "1014"

result=$(run_query "SELECT COUNT(*) FROM claims WHERE status = 'rejected';")
assert_eq "133 claims have status rejected" "$result" "133"

result=$(run_query "
SELECT category_name FROM care_categories cc
JOIN claims cl ON cc.category_id = cl.category_id
GROUP BY cc.category_id, category_name
ORDER BY SUM(cl.billed_amount) DESC
LIMIT 1;
")
assert_eq "Hospitalisation is the category with the highest total billed amount" "$result" "Hospitalisation"

result=$(run_query "
SELECT ROUND(AVG(DATEDIFF(submitted_date, care_date)), 1) FROM claims;
")
assert_le "Average days to submit a claim stays within a realistic 0-10 day window" "$result" "10"

# ------------------------------------------------------------
echo ""
echo "-- Policy portfolio analytics --"

result=$(run_query "SELECT COUNT(*) FROM policies WHERE status = 'cancelled';")
assert_eq "43 policies have status cancelled" "$result" "43"

result=$(run_query "
SELECT COUNT(*) FROM policies WHERE status = 'cancelled' AND end_date < start_date;
")
assert_eq "No cancelled policy has an end_date earlier than its start_date" "$result" "0"

result=$(run_query "
SELECT plan_name FROM policy_plans pp
JOIN policies p ON pp.plan_id = p.plan_id
JOIN premium_payments pay ON p.policy_id = pay.policy_id
GROUP BY pp.plan_id, plan_name
ORDER BY SUM(pay.amount_paid) DESC
LIMIT 1;
")
assert_eq "Premium plan generates the highest total premium revenue" "$result" "Premium"

result=$(run_query "
SELECT COUNT(*) FROM policyholders ph
JOIN policies p ON ph.policyholder_id = p.policyholder_id
LEFT JOIN claims cl ON p.policy_id = cl.policy_id
WHERE cl.claim_id IS NULL;
")
assert_gt "Some policyholders have never filed a claim (zero-utilization segment exists)" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
