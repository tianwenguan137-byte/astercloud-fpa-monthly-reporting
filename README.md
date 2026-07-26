# AsterCloud Monthly FP&A Reporting

An end-to-end FP&A portfolio project for a fictional North American B2B software
company with two revenue streams:

- recurring SaaS subscriptions;
- implementation, optimization, training, and managed services.

The reporting package closes June 2026 and compares actual performance with the
FY2026 budget and the Q2 full-year forecast. The project is designed to
demonstrate SQL, Tableau-ready data modeling, Excel reporting, variance analysis,
and management communication.

> All customers, employees, projects, invoices, and transactions are synthetic.
> Public information is used only to calibrate ranges and business rules. This
> dataset does not reproduce or disclose any real employer data.

## Executive snapshot

![AsterCloud executive summary](assets/executive_summary.png)

| Metric | Result |
| --- | ---: |
| FY2025 revenue | $130.5m |
| FY2025 revenue mix | 83.5% subscription / 16.5% services |
| H1 2026 actual revenue | $69.6m |
| H1 2026 revenue vs budget | $(4.1)m unfavorable |
| H1 2026 adjusted EBITDA | $7.2m / 10.4% margin |
| FY2026 Q2 forecast revenue | $145.0m vs $153.1m budget |
| June 2026 ending ARR | $117.8m |
| June 2026 headcount | 422.6 FTE |
| June 2026 services utilization | 77.3% |

The simulated operating story is intentionally imperfect. Two enterprise
renewal losses and delayed implementation starts create a revenue shortfall.
Hiring delays partially offset the EBITDA impact, while a May cloud commitment
renegotiation improves subscription unit cost.

## Management questions

1. Why is revenue below plan, and is the variance recurring or timing-related?
2. Which revenue stream, region, customer segment, and project explain the gap?
3. Is gross margin moving because of cloud unit cost, utilization, or mix?
4. Are payroll and operating expenses favorable for healthy reasons?
5. What does the Q2 forecast imply for full-year revenue and EBITDA?
6. Where are collection risk and project-margin exceptions concentrated?

## Deliverables

- `data/database/astercloud_fpa.sqlite`: reusable relational database.
- `data/csv/`: normalized source tables with stable IDs.
- `data/tableau/`: flat SQL-generated extracts for Tableau.
- `sql/`: schema, reusable views, analysis queries, and quality checks.
- `deliverables/AsterCloud_FPA_Monthly_Report.xlsx`: formula-driven Excel
  management report.
- `docs/DATA_METHODOLOGY.md`: public benchmarks, modeling choices, and limits.
- `docs/DATA_DICTIONARY.md`: table and field definitions.
- `docs/VALIDATION.md`: row counts, financial tie-outs, and workbook QA results.
- `docs/TABLEAU_DASHBOARD_SPEC.md`: dashboard layout and calculated fields.
- `docs/REUSE_GUIDE.md`: how to extend the same data into a driver-based
  forecasting project.

## Why the data is realistic

The simulation uses four controls rather than unconstrained random numbers:

1. **Public anchors.** Workday informs subscription economics, retention,
   revenue recognition, and cost taxonomy. Globant informs services delivery
   economics. SaaS Capital provides a private B2B growth reference. BLS data
   informs compensation structure.
2. **Accounting relationships.** Subscription revenue is recognized over time;
   project revenue follows delivery; payroll rolls from employee-month records;
   invoices follow contract cadence and payment terms.
3. **Business events.** Churn, hiring delays, utilization softness, and cloud
   cost savings affect the relevant tables instead of being inserted only into a
   final dashboard.
4. **Reconciliation checks.** Subscription revenue, project revenue, payroll,
   invoices, planning periods, and referential integrity are tested in SQL.

The model uses a fixed random seed (`20250725`), so the complete dataset is
reproducible.

## Public calibration sources

| Source | Used for |
| --- | --- |
| [Workday FY2025 Form 10-K](https://www.sec.gov/Archives/edgar/data/1327811/000132781125000056/wday-20250131.htm) | Subscription/services mix, retention, revenue recognition, cost categories |
| [Globant 2024 Form 20-F](https://www.sec.gov/Archives/edgar/data/1557860/000162828025009110/glob-20241231.htm) | Services gross-margin range and project accounting |
| [SaaS Capital 2025 growth benchmarks](https://www.saas-capital.com/research/private-saas-company-growth-rate-benchmarks/) | Private B2B SaaS growth range |
| [BLS employer compensation costs](https://www.bls.gov/news.release/archives/ecec_09122025.htm) | Benefits and compensation loading |
| [BLS industry wage estimates](https://www.bls.gov/oes/2024/may/oes_ind.htm) | Relative salary bands by job family |

The modeled company is not a scaled copy of any one source. It is a composite:
smaller than Workday, with a larger services mix and a profitable internal
delivery organization.

## Data model

```mermaid
erDiagram
  DIM_CUSTOMER ||--o{ FACT_SUBSCRIPTION_MRR : has
  DIM_CUSTOMER ||--o{ DIM_PROJECT : sponsors
  DIM_PROJECT ||--o{ FACT_PROJECT_FINANCIALS : records
  DIM_EMPLOYEE ||--o{ FACT_HEADCOUNT_MONTHLY : costs
  DIM_EMPLOYEE ||--o{ FACT_UTILIZATION_MONTHLY : supplies
  DIM_ACCOUNT ||--o{ FACT_GL_ACTUALS : classifies
  DIM_DEPARTMENT ||--o{ FACT_GL_ACTUALS : owns
  DIM_REGION ||--o{ FACT_GL_ACTUALS : reports
  DIM_ACCOUNT ||--o{ FACT_BUDGET : plans
  DIM_ACCOUNT ||--o{ FACT_FORECAST : forecasts
  DIM_CUSTOMER ||--o{ FACT_INVOICE : billed
```

The detailed model retains transaction-level customer and project keys for
actuals. Budget and forecast are stored at the management planning grain:
month, account, department, region, and business line.

## Reproduce the project

Requirements: Node.js and SQLite.

```bash
node scripts/generate_synthetic_data.mjs
./scripts/build_database.sh
./scripts/export_tableau.sh
sqlite3 -header -column data/database/astercloud_fpa.sqlite < sql/03_quality_checks.sql
```

To explore the prepared management questions:

```bash
sqlite3 -header -column data/database/astercloud_fpa.sqlite < sql/02_analysis_queries.sql
```

## Important conventions

- Currency is USD; Canadian compensation is expressed in USD-equivalent values.
- Revenue and expense facts are stored as positive presentation amounts.
- P&L views subtract costs and expenses from revenue.
- `Adjusted EBITDA` excludes depreciation and amortization; it is a management
  metric, not a GAAP subtotal.
- Actuals run from January 2023 through June 2026.
- FY2026 Budget covers January-December 2026.
- Q2 Forecast contains closed actuals for January-June and revised estimates for
  July-December.

## Portfolio positioning

This repository is intended for Corporate FP&A, Revenue Finance, GTM Finance,
and Finance Analytics / BI roles. It emphasizes the work behind the dashboard:
mapping, reconciliation, scenario versioning, variance logic, and business
interpretation.
