


PRAGMA foreign_keys = ON;




-- ============================================================
-- PART 1: Source Data Audit
-- AsterCloud source-data audit
-- Purpose: understand and validate base tables before rebuilding any views.
-- ============================================================


-- 1. INVENTORY: WHICH BASE TABLES EXIST?
SELECT name AS table_name
FROM sqlite_schema
WHERE type = 'table'
AND name NOT LIKE 'sqlite%'
ORDER BY name;
/*OUTPUT:
business_events
dim_account
dim_customer
dim_date_month
dim_department
dim_employee
dim_project
dim_region
fact_budget
fact_forecast
fact_gl_actuals
fact_headcount_monthly
fact_invoice
fact_project_financials
fact_subscription_mrr
fact_utilization_monthly
model_assumptions
model_sources
*/

SELECT *
FROM pragma_foreign_key_list('sqlite_schema'); 
/*OUTPUT:
pragma_table_info: cid name type notnull dflt_value pk
pragma_foreign_key_list：id, seq, table, from, to, on_update, on_delete, match
*/

-- 2. FIELD INVENTORY: COLUMN, TYPE, REQUIRED FLAG, DECLARED PK
SELECT
  m.name AS table_name,
  p.cid AS colunm_order,
  p.name AS column_name,
  p.type AS data_type,
  p.[notnull] AS is_required,
  p.pk AS primary_key_order
FROM sqlite_schema AS m
JOIN pragma_table_info(m.name) as p
WHERE m.type = 'table'
	AND m.name NOT LIKE 'sqlite_%'
ORDER BY m.name, p.cid;

-- 3. ROW COUNTS: ESTABLISH TABLE SIZE BEFORE EXPLORING VALUES
SELECT 'business_events' AS table_name, COUNT(*) AS row_count FROM business_events
UNION ALL SELECT 'dim_account', COUNT(*) FROM dim_account
UNION ALL SELECT 'dim_customer', COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_date_month', COUNT(*) FROM dim_date_month
UNION ALL SELECT 'dim_department', COUNT(*) FROM dim_department
UNION ALL SELECT 'dim_employee', COUNT(*) FROM dim_employee
UNION ALL SELECT 'dim_project', COUNT(*) FROM dim_project
UNION ALL SELECT 'dim_region', COUNT(*) FROM dim_region
UNION ALL SELECT 'fact_budget', COUNT(*) FROM fact_budget
UNION ALL SELECT 'fact_forecast', COUNT(*) FROM fact_forecast
UNION ALL SELECT 'fact_gl_actuals', COUNT(*) FROM fact_gl_actuals
UNION ALL SELECT 'fact_headcount_monthly', COUNT(*) FROM fact_headcount_monthly
UNION ALL SELECT 'fact_invoice', COUNT(*) FROM fact_invoice
UNION ALL SELECT 'fact_project_financials', COUNT(*) FROM fact_project_financials
UNION ALL SELECT 'fact_subscription_mrr', COUNT(*) FROM fact_subscription_mrr
UNION ALL SELECT 'fact_utilization_monthly', COUNT(*) FROM fact_utilization_monthly
UNION ALL SELECT 'model_assumptions', COUNT(*) FROM model_assumptions
UNION ALL SELECT 'model_sources', COUNT(*) FROM model_sources
ORDER BY table_name;


-- Inspect a small sample from one table at a time
SELECT * FROM business_events LIMIT 5;
SELECT * FROM dim_account LIMIT 5;
SELECT * FROM dim_customer LIMIT 5; -- dimension_2
SELECT * FROM dim_date_month LIMIT 5;
SELECT * FROM dim_department LIMIT 5;
SELECT * FROM dim_employee LIMIT 5;
SELECT * FROM dim_project LIMIT 5; -- dimension_3
SELECT * FROM dim_region LIMIT 5; -- dimension_1
SELECT * FROM fact_budget LIMIT 5;
SELECT * FROM fact_forecast LIMIT 5;
SELECT * FROM fact_gl_actuals LIMIT 5;
SELECT * FROM fact_headcount_monthly LIMIT 5; -- employee-month grain_4
SELECT * FROM fact_invoice LIMIT 5;
SELECT * FROM fact_project_financials LIMIT 5;
SELECT * FROM fact_subscription_mrr LIMIT 5; -- customer-month grain_5
SELECT * FROM fact_utilization_monthly LIMIT 5; -- employee-month utilization grain_6
SELECT * FROM model_assumptions LIMIT 5;
SELECT * FROM model_sources LIMIT 5;


-- 4. CANDIDATE PRIMARY KEYS AND EXPECTED TABLE GRAIN
-- A zero-row result means no duplicate was found at that grain.
SELECT region_id, COUNT(*) AS duplicate_count
FROM dim_region
GROUP BY region_id
HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM dim_customer
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT project_id, COUNT(*) AS duplicate_count
FROM dim_project
GROUP BY project_id
HAVING COUNT(*) > 1;

SELECT employee_id, month_start, COUNT(*) AS duplicate_count
FROM fact_headcount_monthly
GROUP BY employee_id, month_start
HAVING COUNT(*) > 1;

SELECT customer_id, month_start, COUNT(*) AS duplicate_count
FROM fact_subscription_mrr
GROUP BY customer_id, month_start
HAVING COUNT(*) > 1;

SELECT employee_id, month_start, COUNT(*) AS duplicate_count
FROM fact_utilization_monthly
GROUP BY employee_id, month_start
HAVING COUNT(*) > 1;

SELECT 
  budget_version,
  month_start,
  account_id,
  department_id,
  region_id,
  business_line, COUNT(*) AS duplicate_count
FROM fact_budget
GROUP BY
  budget_version,
  month_start,
  account_id,
  department_id,
  region_id,
  business_line
HAVING COUNT(*) > 1;

SELECT 
  forecast_version,
  month_start,
  account_id,
  department_id,
  region_id,
  business_line, COUNT(*) AS duplicate_count
FROM fact_forecast
GROUP BY
  forecast_version,
  month_start,
  account_id,
  department_id,
  region_id,
  business_line
HAVING COUNT(*) > 1;


-- Display declared primary keys after testing candidate grain
SELECT 
  m.name AS table_name,
  GROUP_CONCAT(p.name, ', ') AS declared_primary_key
FROM sqlite_schema AS m
JOIN pragma_table_info(m.name) AS p
WHERE m.type = 'table'
  AND p.pk > 0
GROUP BY m.name
ORDER BY m.name;

-- 5. FOREIGN KEYS AND ORPHAN RECORDS
SELECT 
  m.name AS child_table,
  f.[from] AS children_column,
  f.[table] AS parent_table,
  f.[to] AS parent_column
FROM sqlite_schema AS m
JOIN pragma_foreign_key_list(m.name) AS f
WHERE m.type = 'table'
ORDER BY m.name, f.id;

-- A zero-row result means all declared foreign keys resolve.
PRAGMA foreign_key_check;

-- Manual orphan check.
SELECT m.customer_id
FROM fact_subscription_mrr AS m
LEFT JOIN dim_customer AS c
  ON m.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 6. STRUCTURAL AND ROW-LEVEL VALIDATION
-- Investigate failures first. Then adjust the threshold.
SELECT 
  'Region weights equal 1.0' AS check_name,
  ABS(SUM(revenue_weight) - 1.0) AS max_difference,
  0.0001 AS tolerance,
  CASE
  	WHEN ABS(SUM(revenue_weight) - 1.0) > 0.0001 THEN 1
  	ELSE 0
  END AS failing_rows  
FROM dim_region

UNION ALL 

SELECT
  'MRR roll-forward',
  MAX(
    ABS(
      ending_mrr_usd - 
      (
      opening_mrr_usd + 
      new_mrr_usd + 
      expansion_mrr_usd - 
      contraction_mrr_usd - 
      churn_mrr_usd
      )
     )
    ),
  0.011, 
  SUM(
    CASE
    	WHEN ABS(
    	  ending_mrr_usd - 
    	(
    	opening_mrr_usd + 
    	new_mrr_usd + 
    	expansion_mrr_usd - 
    	contraction_mrr_usd - 
    	churn_mrr_usd
    	)
    ) > 0.011 THEN 1
      ELSE 0
    END 
   ) AS failing_rows
FROM fact_subscription_mrr

UNION ALL 

SELECT
  'invoice_outstanding_equation',
  MAX(
   ABS(
   invoice_amount_usd - amount_paid_usd - outstanding_usd 
    )
   ),
   0.01,
   SUM(
    CASE
    	WHEN ABS(
   invoice_amount_usd - amount_paid_usd - outstanding_usd 
    )
    > 0.01
        THEN 1
     ELSE 0
    END )
FROM fact_invoice

UNION ALL 

SELECT
  'Headcount personnel-cost equation',
  MAX(
    ABS(
      total_personnel_cost_usd - 
        (
          monthly_base_salary_usd +
          bonus_accrual_usd + 
          benefits_usd +
          payroll_taxes_usd
       )
      )
     ),
     0.021,
     SUM(
       CASE 
       	  WHEN ABS(
          total_personnel_cost_usd - 
          (
          monthly_base_salary_usd +
          bonus_accrual_usd + 
          benefits_usd +
          payroll_taxes_usd
       )
      ) > 0.021 THEN 1
        ELSE 0
       END
     ) AS failing_row
FROM fact_headcount_monthly

UNION ALL 

SELECT 
  'Utilization hours equation',
  MAX(
    ABS(
      available_hours - (
        billable_hours +
        internal_hours +
        bench_hours )
        )
      ),
   0.11,
   SUM(
     CASE
     	WHEN ABS(
      available_hours - (
        billable_hours +
        internal_hours +
        bench_hours )
        ) > 0.11 THEN 1
          ELSE 0
     END
     ) AS failing_rows
FROM fact_utilization_monthly

UNION ALL 

SELECT
  'Project gross-profit equation',
  MAX(
    ABS(gross_profit_usd - (
        revenue_usd - 
        direct_labor_cost_usd -
        subcontractor_cost_usd -
        travel_cost_usd 
      ))),
   0.021,
   SUM(
     CASE
     	WHEN 
     	ABS(gross_profit_usd - (
        revenue_usd - 
        direct_labor_cost_usd -
        subcontractor_cost_usd -
        travel_cost_usd 
      )) > 0.021 THEN 1
      ELSE 0
     END
     ) AS failing_rows
FROM fact_project_financials; 

-- Range checks return only suspicious records.
SELECT *
FROM fact_headcount_monthly
WHERE fte <= 0 OR fte > 1;

SELECT *
FROM fact_utilization_monthly
WHERE available_hours < 0
   OR billable_hours < 0
   OR internal_hours < 0
   OR bench_hours < 0
   OR utilization_rate < 0
   OR utilization_rate > 1;

SELECT *
FROM fact_invoice
WHERE invoice_amount_usd < 0
   OR amount_paid_usd < 0
   OR outstanding_usd < 0
   OR amount_paid_usd > invoice_amount_usd;
-- Nulls below are not automatically errors:
-- dim_customer.churn_month: null means the customer has not churned.
-- dim_employee.end_month: null means the employee remains active.
-- fact_invoice.paid_date/days_to_pay: null is expected for unpaid invoices.
-- fact_invoice.project_id: null is expected for subscription invoices.
-- fact_gl_actuals.customer_id/project_id: applicability depends on entry type.


-- ============================================================
-- PART 2: Financial Reconciliation and Close Controls
-- Purpose: confirm source data is complete and financially reliable.
-- ============================================================
WITH checks AS (
  SELECT
    1 AS check_order,
    'Subscription revenue ties to GL' AS check_name,
    ROUND(
      (SELECT SUM(recognized_revenue_usd) FROM fact_subscription_mrr) -
      (SELECT SUM(amount_usd) FROM fact_gl_actuals WHERE account_id = 'A4000'),
      2
    ) AS difference,
    0.05 AS tolerance,
    'fact_subscription_mrr vs A4000' AS fix_location

  UNION ALL

  SELECT
    2,
    'Services revenue ties to GL',
    ROUND(
      (SELECT SUM(revenue_usd) FROM fact_project_financials) -
      (SELECT SUM(amount_usd) FROM fact_gl_actuals WHERE account_id IN ('A4010', 'A4020')),
      2
    ),
    0.05,
    'fact_project_financials vs A4010/A4020'

  UNION ALL

  SELECT
    3,
    'Services labor ties to payroll',
    ROUND(
      (SELECT SUM(total_personnel_cost_usd) FROM fact_headcount_monthly WHERE department_id = 'D03') -
      (SELECT SUM(amount_usd) FROM fact_gl_actuals WHERE account_id = 'A5020'),
      2
    ),
    0.05,
    'fact_headcount_monthly vs A5020'

  UNION ALL

  SELECT
    4,
    'Budget has twelve months',
    CAST((SELECT COUNT(DISTINCT month_start) FROM fact_budget) AS REAL) - 12,
    0,
    'fact_budget'

  UNION ALL

  SELECT
    5,
    'Forecast has twelve months',
    CAST((SELECT COUNT(DISTINCT month_start) FROM fact_forecast) AS REAL) - 12,
    0,
    'fact_forecast'

  UNION ALL

  SELECT
    6,
    'Invoices reconcile',
    ROUND(
      (SELECT SUM(invoice_amount_usd - amount_paid_usd - outstanding_usd) FROM fact_invoice),
      2
    ),
    0.05,
    'fact_invoice'

  UNION ALL

  SELECT
    7,
    'No negative MRR',
    CAST((SELECT COUNT(*) FROM fact_subscription_mrr WHERE ending_mrr_usd < 0) AS REAL),
    0,
    'fact_subscription_mrr'

  UNION ALL

  SELECT
    8,
    'No impossible utilization',
    CAST(
      (
        SELECT COUNT(*)
        FROM fact_utilization_monthly
        WHERE utilization_rate < 0 OR utilization_rate > 1 OR billable_hours > available_hours
      ) AS REAL
    ),
    0,
    'fact_utilization_monthly'

  UNION ALL

  SELECT
    9,
    'Foreign key integrity',
    CAST((SELECT COUNT(*) FROM pragma_foreign_key_check) AS REAL),
    0,
    'database schema'
)
SELECT
  check_order,
  check_name,
  difference,
  tolerance,
  CASE WHEN ABS(difference) <= tolerance THEN 'PASS' ELSE 'FAIL' END AS status,
  fix_location
FROM checks
ORDER BY check_order;




-- ============================================================
-- PART 3: Creat Views
-- ============================================================

DROP VIEW IF EXISTS v_variance_ytd;
DROP VIEW IF EXISTS v_ar_aging;
DROP VIEW IF EXISTS v_headcount_utilization;
DROP VIEW IF EXISTS v_project_margin;
DROP VIEW IF EXISTS v_customer_revenue_monthly;
DROP VIEW IF EXISTS v_monthly_kpi;
DROP VIEW IF EXISTS v_arr_bridge_monthly;
DROP VIEW IF EXISTS v_monthly_pnl;
DROP VIEW IF EXISTS v_scenario_pnl_detail;


CREATE VIEW v_scenario_pnl_detail AS
SELECT
  g.month_start,
  'Actual' AS scenario,
  a.account_id,
  a.account_code,
  a.account_name,
  a.statement_section,
  a.pnl_line,
  a.sort_order,
  d.department_id,
  d.department_name,
  d.function_group,
  r.region_id,
  r.region_name,
  g.business_line,
  g.customer_id,
  g.project_id,
  g.amount_usd
FROM fact_gl_actuals g
JOIN dim_account a ON a.account_id = g.account_id
JOIN dim_department d ON d.department_id = g.department_id
JOIN dim_region r ON r.region_id = g.region_id

UNION ALL

SELECT
  b.month_start,
  'Budget' AS scenario,
  a.account_id,
  a.account_code,
  a.account_name,
  a.statement_section,
  a.pnl_line,
  a.sort_order,
  d.department_id,
  d.department_name,
  d.function_group,
  r.region_id,
  r.region_name,
  b.business_line,
  '' AS customer_id,
  '' AS project_id,
  b.amount_usd
FROM fact_budget b
JOIN dim_account a ON a.account_id = b.account_id
JOIN dim_department d ON d.department_id = b.department_id
JOIN dim_region r ON r.region_id = b.region_id

UNION ALL

SELECT
  f.month_start,
  'Q2 Forecast' AS scenario,
  a.account_id,
  a.account_code,
  a.account_name,
  a.statement_section,
  a.pnl_line,
  a.sort_order,
  d.department_id,
  d.department_name,
  d.function_group,
  r.region_id,
  r.region_name,
  f.business_line,
  '' AS customer_id,
  '' AS project_id,
  f.amount_usd
FROM fact_forecast f
JOIN dim_account a ON a.account_id = f.account_id
JOIN dim_department d ON d.department_id = f.department_id
JOIN dim_region r ON r.region_id = f.region_id;

CREATE VIEW v_monthly_pnl AS
SELECT
  month_start,
  scenario,
  ROUND(SUM(CASE WHEN pnl_line = 'Subscription Revenue' THEN amount_usd ELSE 0 END), 2) AS subscription_revenue_usd,
  ROUND(SUM(CASE WHEN pnl_line = 'Professional Services Revenue' THEN amount_usd ELSE 0 END), 2) AS services_revenue_usd,
  ROUND(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 2) AS total_revenue_usd,
  ROUND(SUM(CASE WHEN pnl_line = 'Cost of Subscription' THEN amount_usd ELSE 0 END), 2) AS cost_of_subscription_usd,
  ROUND(SUM(CASE WHEN pnl_line = 'Cost of Services' THEN amount_usd ELSE 0 END), 2) AS cost_of_services_usd,
  ROUND(
    SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END) -
    SUM(CASE WHEN statement_section = 'Cost of Revenue' THEN amount_usd ELSE 0 END),
    2
  ) AS gross_profit_usd,
  ROUND(
    (
      SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END) -
      SUM(CASE WHEN statement_section = 'Cost of Revenue' THEN amount_usd ELSE 0 END)
    ) / NULLIF(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 0),
    4
  ) AS gross_margin_pct,
  ROUND(SUM(CASE WHEN pnl_line = 'Sales & Marketing' THEN amount_usd ELSE 0 END), 2) AS sales_marketing_usd,
  ROUND(SUM(CASE WHEN pnl_line = 'Research & Development' THEN amount_usd ELSE 0 END), 2) AS research_development_usd,
  ROUND(SUM(CASE WHEN pnl_line = 'General & Administrative' THEN amount_usd ELSE 0 END), 2) AS general_administrative_usd,
  ROUND(
    SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END) -
    SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense') THEN amount_usd ELSE 0 END),
    2
  ) AS adjusted_ebitda_usd,
  ROUND(
    (
      SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END) -
      SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense') THEN amount_usd ELSE 0 END)
    ) / NULLIF(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 0),
    4
  ) AS adjusted_ebitda_margin_pct,
  ROUND(SUM(CASE WHEN pnl_line = 'Depreciation & Amortization' THEN amount_usd ELSE 0 END), 2) AS depreciation_amortization_usd,
  ROUND(
    SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END) -
    SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense', 'D&A') THEN amount_usd ELSE 0 END),
    2
  ) AS operating_income_usd
FROM v_scenario_pnl_detail
GROUP BY month_start, scenario;

CREATE VIEW v_arr_bridge_monthly AS
SELECT
  month_start,
  ROUND(SUM(opening_mrr_usd) * 12, 2) AS opening_arr_usd,
  ROUND(SUM(new_mrr_usd) * 12, 2) AS new_arr_usd,
  ROUND(SUM(expansion_mrr_usd) * 12, 2) AS expansion_arr_usd,
  ROUND(SUM(contraction_mrr_usd) * 12, 2) AS contraction_arr_usd,
  ROUND(SUM(churn_mrr_usd) * 12, 2) AS churn_arr_usd,
  ROUND(SUM(ending_mrr_usd) * 12, 2) AS ending_arr_usd,
  COUNT(CASE WHEN ending_mrr_usd > 0 THEN 1 END) AS active_customers
FROM fact_subscription_mrr
GROUP BY month_start;

CREATE VIEW v_monthly_kpi AS
SELECT
  p.month_start,
  p.total_revenue_usd,
  p.gross_margin_pct,
  p.adjusted_ebitda_usd,
  p.adjusted_ebitda_margin_pct,
  a.ending_arr_usd,
  a.active_customers,
  ROUND((SELECT SUM(fte) FROM fact_headcount_monthly h WHERE h.month_start = p.month_start), 1) AS total_fte,
  ROUND(
    (
      SELECT SUM(u.billable_hours) / NULLIF(SUM(u.available_hours), 0)
      FROM fact_utilization_monthly u
      WHERE u.month_start = p.month_start
    ),
    4
  ) AS services_utilization_pct
FROM v_monthly_pnl p
JOIN v_arr_bridge_monthly a ON a.month_start = p.month_start
WHERE p.scenario = 'Actual';

CREATE VIEW v_customer_revenue_monthly AS
WITH services AS (
  SELECT month_start, customer_id, region_id, SUM(revenue_usd) AS services_revenue_usd
  FROM fact_project_financials
  GROUP BY month_start, customer_id, region_id
),
keys AS (
  SELECT month_start, customer_id, region_id FROM fact_subscription_mrr
  UNION
  SELECT month_start, customer_id, region_id FROM services
)
SELECT
  k.month_start,
  k.customer_id,
  c.customer_name,
  c.segment,
  c.industry,
  r.region_name,
  ROUND(COALESCE(s.recognized_revenue_usd, 0), 2) AS subscription_revenue_usd,
  ROUND(COALESCE(ps.services_revenue_usd, 0), 2) AS services_revenue_usd,
  ROUND(COALESCE(s.recognized_revenue_usd, 0) + COALESCE(ps.services_revenue_usd, 0), 2) AS total_revenue_usd,
  ROUND(COALESCE(s.ending_mrr_usd, 0) * 12, 2) AS ending_arr_usd
FROM keys k
JOIN dim_customer c ON c.customer_id = k.customer_id
JOIN dim_region r ON r.region_id = k.region_id
LEFT JOIN fact_subscription_mrr s
  ON s.month_start = k.month_start AND s.customer_id = k.customer_id
LEFT JOIN services ps
  ON ps.month_start = k.month_start AND ps.customer_id = k.customer_id;

CREATE VIEW v_project_margin AS
SELECT
  p.project_id,
  c.customer_name,
  c.segment,
  r.region_name,
  p.project_type,
  p.contract_type,
  p.start_month,
  p.planned_end_month,
  p.status,
  ROUND(SUM(f.revenue_usd), 2) AS revenue_to_date_usd,
  ROUND(SUM(f.direct_labor_cost_usd), 2) AS direct_labor_cost_usd,
  ROUND(SUM(f.subcontractor_cost_usd), 2) AS subcontractor_cost_usd,
  ROUND(SUM(f.travel_cost_usd), 2) AS travel_cost_usd,
  ROUND(SUM(f.gross_profit_usd), 2) AS gross_profit_usd,
  ROUND(SUM(f.gross_profit_usd) / NULLIF(SUM(f.revenue_usd), 0), 4) AS gross_margin_pct,
  ROUND(SUM(f.revenue_usd) / NULLIF(SUM(f.billable_hours), 0), 2) AS realized_bill_rate_usd
FROM dim_project p
JOIN dim_customer c ON c.customer_id = p.customer_id
JOIN dim_region r ON r.region_id = p.region_id
JOIN fact_project_financials f ON f.project_id = p.project_id
GROUP BY
  p.project_id, c.customer_name, c.segment, r.region_name, p.project_type,
  p.contract_type, p.start_month, p.planned_end_month, p.status;

CREATE VIEW v_headcount_utilization AS
WITH hc AS (
  SELECT
    h.month_start,
    h.department_id,
    h.region_id,
    SUM(h.fte) AS fte,
    SUM(h.total_personnel_cost_usd) AS personnel_cost_usd
  FROM fact_headcount_monthly h
  GROUP BY h.month_start, h.department_id, h.region_id
),
util AS (
  SELECT
    month_start,
    region_id,
    SUM(billable_hours) AS billable_hours,
    SUM(available_hours) AS available_hours
  FROM fact_utilization_monthly
  GROUP BY month_start, region_id
)
SELECT
  hc.month_start,
  d.department_name,
  d.function_group,
  r.region_name,
  ROUND(hc.fte, 1) AS fte,
  ROUND(hc.personnel_cost_usd, 2) AS personnel_cost_usd,
  CASE
    WHEN hc.department_id = 'D03'
      THEN ROUND(util.billable_hours / NULLIF(util.available_hours, 0), 4)
    ELSE NULL
  END AS services_utilization_pct
FROM hc
JOIN dim_department d ON d.department_id = hc.department_id
JOIN dim_region r ON r.region_id = hc.region_id
LEFT JOIN util ON util.month_start = hc.month_start AND util.region_id = hc.region_id;

CREATE VIEW v_ar_aging AS
SELECT
  i.invoice_id,
  i.customer_id,
  c.customer_name,
  c.segment,
  r.region_name,
  i.project_id,
  i.invoice_type,
  i.issue_date,
  i.due_date,
  i.invoice_amount_usd,
  i.amount_paid_usd,
  i.outstanding_usd,
  i.invoice_status,
  CAST(julianday(i.as_of_date) - julianday(i.due_date) AS INTEGER) AS days_past_due,
  CASE
    WHEN julianday(i.as_of_date) <= julianday(i.due_date) THEN 'Current'
    WHEN julianday(i.as_of_date) - julianday(i.due_date) <= 30 THEN '1-30 days'
    WHEN julianday(i.as_of_date) - julianday(i.due_date) <= 60 THEN '31-60 days'
    WHEN julianday(i.as_of_date) - julianday(i.due_date) <= 90 THEN '61-90 days'
    ELSE '90+ days'
  END AS aging_bucket,
  i.as_of_date
FROM fact_invoice i
JOIN dim_customer c ON c.customer_id = i.customer_id
JOIN dim_region r ON r.region_id = c.region_id
WHERE i.outstanding_usd > 0;

CREATE VIEW v_variance_ytd AS
WITH actual AS (
  SELECT pnl_line, SUM(amount_usd) AS amount_usd
  FROM v_scenario_pnl_detail
  WHERE scenario = 'Actual'
    AND month_start BETWEEN '2026-01-01' AND '2026-06-01'
  GROUP BY pnl_line
),
budget AS (
  SELECT pnl_line, SUM(amount_usd) AS amount_usd
  FROM v_scenario_pnl_detail
  WHERE scenario = 'Budget'
    AND month_start BETWEEN '2026-01-01' AND '2026-06-01'
  GROUP BY pnl_line
)
SELECT
  a.pnl_line,
  ROUND(COALESCE(actual.amount_usd, 0), 2) AS actual_ytd_usd,
  ROUND(COALESCE(budget.amount_usd, 0), 2) AS budget_ytd_usd,
  ROUND(
    CASE
      WHEN a.statement_section = 'Revenue'
        THEN COALESCE(actual.amount_usd, 0) - COALESCE(budget.amount_usd, 0)
      ELSE COALESCE(budget.amount_usd, 0) - COALESCE(actual.amount_usd, 0)
    END,
    2
  ) AS favorable_variance_usd,
  ROUND(
    (
      CASE
        WHEN a.statement_section = 'Revenue'
          THEN COALESCE(actual.amount_usd, 0) - COALESCE(budget.amount_usd, 0)
        ELSE COALESCE(budget.amount_usd, 0) - COALESCE(actual.amount_usd, 0)
      END
    ) / NULLIF(COALESCE(budget.amount_usd, 0), 0),
    4
  ) AS favorable_variance_pct
FROM (
  SELECT DISTINCT pnl_line, statement_section
  FROM dim_account
  WHERE pnl_line <> 'Depreciation & Amortization'
) a
LEFT JOIN actual ON actual.pnl_line = a.pnl_line
LEFT JOIN budget ON budget.pnl_line = a.pnl_line;



-- ============================================================
-- PART 4: Analysis Queries
-- ============================================================

-- 1. Monthly P&L: Actual versus Budget versus Q2 Forecast
SELECT *
FROM v_monthly_pnl
WHERE month_start >= '2026-01-01'
ORDER BY month_start, scenario;

-- 2. YTD favorable / unfavorable variance by P&L line
SELECT
  pnl_line,
  actual_ytd_usd,
  budget_ytd_usd,
  favorable_variance_usd,
  favorable_variance_pct,
  CASE WHEN favorable_variance_usd >= 0 THEN 'Favorable' ELSE 'Unfavorable' END AS variance_status
FROM v_variance_ytd
ORDER BY ABS(favorable_variance_usd) DESC;

-- 3. ARR bridge and customer count
SELECT *
FROM v_arr_bridge_monthly
WHERE month_start >= '2025-01-01'
ORDER BY month_start;

-- 4. Revenue concentration by customer for the trailing twelve months
WITH customer_ttm AS (
  SELECT customer_id, customer_name, segment, SUM(total_revenue_usd) AS revenue_ttm_usd
  FROM v_customer_revenue_monthly
  WHERE month_start BETWEEN '2025-07-01' AND '2026-06-01'
  GROUP BY customer_id, customer_name, segment
),
ranked AS (
  SELECT
    *,
    SUM(revenue_ttm_usd) OVER () AS company_revenue_ttm_usd,
    ROW_NUMBER() OVER (ORDER BY revenue_ttm_usd DESC) AS revenue_rank
  FROM customer_ttm
)
SELECT
  revenue_rank,
  customer_id,
  customer_name,
  segment,
  ROUND(revenue_ttm_usd, 2) AS revenue_ttm_usd,
  ROUND(revenue_ttm_usd / company_revenue_ttm_usd, 4) AS revenue_share
FROM ranked
WHERE revenue_rank <= 15
ORDER BY revenue_rank;

-- 5. Services project margin exceptions
SELECT
  project_id,
  customer_name,
  project_type,
  contract_type,
  revenue_to_date_usd,
  gross_margin_pct,
  realized_bill_rate_usd
FROM v_project_margin
WHERE revenue_to_date_usd >= 100000
ORDER BY gross_margin_pct ASC
LIMIT 20;

-- 6. Headcount and utilization trend
SELECT
  month_start,
  SUM(fte) AS total_fte,
  SUM(CASE WHEN department_name = 'Professional Services' THEN fte ELSE 0 END) AS services_fte,
  ROUND(
    SUM(CASE WHEN department_name = 'Professional Services' THEN personnel_cost_usd ELSE 0 END),
    2
  ) AS services_personnel_cost_usd,
  ROUND(MAX(services_utilization_pct), 4) AS services_utilization_pct
FROM v_headcount_utilization
WHERE month_start >= '2025-01-01'
GROUP BY month_start
ORDER BY month_start;

-- 7. AR aging and concentration
SELECT
  aging_bucket,
  COUNT(*) AS invoice_count,
  ROUND(SUM(outstanding_usd), 2) AS outstanding_usd,
  ROUND(SUM(outstanding_usd) / SUM(SUM(outstanding_usd)) OVER (), 4) AS share_of_open_ar
FROM v_ar_aging
GROUP BY aging_bucket
ORDER BY
  CASE aging_bucket
    WHEN 'Current' THEN 1
    WHEN '1-30 days' THEN 2
    WHEN '31-60 days' THEN 3
    WHEN '61-90 days' THEN 4
    ELSE 5
  END;





