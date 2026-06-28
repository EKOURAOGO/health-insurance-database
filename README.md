# Health Insurance Database — MySQL

Modélisation d'une base de données de mutuelle santé : contrats, sinistres, remboursements et primes sur une année complète, avec application stricte des règles métier réelles (plafond annuel de remboursement, franchise, taux de remboursement par catégorie de soin). 17 requêtes analytiques organisées en deux domaines — gestion des sinistres et pilotage du portefeuille de contrats — validées par une suite de tests automatisés.

---

## Pourquoi ce projet

L'assurance santé est un cas d'école pour la modélisation relationnelle : un contrat couvre un assuré et ses ayants droit, chaque soin appartient à une catégorie avec son propre taux de remboursement, et chaque contrat est soumis à un plafond annuel qui doit être respecté de façon stricte sinistre après sinistre. Ce projet implémente cette logique dans le générateur de données lui-même — un sinistre n'est remboursé que si le plafond n'est pas atteint, et un test automatisé vérifie qu'aucune police n'a jamais été remboursée au-delà de sa limite contractuelle.

---

## Structure du projet

```
health-insurance-db/
├── 01_schema.sql                       # 9 tables, contraintes FK, index analytiques
├── 02_seed_data.sql                    # 1147 sinistres / 852 remboursements / 200 contrats
├── generate_seed.py                    # Génération des données avec logique de plafond (seed fixe)
├── queries_01_claims_analytics.sql     # 10 requêtes — sinistres, taux d'approbation, saisonnalité
├── queries_02_policy_portfolio.sql     # 9 requêtes — loss ratio, churn, segmentation contrats
├── run_tests.sh                        # Suite de 18 tests automatisés avec assertions
└── README.md
```

---

## Schéma de données

9 tables représentant le cycle de vie complet d'un contrat de mutuelle :

| Table | Rôle |
|-------|------|
| `policy_plans` | 4 formules (Essentiel, Confort, Premium, Famille+) avec prime, plafond annuel, franchise |
| `policyholders` / `policies` | 200 assurés et leurs contrats, avec statut actif/résilié |
| `dependents` | Ayants droit couverts par un contrat (conjoint, enfants) |
| `providers` | 40 prestataires de soins (médecins, pharmacies, cliniques, laboratoires) |
| `care_categories` | 8 types de soins avec taux de remboursement nominal |
| `claims` | Sinistres déclarés, avec statut et motif de rejet éventuel |
| `reimbursements` | Paiements effectifs liés à un sinistre approuvé |
| `premium_payments` | Historique des cotisations mensuelles versées |

**Règles métier intégrées au générateur de données :**

- Un sinistre n'est remboursé qu'à hauteur du plafond annuel restant du contrat — au-delà, il est automatiquement rejeté avec le motif *"Plafond annuel de remboursement atteint"*
- La franchise du contrat est déduite avant application du taux de remboursement
- Les contrats Famille+ et certains Premium ont des ayants droit ; les autres formules n'en ont pas
- Saisonnalité hivernale réaliste (pic de sinistres en janvier-février, creux en août)
- 43 contrats résiliés en cours de période, dont plusieurs avant un an d'ancienneté

---

## Domaines d'analyse couverts

### Sinistres (`queries_01`)
Taux d'approbation global, évolution mensuelle des remboursements, répartition des motifs de rejet, écart entre taux de remboursement nominal et réel par catégorie, contrats proches ou au-delà du plafond, délai moyen de déclaration, saisonnalité, prestataires au taux de rejet anormalement élevé.

### Portefeuille de contrats (`queries_02`)
Taux de résiliation par formule, pyramide des âges des assurés, **loss ratio par formule** (primes collectées vs sinistres remboursés), répartition géographique, assurés n'ayant jamais consommé, top utilisateurs, résiliations précoces (moins d'un an), classement des formules par revenu de prime.

---

## Installation

```bash
mysql -u root < 01_schema.sql
mysql -u root < 02_seed_data.sql
mysql -u root health_insurance_db < queries_01_claims_analytics.sql
```

Pour régénérer les données (seed fixe, résultat reproductible) :

```bash
python3 generate_seed.py
```

---

## Lancer les tests

```bash
chmod +x run_tests.sh
./run_tests.sh
```

Sortie attendue :

```
RESULTS: 18 passed, 0 failed
```

Le test le plus significatif vérifie la règle métier centrale du domaine :

| Test | Résultat attendu |
|------|-------------------|
| Aucune police remboursée au-delà de son plafond annuel | 0 dépassement |
| Sinistres rejetés pour dépassement de plafond | > 0 (la règle s'applique réellement) |
| Catégorie générant le plus de facturation | Hospitalisation |
| Formule générant le plus de revenu de prime | Premium |

---

## Aperçu des résultats

**Sinistres 2024 :** 1 147 sinistres déposés, taux d'approbation de 88,4 %, 344 092 € facturés au total

**Motif de rejet dominant :** plafond annuel atteint (66,2 % des rejets)

**Loss ratio par formule** (primes collectées vs sinistres remboursés) :

| Formule | Loss ratio | Lecture |
|---------|-----------|---------|
| Essentiel | 268,3 % | Fortement déficitaire — l'assureur paie 2,68 € pour 1 € de prime |
| Confort | 234,1 % | Déficitaire |
| Premium | 139,9 % | Déficitaire mais dans une moindre mesure |
| Famille+ | 64,7 % | Rentable |

**Saisonnalité confirmée :** 145 sinistres en janvier contre 43 en août, conforme à la saisonnalité hivernale attendue (grippe, affections ORL).

---

## Notes techniques

- Toutes les requêtes utilisent la syntaxe **MySQL 8.0+** (CTE, fenêtrage `RANK`, `LAG`, `TIMESTAMPDIFF`).
- La date de référence pour le calcul des âges et des plafonds est fixée à `'2024-12-31'`, le jeu de données étant historique et figé sur l'année 2024.
- Le générateur (`generate_seed.py`) applique la logique de plafond de façon stricte et séquentielle : chaque sinistre est évalué dans l'ordre chronologique en tenant compte du cumul déjà remboursé sur le contrat.

---

## Stack technique

![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=flat-square&logo=mysql&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-CTE%20·%20Window%20Functions%20·%20Business%20Rules-blue?style=flat-square)
![Bash](https://img.shields.io/badge/Bash-Tests%20automatisés-4EAA25?style=flat-square&logo=gnubash&logoColor=white)

---

## Auteur

**Emmanuel KOURAOGO**

[GitHub](https://github.com/EKOURAOGO) · [Email](mailto:ekouraogo73@gmail.com)
