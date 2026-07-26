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

