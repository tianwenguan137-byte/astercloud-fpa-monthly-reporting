# Validation Record

Validation date: 2026-07-25  
Reporting cutoff: 2026-06-30  
Random seed: `20250725`

## Dataset inventory

| Table | Rows |
| --- | ---: |
| `dim_date_month` | 48 |
| `dim_region` | 4 |
| `dim_department` | 12 |
| `dim_account` | 23 |
| `dim_customer` | 300 |
| `dim_project` | 220 |
| `dim_employee` | 505 |
| `fact_subscription_mrr` | 10,006 |
| `fact_headcount_monthly` | 16,197 |
| `fact_utilization_monthly` | 3,035 |
| `fact_project_financials` | 1,301 |
| `fact_gl_actuals` | 17,322 |
| `fact_budget` | 1,260 |
| `fact_forecast` | 1,260 |
| `fact_invoice` | 2,199 |

## SQL controls

All required controls passed against
`data/database/astercloud_fpa.sqlite`.

| Control | Difference | Tolerance | Result |
| --- | ---: | ---: | --- |
| Subscription revenue ties to GL | $0.00 | $0.05 | PASS |
| Services revenue ties to GL | $0.00 | $0.05 | PASS |
| Services labor ties to payroll | $0.00 | $0.05 | PASS |
| Budget contains twelve months | 0 | 0 | PASS |
| Forecast contains twelve months | 0 | 0 | PASS |
| Invoices reconcile | $0.00 | $0.05 | PASS |
| No negative MRR | 0 | 0 | PASS |
| No impossible utilization | 0 | 0 | PASS |
| Foreign-key integrity | 0 | 0 | PASS |

## Workbook controls

- Formula error scan matched zero cells containing `#REF!`, `#DIV/0!`,
  `#VALUE!`, `#NAME?`, or `#N/A`.
- The `Checks` worksheet displays `MODEL STATUS: PASS`.
- Two consecutive generator runs produced the same combined CSV checksum:
  `48fa9cc05635dfb67684a65219fdf1e62cc25587`.
- The presentation sheets were rendered and visually inspected for clipped
  text, inconsistent formats, invalid date axes, and chart overlap.
- Summary metrics reconcile to the SQL reporting views and Tableau extracts.

## Reproduce validation

```bash
./scripts/build_database.sh
./scripts/export_tableau.sh
sqlite3 -header -column data/database/astercloud_fpa.sqlite < sql/03_quality_checks.sql
```

The generator is deterministic. Running
`node scripts/generate_synthetic_data.mjs` with the unchanged seed and model
rules recreates the same source dataset.
