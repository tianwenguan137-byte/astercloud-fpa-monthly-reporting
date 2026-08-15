# AsterCloud Monthly FP&A Reporting

An end-to-end FP&A portfolio project for a fictional North American B2B software company. The June 2026 reporting package compares actual performance with the FY2026 budget and Q2 full-year forecast across recurring SaaS subscriptions and professional services.

![Tableau Executive Overview](executive_overview.png)

## Project Deliverables

- [Tableau dashboard](deliverables/AsterCloud_FPA_Tableau_Dashboard.twbx)
- [Excel management report](deliverables/AsterCloud_FPA_Monthly_Report.xlsx)
- [Oracle SQL workflow](code/astercloud_fpa_oracle.sql)
- [SQLite SQL workflow](code/astercloud_fpa_sqlite.sql)
- [Raw synthetic data](data/raw/)
- [SQL-processed reporting data](data/processed/)

## Workflow

```text
Raw normalized CSV tables
        ↓
SQL audit, joins, reconciliation and reporting views
        ↓
Nine processed reporting datasets
        ↓
Excel management reporting and Tableau dashboards
```

Oracle SQL is presented as the primary enterprise implementation. SQLite contains the same FP&A workflow in a lightweight local environment. Both versions cover source-data review, key and grain validation, financial reconciliation, reusable views, management analysis and final reporting outputs.

## Executive Snapshot

| Metric | Result |
|---|---:|
| FY2025 revenue | $130.5m |
| H1 2026 actual revenue | $69.6m |
| H1 2026 revenue vs. budget | $(4.1)m unfavorable |
| H1 2026 adjusted EBITDA | $7.2m / 10.4% margin |
| FY2026 Q2 forecast revenue | $145.0m vs. $153.1m budget |
| June 2026 ending ARR | $117.8m |
| June 2026 headcount | 422.6 FTE |
| June 2026 services utilization | 77.3% |

## Management Findings

- H1 revenue finished $4.1m below budget, driven by subscription renewal losses and delayed professional-services starts.
- Subscription losses represent a recurring revenue issue; delayed services revenue is mainly timing-related.
- Hiring delays partially offset the EBITDA impact but do not resolve the underlying revenue gap.
- A May cloud-commitment renegotiation improved subscription unit cost and supported gross margin.
- Collection risk is concentrated among past-due customers and selected regional exposures.

## Processed Data

The same nine SQL outputs support both the Excel workbook and Tableau dashboard:

| Dataset | Reporting use |
|---|---|
| `01_monthly_pnl.csv` | Monthly Actual, Budget and Q2 Forecast P&L |
| `02_pnl_line_monthly.csv` | Account-line variance analysis |
| `03_monthly_kpi.csv` | Revenue, margin, EBITDA, ARR, FTE and utilization KPIs |
| `04_arr_bridge.csv` | New, expansion, contraction and churn ARR |
| `05_headcount_utilization.csv` | Personnel cost, headcount and services utilization |
| `06_project_margin.csv` | Project economics and low-margin exceptions |
| `07_ar_aging.csv` | Open receivables, aging and collection risk |
| `08_customer_ttm.csv` | Customer concentration and segment mix |
| `09_quality_checks.csv` | Financial tie-outs and data-quality controls |

## Excel Structure

The nine processed CSV files are loaded into the workbook's `Data_*` sheets. Formula-driven management sheets use `SUMIFS`, ratios and cross-sheet references to produce the Summary, Variance Analysis, Monthly P&L, Revenue & ARR, Headcount & Utilization, AR Aging and Checks views.

## Data Note

All customers, employees, projects, invoices and transactions are synthetic. Public information is used only to calibrate realistic ranges and business rules. No real employer data is reproduced or disclosed.

