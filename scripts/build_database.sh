#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATABASE_PATH="${PROJECT_DIR}/data/database/astercloud_fpa.sqlite"
CSV_DIR="${PROJECT_DIR}/data/csv"

rm -f "${DATABASE_PATH}"
sqlite3 "${DATABASE_PATH}" < "${PROJECT_DIR}/sql/00_create_schema.sql"

sqlite3 "${DATABASE_PATH}" <<SQL
.bail on
.mode csv
.import --skip 1 "${CSV_DIR}/dim_date_month.csv" dim_date_month
.import --skip 1 "${CSV_DIR}/dim_region.csv" dim_region
.import --skip 1 "${CSV_DIR}/dim_department.csv" dim_department
.import --skip 1 "${CSV_DIR}/dim_account.csv" dim_account
.import --skip 1 "${CSV_DIR}/dim_customer.csv" dim_customer
.import --skip 1 "${CSV_DIR}/dim_project.csv" dim_project
.import --skip 1 "${CSV_DIR}/dim_employee.csv" dim_employee
.import --skip 1 "${CSV_DIR}/fact_subscription_mrr.csv" fact_subscription_mrr
.import --skip 1 "${CSV_DIR}/fact_headcount_monthly.csv" fact_headcount_monthly
.import --skip 1 "${CSV_DIR}/fact_utilization_monthly.csv" fact_utilization_monthly
.import --skip 1 "${CSV_DIR}/fact_project_financials.csv" fact_project_financials
.import --skip 1 "${CSV_DIR}/fact_gl_actuals.csv" fact_gl_actuals
.import --skip 1 "${CSV_DIR}/fact_budget.csv" fact_budget
.import --skip 1 "${CSV_DIR}/fact_forecast.csv" fact_forecast
.import --skip 1 "${CSV_DIR}/fact_invoice.csv" fact_invoice
.import --skip 1 "${CSV_DIR}/model_assumptions.csv" model_assumptions
.import --skip 1 "${CSV_DIR}/model_sources.csv" model_sources
.import --skip 1 "${CSV_DIR}/business_events.csv" business_events
.read "${PROJECT_DIR}/sql/01_create_views.sql"
PRAGMA foreign_keys = ON;
ANALYZE;
VACUUM;
SQL

echo "Built ${DATABASE_PATH}"

