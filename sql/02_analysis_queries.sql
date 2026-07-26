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

