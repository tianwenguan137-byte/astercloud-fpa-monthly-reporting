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

