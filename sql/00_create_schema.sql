PRAGMA foreign_keys = OFF;

DROP VIEW IF EXISTS v_variance_ytd;
DROP VIEW IF EXISTS v_ar_aging;
DROP VIEW IF EXISTS v_headcount_utilization;
DROP VIEW IF EXISTS v_project_margin;
DROP VIEW IF EXISTS v_customer_revenue_monthly;
DROP VIEW IF EXISTS v_monthly_kpi;
DROP VIEW IF EXISTS v_arr_bridge_monthly;
DROP VIEW IF EXISTS v_monthly_pnl;
DROP VIEW IF EXISTS v_scenario_pnl_detail;

DROP TABLE IF EXISTS business_events;
DROP TABLE IF EXISTS model_sources;
DROP TABLE IF EXISTS model_assumptions;
DROP TABLE IF EXISTS fact_invoice;
DROP TABLE IF EXISTS fact_forecast;
DROP TABLE IF EXISTS fact_budget;
DROP TABLE IF EXISTS fact_gl_actuals;
DROP TABLE IF EXISTS fact_project_financials;
DROP TABLE IF EXISTS fact_utilization_monthly;
DROP TABLE IF EXISTS fact_headcount_monthly;
DROP TABLE IF EXISTS fact_subscription_mrr;
DROP TABLE IF EXISTS dim_employee;
DROP TABLE IF EXISTS dim_project;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_account;
DROP TABLE IF EXISTS dim_department;
DROP TABLE IF EXISTS dim_region;
DROP TABLE IF EXISTS dim_date_month;

CREATE TABLE dim_date_month (
  month_start TEXT PRIMARY KEY,
  calendar_year INTEGER NOT NULL,
  calendar_quarter TEXT NOT NULL,
  month_number INTEGER NOT NULL,
  month_name TEXT NOT NULL,
  fiscal_year TEXT NOT NULL,
  fiscal_quarter TEXT NOT NULL,
  period_status TEXT NOT NULL
);

CREATE TABLE dim_region (
  region_id TEXT PRIMARY KEY,
  region_name TEXT NOT NULL,
  primary_hub TEXT NOT NULL,
  country TEXT NOT NULL,
  currency TEXT NOT NULL,
  salary_index REAL NOT NULL,
  revenue_weight REAL NOT NULL
);

CREATE TABLE dim_department (
  department_id TEXT PRIMARY KEY,
  department_name TEXT NOT NULL,
  function_group TEXT NOT NULL,
  cost_center TEXT NOT NULL,
  budget_owner TEXT NOT NULL
);

CREATE TABLE dim_account (
  account_id TEXT PRIMARY KEY,
  account_code TEXT NOT NULL UNIQUE,
  account_name TEXT NOT NULL,
  statement_section TEXT NOT NULL,
  pnl_line TEXT NOT NULL,
  business_line TEXT NOT NULL,
  natural_balance TEXT NOT NULL,
  favorable_direction TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);

CREATE TABLE dim_customer (
  customer_id TEXT PRIMARY KEY,
  customer_name TEXT NOT NULL UNIQUE,
  industry TEXT NOT NULL,
  segment TEXT NOT NULL,
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  contract_start_month TEXT NOT NULL,
  renewal_month INTEGER NOT NULL,
  billing_cadence TEXT NOT NULL,
  payment_terms_days INTEGER NOT NULL,
  credit_risk_tier TEXT NOT NULL,
  initial_acv_usd REAL NOT NULL,
  churn_month TEXT,
  current_arr_usd REAL NOT NULL
);

CREATE TABLE dim_project (
  project_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  project_type TEXT NOT NULL,
  contract_type TEXT NOT NULL,
  start_month TEXT NOT NULL,
  planned_end_month TEXT NOT NULL,
  status TEXT NOT NULL,
  contract_value_usd REAL NOT NULL,
  blended_bill_rate_usd REAL NOT NULL,
  actual_margin_pct REAL NOT NULL
);

CREATE TABLE dim_employee (
  employee_id TEXT PRIMARY KEY,
  department_id TEXT NOT NULL REFERENCES dim_department(department_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  job_family TEXT NOT NULL,
  level TEXT NOT NULL,
  employment_type TEXT NOT NULL,
  start_month TEXT NOT NULL,
  end_month TEXT,
  annual_base_salary_at_hire_usd REAL NOT NULL
);

CREATE TABLE fact_subscription_mrr (
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  segment TEXT NOT NULL,
  plan_tier TEXT NOT NULL,
  opening_mrr_usd REAL NOT NULL,
  new_mrr_usd REAL NOT NULL,
  expansion_mrr_usd REAL NOT NULL,
  contraction_mrr_usd REAL NOT NULL,
  churn_mrr_usd REAL NOT NULL,
  ending_mrr_usd REAL NOT NULL,
  recognized_revenue_usd REAL NOT NULL,
  PRIMARY KEY (month_start, customer_id)
);

CREATE TABLE fact_headcount_monthly (
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  employee_id TEXT NOT NULL REFERENCES dim_employee(employee_id),
  department_id TEXT NOT NULL REFERENCES dim_department(department_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  fte REAL NOT NULL,
  monthly_base_salary_usd REAL NOT NULL,
  bonus_accrual_usd REAL NOT NULL,
  benefits_usd REAL NOT NULL,
  payroll_taxes_usd REAL NOT NULL,
  total_personnel_cost_usd REAL NOT NULL,
  PRIMARY KEY (month_start, employee_id)
);

CREATE TABLE fact_utilization_monthly (
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  employee_id TEXT NOT NULL REFERENCES dim_employee(employee_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  available_hours REAL NOT NULL,
  billable_hours REAL NOT NULL,
  internal_hours REAL NOT NULL,
  bench_hours REAL NOT NULL,
  utilization_rate REAL NOT NULL,
  PRIMARY KEY (month_start, employee_id)
);

CREATE TABLE fact_project_financials (
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  project_id TEXT NOT NULL REFERENCES dim_project(project_id),
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  revenue_usd REAL NOT NULL,
  direct_labor_cost_usd REAL NOT NULL,
  subcontractor_cost_usd REAL NOT NULL,
  travel_cost_usd REAL NOT NULL,
  gross_profit_usd REAL NOT NULL,
  billable_hours REAL NOT NULL,
  PRIMARY KEY (month_start, project_id)
);

CREATE TABLE fact_gl_actuals (
  gl_row_id TEXT PRIMARY KEY,
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  account_id TEXT NOT NULL REFERENCES dim_account(account_id),
  department_id TEXT NOT NULL REFERENCES dim_department(department_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  customer_id TEXT,
  project_id TEXT,
  business_line TEXT NOT NULL,
  amount_usd REAL NOT NULL,
  source_system TEXT NOT NULL,
  entry_type TEXT NOT NULL
);

CREATE TABLE fact_budget (
  budget_row_id TEXT PRIMARY KEY,
  budget_version TEXT NOT NULL,
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  account_id TEXT NOT NULL REFERENCES dim_account(account_id),
  department_id TEXT NOT NULL REFERENCES dim_department(department_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  business_line TEXT NOT NULL,
  amount_usd REAL NOT NULL,
  budget_driver TEXT NOT NULL
);

CREATE TABLE fact_forecast (
  forecast_row_id TEXT PRIMARY KEY,
  forecast_version TEXT NOT NULL,
  month_start TEXT NOT NULL REFERENCES dim_date_month(month_start),
  account_id TEXT NOT NULL REFERENCES dim_account(account_id),
  department_id TEXT NOT NULL REFERENCES dim_department(department_id),
  region_id TEXT NOT NULL REFERENCES dim_region(region_id),
  business_line TEXT NOT NULL,
  period_type TEXT NOT NULL,
  amount_usd REAL NOT NULL,
  forecast_driver TEXT NOT NULL
);

CREATE TABLE fact_invoice (
  invoice_id TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES dim_customer(customer_id),
  project_id TEXT,
  invoice_type TEXT NOT NULL,
  issue_date TEXT NOT NULL,
  due_date TEXT NOT NULL,
  paid_date TEXT,
  invoice_amount_usd REAL NOT NULL,
  amount_paid_usd REAL NOT NULL,
  outstanding_usd REAL NOT NULL,
  invoice_status TEXT NOT NULL,
  payment_terms_days INTEGER NOT NULL,
  days_to_pay INTEGER,
  as_of_date TEXT NOT NULL
);

CREATE TABLE model_assumptions (
  assumption_id TEXT PRIMARY KEY,
  category TEXT NOT NULL,
  assumption_name TEXT NOT NULL,
  value TEXT NOT NULL,
  unit TEXT NOT NULL,
  period TEXT NOT NULL,
  basis_type TEXT NOT NULL,
  source_id TEXT,
  rationale TEXT NOT NULL
);

CREATE TABLE model_sources (
  source_id TEXT PRIMARY KEY,
  source_title TEXT NOT NULL,
  organization TEXT NOT NULL,
  source_period TEXT NOT NULL,
  url TEXT NOT NULL,
  accessed_date TEXT NOT NULL,
  use_in_model TEXT NOT NULL,
  notes TEXT NOT NULL
);

CREATE TABLE business_events (
  event_id TEXT PRIMARY KEY,
  event_month TEXT NOT NULL,
  event_name TEXT NOT NULL,
  affected_area TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE INDEX idx_gl_month_account ON fact_gl_actuals(month_start, account_id);
CREATE INDEX idx_gl_customer ON fact_gl_actuals(customer_id);
CREATE INDEX idx_budget_month_account ON fact_budget(month_start, account_id);
CREATE INDEX idx_forecast_month_account ON fact_forecast(month_start, account_id);
CREATE INDEX idx_subscription_month_customer ON fact_subscription_mrr(month_start, customer_id);
CREATE INDEX idx_project_month ON fact_project_financials(month_start, project_id);
CREATE INDEX idx_headcount_month_department ON fact_headcount_monthly(month_start, department_id);
CREATE INDEX idx_invoice_due_status ON fact_invoice(due_date, invoice_status);

