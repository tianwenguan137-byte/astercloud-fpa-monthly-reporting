#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATABASE_PATH="${PROJECT_DIR}/data/database/astercloud_fpa.sqlite"
OUTPUT_DIR="${PROJECT_DIR}/data/tableau"

mkdir -p "${OUTPUT_DIR}"

sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_scenario_pnl_detail;" > "${OUTPUT_DIR}/tableau_pnl_detail.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "
  SELECT
    month_start,
    scenario,
    pnl_line,
    statement_section,
    MIN(sort_order) AS sort_order,
    ROUND(SUM(amount_usd), 2) AS amount_usd
  FROM v_scenario_pnl_detail
  GROUP BY month_start, scenario, pnl_line, statement_section
  ORDER BY month_start, scenario, sort_order;
" > "${OUTPUT_DIR}/tableau_pnl_line_monthly.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_monthly_pnl ORDER BY month_start, scenario;" > "${OUTPUT_DIR}/tableau_monthly_pnl.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_monthly_kpi ORDER BY month_start;" > "${OUTPUT_DIR}/tableau_monthly_kpi.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_arr_bridge_monthly ORDER BY month_start;" > "${OUTPUT_DIR}/tableau_arr_bridge.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_customer_revenue_monthly;" > "${OUTPUT_DIR}/tableau_customer_revenue.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_project_margin ORDER BY gross_margin_pct;" > "${OUTPUT_DIR}/tableau_project_margin.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_headcount_utilization;" > "${OUTPUT_DIR}/tableau_headcount_utilization.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_ar_aging ORDER BY days_past_due DESC;" > "${OUTPUT_DIR}/tableau_ar_aging.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "SELECT * FROM v_variance_ytd ORDER BY ABS(favorable_variance_usd) DESC;" > "${OUTPUT_DIR}/tableau_variance_ytd.csv"
sqlite3 -header -csv "${DATABASE_PATH}" "
  WITH customer_ttm AS (
    SELECT
      customer_id,
      customer_name,
      segment,
      industry,
      region_name,
      SUM(subscription_revenue_usd) AS subscription_revenue_usd,
      SUM(services_revenue_usd) AS services_revenue_usd,
      SUM(total_revenue_usd) AS total_revenue_usd
    FROM v_customer_revenue_monthly
    WHERE month_start BETWEEN '2025-07-01' AND '2026-06-01'
    GROUP BY customer_id, customer_name, segment, industry, region_name
  )
  SELECT
    ROW_NUMBER() OVER (ORDER BY total_revenue_usd DESC) AS revenue_rank,
    customer_id,
    customer_name,
    segment,
    industry,
    region_name,
    ROUND(subscription_revenue_usd, 2) AS subscription_revenue_usd,
    ROUND(services_revenue_usd, 2) AS services_revenue_usd,
    ROUND(total_revenue_usd, 2) AS total_revenue_usd,
    ROUND(total_revenue_usd / SUM(total_revenue_usd) OVER (), 4) AS revenue_share
  FROM customer_ttm
  ORDER BY revenue_rank;
" > "${OUTPUT_DIR}/tableau_customer_ttm.csv"
sqlite3 -header -csv "${DATABASE_PATH}" < "${PROJECT_DIR}/sql/03_quality_checks.sql" > "${OUTPUT_DIR}/tableau_quality_checks.csv"

echo "Exported Tableau-ready CSV files to ${OUTPUT_DIR}"
