# Data Dictionary

## Model conventions

- Dates use ISO format.
- Month fields use the first day of the month.
- Currency amounts are USD.
- Revenue and expense facts are positive presentation amounts.
- Blank `customer_id` or `project_id` means the record is not attributed at
  that grain.

## Dimensions

### `dim_date_month`

One row per calendar month from January 2023 through December 2026.

| Field | Definition |
| --- | --- |
| `month_start` | Primary key in `YYYY-MM-01` format |
| `calendar_year` | Calendar year |
| `calendar_quarter` | Q1-Q4 |
| `month_number` | 1-12 |
| `month_name` | English month name |
| `fiscal_year` | Calendar-aligned fiscal year |
| `fiscal_quarter` | Year and fiscal quarter |
| `period_status` | Actual or Future as of June 2026 |

### `dim_region`

Reporting and employee hubs.

| Field | Definition |
| --- | --- |
| `region_id` | Stable region key |
| `region_name` | US West, US Central, US East, or Canada |
| `primary_hub` | Representative office hub |
| `country` | Country |
| `currency` | Local operating currency |
| `salary_index` | Relative salary multiplier |
| `revenue_weight` | Customer allocation weight |

### `dim_department`

Finance ownership and cost-center hierarchy.

| Field | Definition |
| --- | --- |
| `department_id` | Stable department key |
| `department_name` | Department label |
| `function_group` | Revenue, Cost of Revenue, S&M, R&D, or G&A |
| `cost_center` | Synthetic cost center |
| `budget_owner` | Role accountable for plan |

### `dim_account`

Management P&L mapping.

| Field | Definition |
| --- | --- |
| `account_id` | Stable account key |
| `account_code` | Four-digit natural-account code |
| `account_name` | Natural-account name |
| `statement_section` | Revenue, Cost of Revenue, Operating Expense, or D&A |
| `pnl_line` | Management-reporting line |
| `business_line` | Subscription, Services, or Corporate |
| `natural_balance` | Debit or Credit |
| `favorable_direction` | Whether higher or lower is favorable |
| `sort_order` | P&L presentation order |

### `dim_customer`

Synthetic customer master.

| Field | Definition |
| --- | --- |
| `customer_id` | Stable synthetic key |
| `customer_name` | Invented display name |
| `industry` | Customer industry |
| `segment` | Enterprise, Mid-Market, or SMB |
| `region_id` | Reporting region |
| `contract_start_month` | First subscription month |
| `renewal_month` | Contract renewal month number |
| `billing_cadence` | Annual or Quarterly |
| `payment_terms_days` | Contractual terms |
| `credit_risk_tier` | A, B, or C |
| `initial_acv_usd` | Initial annual contract value |
| `churn_month` | Full-customer churn month, if any |
| `current_arr_usd` | ARR at June 2026 |

### `dim_project`

Synthetic services project master.

| Field | Definition |
| --- | --- |
| `project_id` | Stable project key |
| `customer_id` | Sponsoring customer |
| `region_id` | Delivery/reporting region |
| `project_type` | Implementation, Optimization, Training, or Managed Services |
| `contract_type` | T&M or Fixed Price |
| `start_month` | Project start |
| `planned_end_month` | Planned completion |
| `status` | Completed or In Progress |
| `contract_value_usd` | Estimated total contract value |
| `blended_bill_rate_usd` | Revenue divided by billable hours |
| `actual_margin_pct` | Project contribution margin to date |

### `dim_employee`

Anonymized workforce master.

| Field | Definition |
| --- | --- |
| `employee_id` | Stable anonymized key |
| `department_id` | Employee department |
| `region_id` | Employee hub |
| `job_family` | Functional job family |
| `level` | Career level |
| `employment_type` | Full-time or Part-time |
| `start_month` | Hire month |
| `end_month` | Termination month, if any |
| `annual_base_salary_at_hire_usd` | Synthetic starting salary |

## Facts

### `fact_subscription_mrr`

Customer-month recurring-revenue bridge.

| Field | Definition |
| --- | --- |
| `opening_mrr_usd` | MRR entering the month |
| `new_mrr_usd` | MRR from newly activated customers |
| `expansion_mrr_usd` | Price and cross-sell expansion |
| `contraction_mrr_usd` | Downgrade or volume reduction |
| `churn_mrr_usd` | Lost recurring revenue |
| `ending_mrr_usd` | Opening + new + expansion - contraction - churn |
| `recognized_revenue_usd` | Monthly subscription revenue |

Additional fields: `month_start`, `customer_id`, `region_id`, `segment`, and
`plan_tier`.

### `fact_project_financials`

Project-month services economics.

| Field | Definition |
| --- | --- |
| `revenue_usd` | Revenue recognized during the month |
| `direct_labor_cost_usd` | Billable delivery hours at loaded cost per available hour |
| `subcontractor_cost_usd` | External delivery cost |
| `travel_cost_usd` | Client/project travel |
| `gross_profit_usd` | Revenue less the three project cost fields |
| `billable_hours` | Allocated client-billable hours |

Keys: `month_start`, `project_id`, `customer_id`, and `region_id`.

### `fact_headcount_monthly`

Employee-month cost record.

| Field | Definition |
| --- | --- |
| `fte` | 1.0 full-time or 0.6 part-time |
| `monthly_base_salary_usd` | Monthly salary |
| `bonus_accrual_usd` | Monthly variable compensation accrual |
| `benefits_usd` | Health, retirement, and other cash benefits |
| `payroll_taxes_usd` | Employer payroll-tax estimate |
| `total_personnel_cost_usd` | Sum of the cost fields |

### `fact_utilization_monthly`

Professional-services employee-month capacity.

| Field | Definition |
| --- | --- |
| `available_hours` | Work hours after modeled leave |
| `billable_hours` | Client-delivery hours |
| `internal_hours` | Training, enablement, and internal work |
| `bench_hours` | Unallocated time |
| `utilization_rate` | Billable / available |

### `fact_gl_actuals`

Management-ledger actuals through June 2026.

| Field | Definition |
| --- | --- |
| `gl_row_id` | Stable row key |
| `month_start` | Posting month |
| `account_id` | Natural-account mapping |
| `department_id` | Finance owner |
| `region_id` | Reporting region |
| `customer_id` | Optional customer attribution |
| `project_id` | Optional project attribution |
| `business_line` | Subscription, Services, or Corporate |
| `amount_usd` | Positive presentation amount |
| `source_system` | Synthetic source-system label |
| `entry_type` | Business meaning of the entry |

### `fact_budget`

FY2026 budget at management-planning grain.

Fields: `budget_row_id`, `budget_version`, `month_start`, `account_id`,
`department_id`, `region_id`, `business_line`, `amount_usd`, and
`budget_driver`.

### `fact_forecast`

2026 Q2 6+6 forecast.

Fields: `forecast_row_id`, `forecast_version`, `month_start`, `account_id`,
`department_id`, `region_id`, `business_line`, `period_type`, `amount_usd`, and
`forecast_driver`.

`period_type` is `Actualized` for January-June and `Forecast` for July-December.

### `fact_invoice`

Subscription and services invoices through June 2026.

| Field | Definition |
| --- | --- |
| `invoice_id` | Stable invoice key |
| `customer_id` | Billed customer |
| `project_id` | Optional services project |
| `invoice_type` | Subscription or Professional Services |
| `issue_date` | Invoice date |
| `due_date` | Contractual due date |
| `paid_date` | Full-payment date if paid |
| `invoice_amount_usd` | Original amount |
| `amount_paid_usd` | Cash received |
| `outstanding_usd` | Remaining receivable |
| `invoice_status` | Paid, Open, Past Due, or Partially Paid |
| `payment_terms_days` | Contractual terms |
| `days_to_pay` | Issue-to-payment days for paid invoices |
| `as_of_date` | Aging cutoff |

## Governance tables

### `model_assumptions`

Assumption ID, category, name, value, unit, period, basis type, source ID, and
rationale.

### `model_sources`

Public source title, organization, period, URL, access date, model use, and
notes.

### `business_events`

Designed event month, name, affected area, and description.

## SQL views

| View | Purpose |
| --- | --- |
| `v_scenario_pnl_detail` | Unified Actual, Budget, and Q2 Forecast reporting layer |
| `v_monthly_pnl` | Monthly P&L and management subtotals |
| `v_arr_bridge_monthly` | ARR bridge and active customer count |
| `v_monthly_kpi` | Revenue, margin, ARR, FTE, and utilization |
| `v_customer_revenue_monthly` | Customer-level subscription and services revenue |
| `v_project_margin` | Project economics to date |
| `v_headcount_utilization` | Department/region workforce view |
| `v_ar_aging` | Open receivables and aging bucket |
| `v_variance_ytd` | Favorable YTD variance by P&L line |
