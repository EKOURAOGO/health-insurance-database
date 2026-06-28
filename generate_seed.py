import random
from datetime import date, timedelta

random.seed(7)

lines = []
lines.append("-- ============================================================")
lines.append("-- Health Insurance Database — Seed data (generated)")
lines.append("-- ============================================================")
lines.append("USE health_insurance_db;\n")

first_names = ["Lucas","Emma","Hugo","Lea","Louis","Chloe","Jules","Manon","Adam","Camille",
               "Nathan","Sarah","Theo","Ines","Mathis","Zoe","Noah","Lola","Ethan","Eva",
               "Marie","Pierre","Sophie","Julien","Claire","Antoine","Laura","Maxime"]
last_names = ["Martin","Bernard","Dubois","Thomas","Robert","Petit","Durand","Leroy","Moreau","Simon",
              "Laurent","Lefebvre","Michel","Garcia","David","Bertrand","Roux","Vincent"]
cities = ["Paris","Lyon","Marseille","Lille","Toulouse","Nantes","Bordeaux","Strasbourg","Nice","Rennes"]

# ------------------------------------------------------------
# policy_plans
# ------------------------------------------------------------
plans = [
    (1, "Essentiel",  29.90,  1500.00, 50.00),
    (2, "Confort",    49.90,  3500.00, 30.00),
    (3, "Premium",    89.90,  8000.00, 0.00),
    (4, "Famille+",   119.90, 12000.00, 0.00),
]
lines.append("-- policy_plans")
lines.append("INSERT INTO policy_plans (plan_id, plan_name, monthly_premium, annual_reimbursement_cap, deductible) VALUES")
lines.append(",\n".join(f"({i},'{n}',{p},{cap},{d})" for i,n,p,cap,d in plans) + ";\n")

# ------------------------------------------------------------
# care_categories (with realistic French health insurance reimbursement rates)
# ------------------------------------------------------------
categories = [
    (1, "Consultation generaliste", 70.00),
    (2, "Consultation specialiste", 70.00),
    (3, "Pharmacie", 65.00),
    (4, "Dentaire", 50.00),
    (5, "Optique", 60.00),
    (6, "Hospitalisation", 80.00),
    (7, "Analyses laboratoire", 60.00),
    (8, "Kinesitherapie", 60.00),
]
lines.append("-- care_categories")
lines.append("INSERT INTO care_categories (category_id, category_name, reimbursement_rate) VALUES")
lines.append(",\n".join(f"({i},'{n}',{r})" for i,n,r in categories) + ";\n")

# ------------------------------------------------------------
# providers
# ------------------------------------------------------------
specialties = ["Medecin generaliste", "Cardiologue", "Dermatologue", "Dentiste",
               "Ophtalmologue", "Pharmacie", "Hopital", "Kinesitherapeute", "Laboratoire d''analyses"]
providers = []
for pid in range(1, 41):
    name_type = random.choice(["Dr.", "Cabinet", "Pharmacie", "Clinique", "Laboratoire"])
    name = f"{name_type} {random.choice(last_names)}"
    specialty = random.choice(specialties)
    city = random.choice(cities)
    providers.append((pid, name, specialty, city))

lines.append("-- providers")
lines.append("INSERT INTO providers (provider_id, provider_name, specialty, city) VALUES")
lines.append(",\n".join(f"({i},'{n}','{s}','{c}')" for i,n,s,c in providers) + ";\n")

# ------------------------------------------------------------
# policyholders (200 people)
# ------------------------------------------------------------
policyholders = []
for pid in range(1, 201):
    name = f"{random.choice(first_names)} {random.choice(last_names)}"
    birth = date(random.randint(1950, 2002), random.randint(1,12), random.randint(1,28))
    city = random.choice(cities)
    email = f"{name.lower().replace(' ', '.')}{pid}@email.fr"
    policyholders.append((pid, name, birth.isoformat(), city, email))

lines.append("-- policyholders")
lines.append("INSERT INTO policyholders (policyholder_id, full_name, birth_date, city, email) VALUES")
batch = [f"({p[0]},'{p[1]}','{p[2]}','{p[3]}','{p[4]}')" for p in policyholders]
lines.append(",\n".join(batch) + ";\n")

# ------------------------------------------------------------
# policies (one per policyholder, some cancelled, some still active)
# ------------------------------------------------------------
policies = []
pol_id = 1
for ph_id, *_ in policyholders:
    plan_id = random.choices([1,2,3,4], weights=[35,35,20,10])[0]
    start = date(2021, 1, 1) + timedelta(days=random.randint(0, 900))
    # 15% of policies got cancelled at some point
    if random.random() < 0.15:
        end = start + timedelta(days=random.randint(180, 700))
        if end > date(2024,12,31):
            end = None
            status = "active"
        else:
            status = "cancelled"
    else:
        end = None
        status = "active"
    policies.append((pol_id, ph_id, plan_id, start.isoformat(),
                      end.isoformat() if end else None, status))
    pol_id += 1

lines.append("-- policies")
lines.append("INSERT INTO policies (policy_id, policyholder_id, plan_id, start_date, end_date, status) VALUES")
batch = []
for p in policies:
    end_val = f"'{p[4]}'" if p[4] else "NULL"
    batch.append(f"({p[0]},{p[1]},{p[2]},'{p[3]}',{end_val},'{p[5]}')")
lines.append(",\n".join(batch) + ";\n")

# ------------------------------------------------------------
# dependents (only for Famille+ plan holders, and some Premium)
# ------------------------------------------------------------
dependents = []
dep_id = 1
for pol in policies:
    pol_id_, ph_id, plan_id, start, end, status = pol
    if plan_id == 4:  # Famille+
        n_dep = random.randint(1, 3)
    elif plan_id == 3 and random.random() < 0.3:  # some Premium have a spouse
        n_dep = 1
    else:
        n_dep = 0
    for _ in range(n_dep):
        rel = random.choice(["spouse", "child", "child"])
        name = f"{random.choice(first_names)} {random.choice(last_names)}"
        if rel == "child":
            birth = date(random.randint(2008, 2023), random.randint(1,12), random.randint(1,28))
        else:
            birth = date(random.randint(1955, 2000), random.randint(1,12), random.randint(1,28))
        dependents.append((dep_id, pol_id_, name, birth.isoformat(), rel))
        dep_id += 1

lines.append("-- dependents")
lines.append("INSERT INTO dependents (dependent_id, policy_id, full_name, birth_date, relationship) VALUES")
batch = [f"({d[0]},{d[1]},'{d[2]}','{d[3]}','{d[4]}')" for d in dependents]
lines.append(",\n".join(batch) + ";\n")

# ------------------------------------------------------------
# claims + reimbursements
# 2024 calendar year, with seasonal patterns (more claims in winter: flu season)
# ------------------------------------------------------------
plan_caps = {p[0]: p[3] for p in plans}
plan_deductibles = {p[0]: p[4] for p in plans}
category_rates = {c[0]: c[2] for c in categories}

claims = []
reimbursements = []
claim_id = 1
reimb_id = 1

# Track cumulative reimbursed amount per policy per year (for cap enforcement)
policy_annual_reimbursed = {p[0]: 0.0 for p in policies}

rejection_reasons = [
    "Plafond annuel de remboursement atteint",
    "Prestataire hors reseau",
    "Document justificatif manquant",
    "Soin non couvert par le contrat",
]

active_policy_ids = [p[0] for p in policies]

def seasonality(d):
    month = d.month
    # more claims in Jan/Feb (flu) and a dip in August
    weights = {1:1.5, 2:1.4, 3:1.1, 4:0.9, 5:0.9, 6:0.9, 7:0.8, 8:0.6,
               9:1.0, 10:1.1, 11:1.2, 12:1.3}
    return weights.get(month, 1.0)

current = date(2024,1,1)
end_period = date(2024,12,31)
while current <= end_period:
    weight = seasonality(current)
    n_claims_today = max(0, int(random.gauss(4 * weight, 2)))
    for _ in range(n_claims_today):
        pol = random.choice(policies)
        pol_id_, ph_id, plan_id, p_start, p_end, p_status = pol
        # skip if the policy was not active on this date
        p_start_date = date(*map(int, p_start.split('-')))
        if p_start_date > current:
            continue
        if p_end:
            p_end_date = date(*map(int, p_end.split('-')))
            if p_end_date < current:
                continue

        # decide if it's for the policyholder or a dependent
        pol_dependents = [d for d in dependents if d[1] == pol_id_]
        if pol_dependents and random.random() < 0.3:
            dependent_id = random.choice(pol_dependents)[0]
        else:
            dependent_id = None

        provider = random.choice(providers)
        category = random.choice(categories)
        category_id = category[0]

        # billed amount depends loosely on category
        base_amounts = {1:25,2:50,3:30,4:120,5:200,6:1500,7:40,8:35}
        billed = round(base_amounts.get(category_id, 50) * random.uniform(0.7, 1.8), 2)

        submitted = current + timedelta(days=random.randint(1,10))
        if submitted > date(2024,12,31):
            submitted = date(2024,12,31)

        # determine approval
        deductible = plan_deductibles[plan_id]
        cap = plan_caps[plan_id]
        rate = category_rates[category_id]
        reimbursable = max(0, billed - deductible) * rate / 100

        already_reimbursed = policy_annual_reimbursed[pol_id_]
        rejection_reason = None

        if random.random() < 0.04:
            # random administrative rejection
            status = "rejected"
            rejection_reason = random.choice(rejection_reasons[1:])
        elif already_reimbursed >= cap:
            status = "rejected"
            rejection_reason = rejection_reasons[0]
            reimbursable = 0
        elif already_reimbursed + reimbursable > cap:
            # partial: cap reached mid-claim -> reduce reimbursable, still "paid"
            reimbursable = max(0, cap - already_reimbursed)
            status = "paid" if reimbursable > 0 else "rejected"
            if reimbursable == 0:
                rejection_reason = rejection_reasons[0]
        else:
            status = "paid"

        claims.append((claim_id, pol_id_, dependent_id, provider[0], category_id,
                        current.isoformat(), submitted.isoformat(), billed, status, rejection_reason))

        if status == "paid" and reimbursable > 0:
            policy_annual_reimbursed[pol_id_] += reimbursable
            payment_date = submitted + timedelta(days=random.randint(2,15))
            if payment_date > date(2024,12,31):
                payment_date = date(2024,12,31)
            reimbursements.append((reimb_id, claim_id, round(reimbursable,2), payment_date.isoformat()))
            reimb_id += 1

        claim_id += 1
    current += timedelta(days=1)

lines.append("-- claims")
chunks = []
batch = []
for c in claims:
    rej = f"'{c[9]}'" if c[9] else "NULL"
    dep = c[2] if c[2] else "NULL"
    batch.append(f"({c[0]},{c[1]},{dep},{c[3]},{c[4]},'{c[5]}','{c[6]}',{c[7]},'{c[8]}',{rej})")
    if len(batch) >= 400:
        chunks.append("INSERT INTO claims (claim_id, policy_id, dependent_id, provider_id, category_id, care_date, submitted_date, billed_amount, status, rejection_reason) VALUES\n" + ",\n".join(batch) + ";")
        batch = []
if batch:
    chunks.append("INSERT INTO claims (claim_id, policy_id, dependent_id, provider_id, category_id, care_date, submitted_date, billed_amount, status, rejection_reason) VALUES\n" + ",\n".join(batch) + ";")
lines.append("\n\n".join(chunks) + "\n")

lines.append("-- reimbursements")
chunks = []
batch = []
for r in reimbursements:
    batch.append(f"({r[0]},{r[1]},{r[2]},'{r[3]}')")
    if len(batch) >= 400:
        chunks.append("INSERT INTO reimbursements (reimbursement_id, claim_id, reimbursed_amount, payment_date) VALUES\n" + ",\n".join(batch) + ";")
        batch = []
if batch:
    chunks.append("INSERT INTO reimbursements (reimbursement_id, claim_id, reimbursed_amount, payment_date) VALUES\n" + ",\n".join(batch) + ";")
lines.append("\n\n".join(chunks) + "\n")

# ------------------------------------------------------------
# premium_payments — monthly payments for active months of each policy
# ------------------------------------------------------------
premium_payments = []
pay_id = 1
plan_premiums = {p[0]: p[2] for p in plans}
for pol in policies:
    pol_id_, ph_id, plan_id, p_start, p_end, p_status = pol
    p_start_date = date(*map(int, p_start.split('-')))
    p_end_date = date(*map(int, p_end.split('-'))) if p_end else date(2024,12,31)

    # only generate payments within calendar year 2024
    period_start = max(p_start_date, date(2024,1,1))
    period_end = min(p_end_date, date(2024,12,31))
    if period_start > period_end:
        continue

    m = date(period_start.year, period_start.month, 1)
    while m <= period_end:
        premium_payments.append((pay_id, pol_id_, m.isoformat(), plan_premiums[plan_id]))
        pay_id += 1
        if m.month == 12:
            m = date(m.year+1, 1, 1)
        else:
            m = date(m.year, m.month+1, 1)

lines.append("-- premium_payments")
chunks = []
batch = []
for pp in premium_payments:
    batch.append(f"({pp[0]},{pp[1]},'{pp[2]}',{pp[3]})")
    if len(batch) >= 400:
        chunks.append("INSERT INTO premium_payments (payment_id, policy_id, payment_date, amount_paid) VALUES\n" + ",\n".join(batch) + ";")
        batch = []
if batch:
    chunks.append("INSERT INTO premium_payments (payment_id, policy_id, payment_date, amount_paid) VALUES\n" + ",\n".join(batch) + ";")
lines.append("\n\n".join(chunks) + "\n")

with open("/home/claude/health-insurance-project/02_seed_data.sql", "w") as f:
    f.write("\n".join(lines))

print(f"Generated: {len(plans)} plans, {len(categories)} categories, {len(providers)} providers,")
print(f"{len(policyholders)} policyholders, {len(policies)} policies, {len(dependents)} dependents,")
print(f"{len(claims)} claims, {len(reimbursements)} reimbursements, {len(premium_payments)} premium payments")

n_rejected = sum(1 for c in claims if c[8] == 'rejected')
n_paid = sum(1 for c in claims if c[8] == 'paid')
n_cancelled_policies = sum(1 for p in policies if p[5] == 'cancelled')
print(f"Claims: {n_paid} paid, {n_rejected} rejected")
print(f"Cancelled policies: {n_cancelled_policies}")
