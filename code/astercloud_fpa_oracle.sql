SELECT table_name
FROM user_tables
ORDER BY table_name;
/*
===============================================================================
AsterCloud Monthly FP&A Reporting - Oracle SQL / PL/SQL Implementation
===============================================================================

Purpose
  Rebuild the same synthetic AsterCloud FP&A case in Oracle to demonstrate
  enterprise SQL skills alongside the published SQLite implementation.

Target
  Oracle Database 19c or later. Run as a script from DBeaver (Alt+X).

Execution order
  1. Run PART 0 once in an empty Oracle schema.
  2. Import data/raw with DBeaver in the order documented below.
  3. Run PART 1 and PART 2; investigate non-zero or FAIL results.
  4. Run PART 3 to create or refresh reporting views.
  5. Run PART 4 for management analysis.
  6. Optionally run PART 5 for PL/SQL close-control automation.

CSV import notes
  - Map date columns as Oracle DATE with input pattern YYYY-MM-DD.
  - Map dim_employee.level to dim_employee.employee_level.
  - Map model_assumptions.value to model_assumptions.assumption_value.
  - Oracle treats empty strings as NULL. Nullable IDs and dates are expected.

No real employer data is included. In production these sections would normally
be separated into migrations, transformations, controls, and reporting scripts.
===============================================================================
*/

ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';


-- =============================================================================
-- PART 0: ORACLE SCHEMA, CONSTRAINTS, AND INDEXES
-- Run once before importing the CSV files.
-- =============================================================================

CREATE TABLE dim_date_month (
    month_start       DATE          NOT NULL,
    calendar_year     NUMBER(4)     NOT NULL,
    calendar_quarter  VARCHAR2(10)  NOT NULL,
    month_number      NUMBER(2)     NOT NULL,
    month_name        VARCHAR2(20)  NOT NULL,
    fiscal_year       VARCHAR2(10)  NOT NULL,
    fiscal_quarter    VARCHAR2(10)  NOT NULL,
    period_status     VARCHAR2(20)  NOT NULL,
    CONSTRAINT pk_date_month PRIMARY KEY (month_start),
    CONSTRAINT ck_month_number CHECK (month_number BETWEEN 1 AND 12)
);

CREATE TABLE dim_region (
    region_id       VARCHAR2(20)   NOT NULL,
    region_name     VARCHAR2(100)  NOT NULL,
    primary_hub     VARCHAR2(100)  NOT NULL,
    country         VARCHAR2(100)  NOT NULL,
    currency        VARCHAR2(10)   NOT NULL,
    salary_index    NUMBER(12,6)   NOT NULL,
    revenue_weight  NUMBER(12,6)   NOT NULL,
    CONSTRAINT pk_region PRIMARY KEY (region_id),
    CONSTRAINT ck_salary_index CHECK (salary_index > 0),
    CONSTRAINT ck_revenue_weight CHECK (revenue_weight BETWEEN 0 AND 1)
);

CREATE TABLE dim_department (
    department_id    VARCHAR2(20)   NOT NULL,
    department_name  VARCHAR2(100)  NOT NULL,
    function_group   VARCHAR2(100)  NOT NULL,
    cost_center      VARCHAR2(30)   NOT NULL,
    budget_owner     VARCHAR2(100)  NOT NULL,
    CONSTRAINT pk_department PRIMARY KEY (department_id),
    CONSTRAINT uq_cost_center UNIQUE (cost_center)
);

CREATE TABLE dim_account (
    account_id           VARCHAR2(20)   NOT NULL,
    account_code         VARCHAR2(30)   NOT NULL,
    account_name         VARCHAR2(150)  NOT NULL,
    statement_section    VARCHAR2(50)   NOT NULL,
    pnl_line             VARCHAR2(100)  NOT NULL,
    business_line        VARCHAR2(50)   NOT NULL,
    natural_balance      VARCHAR2(20)   NOT NULL,
    favorable_direction  VARCHAR2(20)   NOT NULL,
    sort_order           NUMBER(6)      NOT NULL,
    CONSTRAINT pk_account PRIMARY KEY (account_id),
    CONSTRAINT uq_account_code UNIQUE (account_code),
    CONSTRAINT ck_natural_balance CHECK (natural_balance IN ('Debit', 'Credit')),
    CONSTRAINT ck_favorable_dir CHECK (favorable_direction IN ('Higher is favorable', 'Lower is favorable'))
);

CREATE TABLE model_sources (
    source_id       VARCHAR2(30)    NOT NULL,
    source_title    VARCHAR2(300)   NOT NULL,
    organization    VARCHAR2(200)   NOT NULL,
    source_period   VARCHAR2(100)   NOT NULL,
    url             VARCHAR2(1000)  NOT NULL,
    accessed_date   DATE            NOT NULL,
    use_in_model    VARCHAR2(1000)  NOT NULL,
    notes           VARCHAR2(1000)  NOT NULL,
    CONSTRAINT pk_model_sources PRIMARY KEY (source_id)
);

CREATE TABLE business_events (
    event_id       VARCHAR2(30)    NOT NULL,
    event_month    DATE            NOT NULL,
    event_name     VARCHAR2(200)   NOT NULL,
    affected_area  VARCHAR2(100)   NOT NULL,
    description    VARCHAR2(1000)  NOT NULL,
    CONSTRAINT pk_business_events PRIMARY KEY (event_id)
);

CREATE TABLE dim_customer (
    customer_id          VARCHAR2(30)   NOT NULL,
    customer_name        VARCHAR2(200)  NOT NULL,
    industry             VARCHAR2(100)  NOT NULL,
    segment              VARCHAR2(50)   NOT NULL,
    region_id            VARCHAR2(20)   NOT NULL,
    contract_start_month DATE           NOT NULL,
    renewal_month        NUMBER(2)      NOT NULL,
    billing_cadence      VARCHAR2(30)   NOT NULL,
    payment_terms_days   NUMBER(4)      NOT NULL,
    credit_risk_tier     VARCHAR2(30)   NOT NULL,
    initial_acv_usd      NUMBER(18,2)   NOT NULL,
    churn_month          DATE,
    current_arr_usd      NUMBER(18,2)   NOT NULL,
    CONSTRAINT pk_customer PRIMARY KEY (customer_id),
    CONSTRAINT uq_customer_name UNIQUE (customer_name),
    CONSTRAINT fk_customer_region FOREIGN KEY (region_id)
        REFERENCES dim_region (region_id),
    CONSTRAINT ck_renewal_month CHECK (renewal_month BETWEEN 1 AND 12),
    CONSTRAINT ck_customer_amounts CHECK (initial_acv_usd >= 0 AND current_arr_usd >= 0)
);

CREATE TABLE dim_employee (
    employee_id                    VARCHAR2(30)   NOT NULL,
    department_id                  VARCHAR2(20)   NOT NULL,
    region_id                      VARCHAR2(20)   NOT NULL,
    job_family                     VARCHAR2(100)  NOT NULL,
    employee_level                 VARCHAR2(30)   NOT NULL,
    employment_type                VARCHAR2(30)   NOT NULL,
    start_month                    DATE           NOT NULL,
    end_month                      DATE,
    annual_base_salary_at_hire_usd NUMBER(18,2)   NOT NULL,
    CONSTRAINT pk_employee PRIMARY KEY (employee_id),
    CONSTRAINT fk_employee_dept FOREIGN KEY (department_id)
        REFERENCES dim_department (department_id),
    CONSTRAINT fk_employee_region FOREIGN KEY (region_id)
        REFERENCES dim_region (region_id),
    CONSTRAINT ck_employee_dates CHECK (end_month IS NULL OR end_month >= start_month),
    CONSTRAINT ck_employee_salary CHECK (annual_base_salary_at_hire_usd >= 0)
);

CREATE TABLE dim_project (
    project_id             VARCHAR2(30)   NOT NULL,
    customer_id            VARCHAR2(30)   NOT NULL,
    region_id              VARCHAR2(20)   NOT NULL,
    project_type           VARCHAR2(100)  NOT NULL,
    contract_type          VARCHAR2(50)   NOT NULL,
    start_month            DATE           NOT NULL,
    planned_end_month      DATE           NOT NULL,
    status                 VARCHAR2(30)   NOT NULL,
    contract_value_usd     NUMBER(18,2)   NOT NULL,
    blended_bill_rate_usd  NUMBER(18,2)   NOT NULL,
    actual_margin_pct      NUMBER(12,6)   NOT NULL,
    CONSTRAINT pk_project PRIMARY KEY (project_id),
    CONSTRAINT fk_project_customer FOREIGN KEY (customer_id)
        REFERENCES dim_customer (customer_id),
    CONSTRAINT fk_project_region FOREIGN KEY (region_id)
        REFERENCES dim_region (region_id),
    CONSTRAINT ck_project_dates CHECK (planned_end_month >= start_month),
    CONSTRAINT ck_project_value CHECK (contract_value_usd >= 0 AND blended_bill_rate_usd >= 0)
);

CREATE TABLE model_assumptions (
    assumption_id     VARCHAR2(30)    NOT NULL,
    category          VARCHAR2(100)   NOT NULL,
    assumption_name   VARCHAR2(300)   NOT NULL,
    assumption_value  VARCHAR2(300)   NOT NULL,
    unit              VARCHAR2(100)   NOT NULL,
    period            VARCHAR2(100)   NOT NULL,
    basis_type        VARCHAR2(100)   NOT NULL,
    source_id         VARCHAR2(30),
    rationale         VARCHAR2(1000)  NOT NULL,
    CONSTRAINT pk_model_assumptions PRIMARY KEY (assumption_id),
    CONSTRAINT fk_assumption_source FOREIGN KEY (source_id)
        REFERENCES model_sources (source_id)
);

CREATE TABLE fact_subscription_mrr (
    month_start           DATE          NOT NULL,
    customer_id           VARCHAR2(30)  NOT NULL,
    region_id             VARCHAR2(20)  NOT NULL,
    segment               VARCHAR2(50)  NOT NULL,
    plan_tier             VARCHAR2(50)  NOT NULL,
    opening_mrr_usd       NUMBER(18,2)  NOT NULL,
    new_mrr_usd           NUMBER(18,2)  NOT NULL,
    expansion_mrr_usd     NUMBER(18,2)  NOT NULL,
    contraction_mrr_usd   NUMBER(18,2)  NOT NULL,
    churn_mrr_usd         NUMBER(18,2)  NOT NULL,
    ending_mrr_usd        NUMBER(18,2)  NOT NULL,
    recognized_revenue_usd NUMBER(18,2) NOT NULL,
    CONSTRAINT pk_subscription_mrr PRIMARY KEY (month_start, customer_id),
    CONSTRAINT fk_mrr_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_mrr_customer FOREIGN KEY (customer_id) REFERENCES dim_customer,
    CONSTRAINT fk_mrr_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT ck_mrr_nonnegative CHECK (
        opening_mrr_usd >= 0 AND new_mrr_usd >= 0 AND expansion_mrr_usd >= 0
        AND contraction_mrr_usd >= 0 AND churn_mrr_usd >= 0
        AND ending_mrr_usd >= 0 AND recognized_revenue_usd >= 0
    ),
    CONSTRAINT ck_mrr_rollforward CHECK (
        ABS(ending_mrr_usd - (opening_mrr_usd + new_mrr_usd + expansion_mrr_usd
            - contraction_mrr_usd - churn_mrr_usd)) <= 0.02
    )
);

CREATE TABLE fact_headcount_monthly (
    month_start              DATE          NOT NULL,
    employee_id              VARCHAR2(30)  NOT NULL,
    department_id            VARCHAR2(20)  NOT NULL,
    region_id                VARCHAR2(20)  NOT NULL,
    fte                      NUMBER(8,4)   NOT NULL,
    monthly_base_salary_usd  NUMBER(18,2)  NOT NULL,
    bonus_accrual_usd        NUMBER(18,2)  NOT NULL,
    benefits_usd             NUMBER(18,2)  NOT NULL,
    payroll_taxes_usd        NUMBER(18,2)  NOT NULL,
    total_personnel_cost_usd NUMBER(18,2)  NOT NULL,
    CONSTRAINT pk_headcount_monthly PRIMARY KEY (month_start, employee_id),
    CONSTRAINT fk_hc_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_hc_employee FOREIGN KEY (employee_id) REFERENCES dim_employee,
    CONSTRAINT fk_hc_department FOREIGN KEY (department_id) REFERENCES dim_department,
    CONSTRAINT fk_hc_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT ck_hc_fte CHECK (fte > 0 AND fte <= 1),
    CONSTRAINT ck_hc_cost CHECK (
        ABS(total_personnel_cost_usd - (monthly_base_salary_usd + bonus_accrual_usd
            + benefits_usd + payroll_taxes_usd)) <= 0.03
    )
);

CREATE TABLE fact_utilization_monthly (
    month_start       DATE          NOT NULL,
    employee_id       VARCHAR2(30)  NOT NULL,
    region_id         VARCHAR2(20)  NOT NULL,
    available_hours   NUMBER(12,2)  NOT NULL,
    billable_hours    NUMBER(12,2)  NOT NULL,
    internal_hours    NUMBER(12,2)  NOT NULL,
    bench_hours       NUMBER(12,2)  NOT NULL,
    utilization_rate  NUMBER(12,6)  NOT NULL,
    CONSTRAINT pk_util_monthly PRIMARY KEY (month_start, employee_id),
    CONSTRAINT fk_util_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_util_employee FOREIGN KEY (employee_id) REFERENCES dim_employee,
    CONSTRAINT fk_util_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT ck_util_rate CHECK (utilization_rate BETWEEN 0 AND 1),
    CONSTRAINT ck_util_hours CHECK (
        available_hours >= 0 AND billable_hours >= 0 AND internal_hours >= 0
        AND bench_hours >= 0 AND billable_hours <= available_hours
        AND ABS(available_hours - (billable_hours + internal_hours + bench_hours)) <= 0.11
    )
);

CREATE TABLE fact_project_financials (
    month_start             DATE          NOT NULL,
    project_id              VARCHAR2(30)  NOT NULL,
    customer_id             VARCHAR2(30)  NOT NULL,
    region_id               VARCHAR2(20)  NOT NULL,
    revenue_usd             NUMBER(18,2)  NOT NULL,
    direct_labor_cost_usd   NUMBER(18,2)  NOT NULL,
    subcontractor_cost_usd  NUMBER(18,2)  NOT NULL,
    travel_cost_usd         NUMBER(18,2)  NOT NULL,
    gross_profit_usd        NUMBER(18,2)  NOT NULL,
    billable_hours          NUMBER(14,2)  NOT NULL,
    CONSTRAINT pk_project_fin PRIMARY KEY (month_start, project_id),
    CONSTRAINT fk_pf_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_pf_project FOREIGN KEY (project_id) REFERENCES dim_project,
    CONSTRAINT fk_pf_customer FOREIGN KEY (customer_id) REFERENCES dim_customer,
    CONSTRAINT fk_pf_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT ck_pf_nonnegative CHECK (
        revenue_usd >= 0 AND direct_labor_cost_usd >= 0
        AND subcontractor_cost_usd >= 0 AND travel_cost_usd >= 0
        AND billable_hours >= 0
    ),
    CONSTRAINT ck_pf_gross_profit CHECK (
        ABS(gross_profit_usd - (revenue_usd - direct_labor_cost_usd
            - subcontractor_cost_usd - travel_cost_usd)) <= 0.03
    )
);

CREATE TABLE fact_gl_actuals (
    gl_row_id      VARCHAR2(40)  NOT NULL,
    month_start   DATE          NOT NULL,
    account_id    VARCHAR2(20)  NOT NULL,
    department_id VARCHAR2(20)  NOT NULL,
    region_id     VARCHAR2(20)  NOT NULL,
    customer_id   VARCHAR2(30),
    project_id    VARCHAR2(30),
    business_line VARCHAR2(50)  NOT NULL,
    amount_usd    NUMBER(18,2)  NOT NULL,
    source_system VARCHAR2(50)  NOT NULL,
    entry_type    VARCHAR2(50)  NOT NULL,
    CONSTRAINT pk_gl_actuals PRIMARY KEY (gl_row_id),
    CONSTRAINT fk_gl_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_gl_account FOREIGN KEY (account_id) REFERENCES dim_account,
    CONSTRAINT fk_gl_department FOREIGN KEY (department_id) REFERENCES dim_department,
    CONSTRAINT fk_gl_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT fk_gl_customer FOREIGN KEY (customer_id) REFERENCES dim_customer,
    CONSTRAINT fk_gl_project FOREIGN KEY (project_id) REFERENCES dim_project
);

CREATE TABLE fact_budget (
    budget_row_id   VARCHAR2(40)   NOT NULL,
    budget_version  VARCHAR2(50)   NOT NULL,
    month_start     DATE           NOT NULL,
    account_id      VARCHAR2(20)   NOT NULL,
    department_id   VARCHAR2(20)   NOT NULL,
    region_id       VARCHAR2(20)   NOT NULL,
    business_line   VARCHAR2(50)   NOT NULL,
    amount_usd      NUMBER(18,2)   NOT NULL,
    budget_driver   VARCHAR2(300)  NOT NULL,
    CONSTRAINT pk_budget PRIMARY KEY (budget_row_id),
    CONSTRAINT fk_budget_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_budget_account FOREIGN KEY (account_id) REFERENCES dim_account,
    CONSTRAINT fk_budget_dept FOREIGN KEY (department_id) REFERENCES dim_department,
    CONSTRAINT fk_budget_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT uq_budget_grain UNIQUE (
        budget_version, month_start, account_id, department_id, region_id, business_line
    )
);

CREATE TABLE fact_forecast (
    forecast_row_id   VARCHAR2(40)   NOT NULL,
    forecast_version  VARCHAR2(50)   NOT NULL,
    month_start       DATE           NOT NULL,
    account_id        VARCHAR2(20)   NOT NULL,
    department_id     VARCHAR2(20)   NOT NULL,
    region_id         VARCHAR2(20)   NOT NULL,
    business_line     VARCHAR2(50)   NOT NULL,
    period_type       VARCHAR2(30)   NOT NULL,
    amount_usd        NUMBER(18,2)   NOT NULL,
    forecast_driver   VARCHAR2(300)  NOT NULL,
    CONSTRAINT pk_forecast PRIMARY KEY (forecast_row_id),
    CONSTRAINT fk_forecast_month FOREIGN KEY (month_start) REFERENCES dim_date_month,
    CONSTRAINT fk_forecast_account FOREIGN KEY (account_id) REFERENCES dim_account,
    CONSTRAINT fk_forecast_dept FOREIGN KEY (department_id) REFERENCES dim_department,
    CONSTRAINT fk_forecast_region FOREIGN KEY (region_id) REFERENCES dim_region,
    CONSTRAINT uq_forecast_grain UNIQUE (
        forecast_version, month_start, account_id, department_id, region_id, business_line
    )
);

CREATE TABLE fact_invoice (
    invoice_id          VARCHAR2(40)  NOT NULL,
    customer_id         VARCHAR2(30)  NOT NULL,
    project_id          VARCHAR2(30),
    invoice_type        VARCHAR2(50)  NOT NULL,
    issue_date          DATE          NOT NULL,
    due_date            DATE          NOT NULL,
    paid_date           DATE,
    invoice_amount_usd  NUMBER(18,2)  NOT NULL,
    amount_paid_usd     NUMBER(18,2)  NOT NULL,
    outstanding_usd     NUMBER(18,2)  NOT NULL,
    invoice_status      VARCHAR2(30)  NOT NULL,
    payment_terms_days  NUMBER(4)     NOT NULL,
    days_to_pay         NUMBER(6),
    as_of_date          DATE          NOT NULL,
    CONSTRAINT pk_invoice PRIMARY KEY (invoice_id),
    CONSTRAINT fk_invoice_customer FOREIGN KEY (customer_id) REFERENCES dim_customer,
    CONSTRAINT fk_invoice_project FOREIGN KEY (project_id) REFERENCES dim_project,
    CONSTRAINT ck_invoice_dates CHECK (due_date >= issue_date),
    CONSTRAINT ck_invoice_amounts CHECK (
        invoice_amount_usd >= 0 AND amount_paid_usd >= 0 AND outstanding_usd >= 0
        AND amount_paid_usd <= invoice_amount_usd
        AND ABS(invoice_amount_usd - amount_paid_usd - outstanding_usd) <= 0.02
    )
);

CREATE INDEX ix_gl_month_account ON fact_gl_actuals (month_start, account_id);
CREATE INDEX ix_gl_customer ON fact_gl_actuals (customer_id);
CREATE INDEX ix_budget_month_account ON fact_budget (month_start, account_id);
CREATE INDEX ix_forecast_month_account ON fact_forecast (month_start, account_id);
CREATE INDEX ix_mrr_customer ON fact_subscription_mrr (customer_id, month_start);
CREATE INDEX ix_project_month ON fact_project_financials (project_id, month_start);
CREATE INDEX ix_hc_department ON fact_headcount_monthly (department_id, month_start);
CREATE INDEX ix_invoice_due_status ON fact_invoice (due_date, invoice_status);

/*
CSV import order in DBeaver
  1. dim_date_month, dim_region, dim_department, dim_account, model_sources,
     business_events
  2. dim_customer, dim_employee, dim_project, model_assumptions
  3. fact_subscription_mrr, fact_headcount_monthly,
     fact_utilization_monthly, fact_project_financials, fact_gl_actuals,
     fact_budget, fact_forecast, fact_invoice
*/



-- =============================================================================
-- PART 1: SOURCE DATA AUDIT, GRAIN, AND REFERENTIAL INTEGRITY
-- Run after importing all CSV files.
-- =============================================================================

-- 1. Inventory: base tables available in the current Oracle schema.
SELECT table_name, num_rows, last_analyzed
FROM user_tables
WHERE table_name LIKE 'DIM\_%' ESCAPE '\'
   OR table_name LIKE 'FACT\_%' ESCAPE '\'
   OR table_name IN ('MODEL_ASSUMPTIONS', 'MODEL_SOURCES', 'BUSINESS_EVENTS')
ORDER BY table_name;

-- 2. Field inventory: Oracle types, nullability, and declared PK columns.
SELECT
    c.table_name,
    c.column_id,
    c.column_name,
    c.data_type,
    c.data_length,
    c.data_precision,
    c.data_scale,
    c.nullable,
    CASE WHEN pk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END AS is_primary_key
FROM user_tab_columns c
LEFT JOIN (
    SELECT uc.table_name, ucc.column_name
    FROM user_constraints uc
    JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
    WHERE uc.constraint_type = 'P'
) pk
  ON pk.table_name = c.table_name
 AND pk.column_name = c.column_name
WHERE c.table_name LIKE 'DIM\_%' ESCAPE '\'
   OR c.table_name LIKE 'FACT\_%' ESCAPE '\'
   OR c.table_name IN ('MODEL_ASSUMPTIONS', 'MODEL_SOURCES', 'BUSINESS_EVENTS')
ORDER BY c.table_name, c.column_id;

-- 3. Row counts: establish source size before analysis.
SELECT 'BUSINESS_EVENTS' AS table_name, COUNT(*) AS row_count FROM business_events
UNION ALL SELECT 'DIM_ACCOUNT', COUNT(*) FROM dim_account
UNION ALL SELECT 'DIM_CUSTOMER', COUNT(*) FROM dim_customer
UNION ALL SELECT 'DIM_DATE_MONTH', COUNT(*) FROM dim_date_month
UNION ALL SELECT 'DIM_DEPARTMENT', COUNT(*) FROM dim_department
UNION ALL SELECT 'DIM_EMPLOYEE', COUNT(*) FROM dim_employee
UNION ALL SELECT 'DIM_PROJECT', COUNT(*) FROM dim_project
UNION ALL SELECT 'DIM_REGION', COUNT(*) FROM dim_region
UNION ALL SELECT 'FACT_BUDGET', COUNT(*) FROM fact_budget
UNION ALL SELECT 'FACT_FORECAST', COUNT(*) FROM fact_forecast
UNION ALL SELECT 'FACT_GL_ACTUALS', COUNT(*) FROM fact_gl_actuals
UNION ALL SELECT 'FACT_HEADCOUNT_MONTHLY', COUNT(*) FROM fact_headcount_monthly
UNION ALL SELECT 'FACT_INVOICE', COUNT(*) FROM fact_invoice
UNION ALL SELECT 'FACT_PROJECT_FINANCIALS', COUNT(*) FROM fact_project_financials
UNION ALL SELECT 'FACT_SUBSCRIPTION_MRR', COUNT(*) FROM fact_subscription_mrr
UNION ALL SELECT 'FACT_UTILIZATION_MONTHLY', COUNT(*) FROM fact_utilization_monthly
UNION ALL SELECT 'MODEL_ASSUMPTIONS', COUNT(*) FROM model_assumptions
UNION ALL SELECT 'MODEL_SOURCES', COUNT(*) FROM model_sources
ORDER BY table_name;

-- 4. Samples. Run individually in DBeaver while learning the data.
SELECT * FROM dim_region FETCH FIRST 5 ROWS ONLY;
SELECT * FROM dim_customer FETCH FIRST 5 ROWS ONLY;
SELECT * FROM dim_project FETCH FIRST 5 ROWS ONLY;
SELECT * FROM fact_gl_actuals FETCH FIRST 5 ROWS ONLY;
SELECT * FROM fact_budget FETCH FIRST 5 ROWS ONLY;
SELECT * FROM fact_forecast FETCH FIRST 5 ROWS ONLY;
SELECT * FROM fact_subscription_mrr FETCH FIRST 5 ROWS ONLY;
SELECT * FROM fact_invoice FETCH FIRST 5 ROWS ONLY;

-- 5. Candidate keys and expected grain. Every query should return zero rows.
SELECT region_id, COUNT(*) AS duplicate_count
FROM dim_region GROUP BY region_id HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM dim_customer GROUP BY customer_id HAVING COUNT(*) > 1;

SELECT project_id, COUNT(*) AS duplicate_count
FROM dim_project GROUP BY project_id HAVING COUNT(*) > 1;

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
    budget_version, month_start, account_id, department_id,
    region_id, business_line, COUNT(*) AS duplicate_count
FROM fact_budget
GROUP BY budget_version, month_start, account_id, department_id, region_id, business_line
HAVING COUNT(*) > 1;

SELECT
    forecast_version, month_start, account_id, department_id,
    region_id, business_line, COUNT(*) AS duplicate_count
FROM fact_forecast
GROUP BY forecast_version, month_start, account_id, department_id, region_id, business_line
HAVING COUNT(*) > 1;

-- 6. Declared Oracle PK and FK relationships.
SELECT
    uc.table_name,
    uc.constraint_name,
    CASE uc.constraint_type
        WHEN 'P' THEN 'PRIMARY KEY'
        WHEN 'R' THEN 'FOREIGN KEY'
    END AS constraint_type,
    LISTAGG(ucc.column_name, ', ') WITHIN GROUP (ORDER BY ucc.position) AS key_columns,
    uc.status,
    uc.validated
FROM user_constraints uc
JOIN user_cons_columns ucc ON ucc.constraint_name = uc.constraint_name
WHERE uc.constraint_type IN ('P', 'R')
GROUP BY uc.table_name, uc.constraint_name, uc.constraint_type, uc.status, uc.validated
ORDER BY uc.table_name, constraint_type, uc.constraint_name;

-- 7. Manual orphan checks. Every orphan_count should be zero.
SELECT 'MRR -> CUSTOMER' AS relationship, COUNT(*) AS orphan_count
FROM fact_subscription_mrr m
LEFT JOIN dim_customer c ON c.customer_id = m.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'PROJECT FINANCIALS -> PROJECT', COUNT(*)
FROM fact_project_financials f
LEFT JOIN dim_project p ON p.project_id = f.project_id
WHERE p.project_id IS NULL
UNION ALL
SELECT 'HEADCOUNT -> EMPLOYEE', COUNT(*)
FROM fact_headcount_monthly h
LEFT JOIN dim_employee e ON e.employee_id = h.employee_id
WHERE e.employee_id IS NULL
UNION ALL
SELECT 'GL -> ACCOUNT', COUNT(*)
FROM fact_gl_actuals g
LEFT JOIN dim_account a ON a.account_id = g.account_id
WHERE a.account_id IS NULL
UNION ALL
SELECT 'BUDGET -> ACCOUNT', COUNT(*)
FROM fact_budget b
LEFT JOIN dim_account a ON a.account_id = b.account_id
WHERE a.account_id IS NULL
UNION ALL
SELECT 'FORECAST -> ACCOUNT', COUNT(*)
FROM fact_forecast f
LEFT JOIN dim_account a ON a.account_id = f.account_id
WHERE a.account_id IS NULL
UNION ALL
SELECT 'INVOICE -> CUSTOMER', COUNT(*)
FROM fact_invoice i
LEFT JOIN dim_customer c ON c.customer_id = i.customer_id
WHERE c.customer_id IS NULL;

-- 8. Structural equations and row-level business rules.
SELECT
    check_name,
    max_difference,
    tolerance,
    failing_rows,
    CASE WHEN NVL(max_difference, 0) <= tolerance AND failing_rows = 0
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM (
    SELECT
        'Region weights equal 1.0' AS check_name,
        ABS(SUM(revenue_weight) - 1) AS max_difference,
        0.0001 AS tolerance,
        CASE WHEN ABS(SUM(revenue_weight) - 1) > 0.0001 THEN 1 ELSE 0 END AS failing_rows
    FROM dim_region

    UNION ALL

    SELECT
        'MRR roll-forward',
        MAX(ABS(ending_mrr_usd - (opening_mrr_usd + new_mrr_usd + expansion_mrr_usd
            - contraction_mrr_usd - churn_mrr_usd))),
        0.02,
        SUM(CASE WHEN ABS(ending_mrr_usd - (opening_mrr_usd + new_mrr_usd
            + expansion_mrr_usd - contraction_mrr_usd - churn_mrr_usd)) > 0.02
            THEN 1 ELSE 0 END)
    FROM fact_subscription_mrr

    UNION ALL

    SELECT
        'Invoice outstanding equation',
        MAX(ABS(invoice_amount_usd - amount_paid_usd - outstanding_usd)),
        0.02,
        SUM(CASE WHEN ABS(invoice_amount_usd - amount_paid_usd - outstanding_usd) > 0.02
            THEN 1 ELSE 0 END)
    FROM fact_invoice

    UNION ALL

    SELECT
        'Headcount personnel-cost equation',
        MAX(ABS(total_personnel_cost_usd - (monthly_base_salary_usd + bonus_accrual_usd
            + benefits_usd + payroll_taxes_usd))),
        0.03,
        SUM(CASE WHEN ABS(total_personnel_cost_usd - (monthly_base_salary_usd
            + bonus_accrual_usd + benefits_usd + payroll_taxes_usd)) > 0.03
            THEN 1 ELSE 0 END)
    FROM fact_headcount_monthly

    UNION ALL

    SELECT
        'Utilization hours equation',
        MAX(ABS(available_hours - (billable_hours + internal_hours + bench_hours))),
        0.11,
        SUM(CASE WHEN ABS(available_hours - (billable_hours + internal_hours
            + bench_hours)) > 0.11 THEN 1 ELSE 0 END)
    FROM fact_utilization_monthly

    UNION ALL

    SELECT
        'Project gross-profit equation',
        MAX(ABS(gross_profit_usd - (revenue_usd - direct_labor_cost_usd
            - subcontractor_cost_usd - travel_cost_usd))),
        0.03,
        SUM(CASE WHEN ABS(gross_profit_usd - (revenue_usd - direct_labor_cost_usd
            - subcontractor_cost_usd - travel_cost_usd)) > 0.03 THEN 1 ELSE 0 END)
    FROM fact_project_financials
);


-- =============================================================================
-- PART 2: FINANCIAL RECONCILIATION AND MONTH-CLOSE CONTROLS
-- =============================================================================

WITH checks AS (
    SELECT 1 AS check_order, 'Subscription revenue ties to GL' AS check_name,
        ROUND(
            (SELECT SUM(recognized_revenue_usd) FROM fact_subscription_mrr)
            - (SELECT SUM(amount_usd) FROM fact_gl_actuals WHERE account_id = 'A4000'), 2
        ) AS difference,
        0.05 AS tolerance, 'FACT_SUBSCRIPTION_MRR vs A4000' AS fix_location
    FROM dual

    UNION ALL
    SELECT 2, 'Services revenue ties to GL',
        ROUND(
            (SELECT SUM(revenue_usd) FROM fact_project_financials)
            - (SELECT SUM(amount_usd) FROM fact_gl_actuals
               WHERE account_id IN ('A4010', 'A4020')), 2
        ),
        0.05, 'FACT_PROJECT_FINANCIALS vs A4010/A4020'
    FROM dual

    UNION ALL
    SELECT 3, 'Services labor ties to payroll',
        ROUND(
            (SELECT SUM(total_personnel_cost_usd)
             FROM fact_headcount_monthly WHERE department_id = 'D03')
            - (SELECT SUM(amount_usd) FROM fact_gl_actuals WHERE account_id = 'A5020'), 2
        ),
        0.05, 'FACT_HEADCOUNT_MONTHLY vs A5020'
    FROM dual

    UNION ALL
    SELECT 4, 'Budget has twelve months',
        (SELECT COUNT(DISTINCT month_start) FROM fact_budget) - 12,
        0, 'FACT_BUDGET'
    FROM dual

    UNION ALL
    SELECT 5, 'Forecast has twelve months',
        (SELECT COUNT(DISTINCT month_start) FROM fact_forecast) - 12,
        0, 'FACT_FORECAST'
    FROM dual

    UNION ALL
    SELECT 6, 'Invoices reconcile',
        ROUND((SELECT SUM(invoice_amount_usd - amount_paid_usd - outstanding_usd)
               FROM fact_invoice), 2),
        0.05, 'FACT_INVOICE'
    FROM dual

    UNION ALL
    SELECT 7, 'No negative MRR',
        (SELECT COUNT(*) FROM fact_subscription_mrr WHERE ending_mrr_usd < 0),
        0, 'FACT_SUBSCRIPTION_MRR'
    FROM dual

    UNION ALL
    SELECT 8, 'No impossible utilization',
        (SELECT COUNT(*) FROM fact_utilization_monthly
         WHERE utilization_rate < 0 OR utilization_rate > 1
            OR billable_hours > available_hours),
        0, 'FACT_UTILIZATION_MONTHLY'
    FROM dual

    UNION ALL
    SELECT 9, 'All FK constraints enabled and validated',
        (SELECT COUNT(*) FROM user_constraints
         WHERE constraint_type = 'R'
           AND (status <> 'ENABLED' OR validated <> 'VALIDATED')),
        0, 'USER_CONSTRAINTS'
    FROM dual
)
SELECT
    check_order,
    check_name,
    difference,
    tolerance,
    CASE WHEN ABS(NVL(difference, 0)) <= tolerance THEN 'PASS' ELSE 'FAIL' END AS status,
    fix_location
FROM checks
ORDER BY check_order;


-- =============================================================================
-- PART 3: REUSABLE ORACLE REPORTING VIEWS
-- CREATE OR REPLACE makes this section safe to rerun after logic changes.
-- =============================================================================

CREATE OR REPLACE VIEW v_scenario_pnl_detail AS
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
    CAST(NULL AS VARCHAR2(30)) AS customer_id,
    CAST(NULL AS VARCHAR2(30)) AS project_id,
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
    CAST(NULL AS VARCHAR2(30)) AS customer_id,
    CAST(NULL AS VARCHAR2(30)) AS project_id,
    f.amount_usd
FROM fact_forecast f
JOIN dim_account a ON a.account_id = f.account_id
JOIN dim_department d ON d.department_id = f.department_id
JOIN dim_region r ON r.region_id = f.region_id;


CREATE OR REPLACE VIEW v_monthly_pnl AS
SELECT
    month_start,
    scenario,
    ROUND(SUM(CASE WHEN pnl_line = 'Subscription Revenue' THEN amount_usd ELSE 0 END), 2)
        AS subscription_revenue_usd,
    ROUND(SUM(CASE WHEN pnl_line = 'Professional Services Revenue' THEN amount_usd ELSE 0 END), 2)
        AS services_revenue_usd,
    ROUND(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 2)
        AS total_revenue_usd,
    ROUND(SUM(CASE WHEN pnl_line = 'Cost of Subscription' THEN amount_usd ELSE 0 END), 2)
        AS cost_of_subscription_usd,
    ROUND(SUM(CASE WHEN pnl_line = 'Cost of Services' THEN amount_usd ELSE 0 END), 2)
        AS cost_of_services_usd,
    ROUND(
        SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END)
        - SUM(CASE WHEN statement_section = 'Cost of Revenue' THEN amount_usd ELSE 0 END),
        2
    ) AS gross_profit_usd,
    ROUND(
        (SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END)
        - SUM(CASE WHEN statement_section = 'Cost of Revenue' THEN amount_usd ELSE 0 END))
        / NULLIF(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 0),
        4
    ) AS gross_margin_pct,
    ROUND(SUM(CASE WHEN pnl_line = 'Sales & Marketing' THEN amount_usd ELSE 0 END), 2)
        AS sales_marketing_usd,
    ROUND(SUM(CASE WHEN pnl_line = 'Research & Development' THEN amount_usd ELSE 0 END), 2)
        AS research_development_usd,
    ROUND(SUM(CASE WHEN pnl_line = 'General & Administrative' THEN amount_usd ELSE 0 END), 2)
        AS general_administrative_usd,
    ROUND(
        SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END)
        - SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense')
                   THEN amount_usd ELSE 0 END),
        2
    ) AS adjusted_ebitda_usd,
    ROUND(
        (SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END)
        - SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense')
                   THEN amount_usd ELSE 0 END))
        / NULLIF(SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END), 0),
        4
    ) AS adjusted_ebitda_margin_pct,
    ROUND(SUM(CASE WHEN pnl_line = 'Depreciation & Amortization' THEN amount_usd ELSE 0 END), 2)
        AS depreciation_amortization_usd,
    ROUND(
        SUM(CASE WHEN statement_section = 'Revenue' THEN amount_usd ELSE 0 END)
        - SUM(CASE WHEN statement_section IN ('Cost of Revenue', 'Operating Expense', 'D&A')
                   THEN amount_usd ELSE 0 END),
        2
    ) AS operating_income_usd
FROM v_scenario_pnl_detail
GROUP BY month_start, scenario;


CREATE OR REPLACE VIEW v_arr_bridge_monthly AS
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


CREATE OR REPLACE VIEW v_monthly_kpi AS
SELECT
    p.month_start,
    p.total_revenue_usd,
    p.gross_margin_pct,
    p.adjusted_ebitda_usd,
    p.adjusted_ebitda_margin_pct,
    a.ending_arr_usd,
    a.active_customers,
    ROUND((SELECT SUM(h.fte)
           FROM fact_headcount_monthly h
           WHERE h.month_start = p.month_start), 1) AS total_fte,
    ROUND((SELECT SUM(u.billable_hours) / NULLIF(SUM(u.available_hours), 0)
           FROM fact_utilization_monthly u
           WHERE u.month_start = p.month_start), 4) AS services_utilization_pct
FROM v_monthly_pnl p
JOIN v_arr_bridge_monthly a ON a.month_start = p.month_start
WHERE p.scenario = 'Actual';


CREATE OR REPLACE VIEW v_customer_revenue_monthly AS
WITH services AS (
    SELECT month_start, customer_id, region_id, SUM(revenue_usd) AS services_revenue_usd
    FROM fact_project_financials
    GROUP BY month_start, customer_id, region_id
),
customer_month_keys AS (
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
    ROUND(NVL(s.recognized_revenue_usd, 0), 2) AS subscription_revenue_usd,
    ROUND(NVL(ps.services_revenue_usd, 0), 2) AS services_revenue_usd,
    ROUND(NVL(s.recognized_revenue_usd, 0) + NVL(ps.services_revenue_usd, 0), 2)
        AS total_revenue_usd,
    ROUND(NVL(s.ending_mrr_usd, 0) * 12, 2) AS ending_arr_usd
FROM customer_month_keys k
JOIN dim_customer c ON c.customer_id = k.customer_id
JOIN dim_region r ON r.region_id = k.region_id
LEFT JOIN fact_subscription_mrr s
  ON s.month_start = k.month_start
 AND s.customer_id = k.customer_id
LEFT JOIN services ps
  ON ps.month_start = k.month_start
 AND ps.customer_id = k.customer_id;


CREATE OR REPLACE VIEW v_project_margin AS
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
    ROUND(SUM(f.revenue_usd) / NULLIF(SUM(f.billable_hours), 0), 2)
        AS realized_bill_rate_usd
FROM dim_project p
JOIN dim_customer c ON c.customer_id = p.customer_id
JOIN dim_region r ON r.region_id = p.region_id
JOIN fact_project_financials f ON f.project_id = p.project_id
GROUP BY
    p.project_id, c.customer_name, c.segment, r.region_name, p.project_type,
    p.contract_type, p.start_month, p.planned_end_month, p.status;


CREATE OR REPLACE VIEW v_headcount_utilization AS
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
    CASE WHEN hc.department_id = 'D03'
         THEN ROUND(util.billable_hours / NULLIF(util.available_hours, 0), 4)
         ELSE NULL END AS services_utilization_pct
FROM hc
JOIN dim_department d ON d.department_id = hc.department_id
JOIN dim_region r ON r.region_id = hc.region_id
LEFT JOIN util
  ON util.month_start = hc.month_start
 AND util.region_id = hc.region_id;


CREATE OR REPLACE VIEW v_ar_aging AS
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
    TRUNC(i.as_of_date) - TRUNC(i.due_date) AS days_past_due,
    CASE
        WHEN TRUNC(i.as_of_date) <= TRUNC(i.due_date) THEN 'Current'
        WHEN TRUNC(i.as_of_date) - TRUNC(i.due_date) <= 30 THEN '1-30 days'
        WHEN TRUNC(i.as_of_date) - TRUNC(i.due_date) <= 60 THEN '31-60 days'
        WHEN TRUNC(i.as_of_date) - TRUNC(i.due_date) <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END AS aging_bucket,
    i.as_of_date
FROM fact_invoice i
JOIN dim_customer c ON c.customer_id = i.customer_id
JOIN dim_region r ON r.region_id = c.region_id
WHERE i.outstanding_usd > 0;


CREATE OR REPLACE VIEW v_variance_ytd AS
WITH actual AS (
    SELECT pnl_line, SUM(amount_usd) AS amount_usd
    FROM v_scenario_pnl_detail
    WHERE scenario = 'Actual'
      AND month_start BETWEEN DATE '2026-01-01' AND DATE '2026-06-01'
    GROUP BY pnl_line
),
budget AS (
    SELECT pnl_line, SUM(amount_usd) AS amount_usd
    FROM v_scenario_pnl_detail
    WHERE scenario = 'Budget'
      AND month_start BETWEEN DATE '2026-01-01' AND DATE '2026-06-01'
    GROUP BY pnl_line
),
pnl_lines AS (
    SELECT DISTINCT pnl_line, statement_section
    FROM dim_account
    WHERE pnl_line <> 'Depreciation & Amortization'
)
SELECT
    p.pnl_line,
    ROUND(NVL(a.amount_usd, 0), 2) AS actual_ytd_usd,
    ROUND(NVL(b.amount_usd, 0), 2) AS budget_ytd_usd,
    ROUND(
        CASE WHEN p.statement_section = 'Revenue'
             THEN NVL(a.amount_usd, 0) - NVL(b.amount_usd, 0)
             ELSE NVL(b.amount_usd, 0) - NVL(a.amount_usd, 0)
        END,
        2
    ) AS favorable_variance_usd,
    ROUND(
        CASE WHEN p.statement_section = 'Revenue'
             THEN NVL(a.amount_usd, 0) - NVL(b.amount_usd, 0)
             ELSE NVL(b.amount_usd, 0) - NVL(a.amount_usd, 0)
        END / NULLIF(NVL(b.amount_usd, 0), 0),
        4
    ) AS favorable_variance_pct
FROM pnl_lines p
LEFT JOIN actual a ON a.pnl_line = p.pnl_line
LEFT JOIN budget b ON b.pnl_line = p.pnl_line;

-- =============================================================================
-- PART 4: MANAGEMENT ANALYSIS QUERIES
-- =============================================================================

-- 1. Monthly P&L: Actual versus Budget versus Q2 Forecast.
SELECT *
FROM v_monthly_pnl
WHERE month_start >= DATE '2026-01-01'
ORDER BY month_start, scenario;

-- 2. H1 favorable / unfavorable variance by P&L line.
SELECT
    pnl_line,
    actual_ytd_usd,
    budget_ytd_usd,
    favorable_variance_usd,
    favorable_variance_pct,
    CASE WHEN favorable_variance_usd >= 0 THEN 'Favorable' ELSE 'Unfavorable' END
        AS variance_status
FROM v_variance_ytd
ORDER BY ABS(favorable_variance_usd) DESC;

-- 3. ARR bridge, month-over-month movement, and active customers.
SELECT
    month_start,
    opening_arr_usd,
    new_arr_usd,
    expansion_arr_usd,
    contraction_arr_usd,
    churn_arr_usd,
    ending_arr_usd,
    ending_arr_usd - LAG(ending_arr_usd) OVER (ORDER BY month_start) AS arr_change_usd,
    active_customers
FROM v_arr_bridge_monthly
WHERE month_start >= DATE '2025-01-01'
ORDER BY month_start;

-- 4. Top-15 customer concentration for the trailing twelve months.
WITH customer_ttm AS (
    SELECT
        customer_id,
        customer_name,
        segment,
        SUM(total_revenue_usd) AS revenue_ttm_usd
    FROM v_customer_revenue_monthly
    WHERE month_start BETWEEN DATE '2025-07-01' AND DATE '2026-06-01'
    GROUP BY customer_id, customer_name, segment
),
ranked AS (
    SELECT
        customer_ttm.*,
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
    ROUND(revenue_ttm_usd / NULLIF(company_revenue_ttm_usd, 0), 4) AS revenue_share,
    ROUND(
        SUM(revenue_ttm_usd) OVER (
            ORDER BY revenue_rank ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / NULLIF(company_revenue_ttm_usd, 0),
        4
    ) AS cumulative_revenue_share
FROM ranked
WHERE revenue_rank <= 15
ORDER BY revenue_rank;

-- 5. Lowest-margin services projects with at least $100k revenue to date.
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
FETCH FIRST 20 ROWS ONLY;

-- 6. Headcount, personnel cost, and services utilization trend.
SELECT
    month_start,
    SUM(fte) AS total_fte,
    SUM(CASE WHEN department_name = 'Professional Services' THEN fte ELSE 0 END)
        AS services_fte,
    ROUND(SUM(CASE WHEN department_name = 'Professional Services'
                   THEN personnel_cost_usd ELSE 0 END), 2)
        AS services_personnel_cost_usd,
    ROUND(MAX(services_utilization_pct), 4) AS services_utilization_pct
FROM v_headcount_utilization
WHERE month_start >= DATE '2025-01-01'
GROUP BY month_start
ORDER BY month_start;

-- 7. AR aging, concentration, and ordered aging buckets.
SELECT
    aging_bucket,
    COUNT(*) AS invoice_count,
    ROUND(SUM(outstanding_usd), 2) AS outstanding_usd,
    ROUND(SUM(outstanding_usd) / NULLIF(SUM(SUM(outstanding_usd)) OVER (), 0), 4)
        AS share_of_open_ar
FROM v_ar_aging
GROUP BY aging_bucket
ORDER BY CASE aging_bucket
    WHEN 'Current' THEN 1
    WHEN '1-30 days' THEN 2
    WHEN '31-60 days' THEN 3
    WHEN '61-90 days' THEN 4
    ELSE 5
END;


-- =============================================================================
-- PART 5: OPTIONAL PL/SQL MONTH-CLOSE CONTROL AUTOMATION
-- Run the table DDL once. The procedure can be rerun for any close month.
-- =============================================================================

CREATE TABLE fpa_close_check_results (
    result_id    NUMBER GENERATED BY DEFAULT AS IDENTITY,
    close_month  DATE           NOT NULL,
    check_name   VARCHAR2(200)  NOT NULL,
    difference   NUMBER(18,4),
    tolerance    NUMBER(18,4)   NOT NULL,
    status       VARCHAR2(10)   NOT NULL,
    checked_at   TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_close_check_results PRIMARY KEY (result_id),
    CONSTRAINT ck_close_check_status CHECK (status IN ('PASS', 'FAIL'))
);


CREATE OR REPLACE PROCEDURE sp_run_monthly_close_checks (
    p_close_month IN DATE
)
AS
    v_month DATE := TRUNC(p_close_month, 'MM');
BEGIN
    DELETE FROM fpa_close_check_results
    WHERE close_month = v_month;

    INSERT INTO fpa_close_check_results
        (close_month, check_name, difference, tolerance, status)
    SELECT
        v_month,
        'Subscription revenue ties to GL',
        difference,
        0.05,
        CASE WHEN ABS(NVL(difference, 0)) <= 0.05 THEN 'PASS' ELSE 'FAIL' END
    FROM (
        SELECT ROUND(
            (SELECT SUM(recognized_revenue_usd)
             FROM fact_subscription_mrr WHERE month_start = v_month)
            - (SELECT SUM(amount_usd)
               FROM fact_gl_actuals
               WHERE month_start = v_month AND account_id = 'A4000'),
            2
        ) AS difference
        FROM dual
    );

    INSERT INTO fpa_close_check_results
        (close_month, check_name, difference, tolerance, status)
    SELECT
        v_month,
        'Services revenue ties to GL',
        difference,
        0.05,
        CASE WHEN ABS(NVL(difference, 0)) <= 0.05 THEN 'PASS' ELSE 'FAIL' END
    FROM (
        SELECT ROUND(
            (SELECT SUM(revenue_usd)
             FROM fact_project_financials WHERE month_start = v_month)
            - (SELECT SUM(amount_usd)
               FROM fact_gl_actuals
               WHERE month_start = v_month AND account_id IN ('A4010', 'A4020')),
            2
        ) AS difference
        FROM dual
    );

    INSERT INTO fpa_close_check_results
        (close_month, check_name, difference, tolerance, status)
    SELECT
        v_month,
        'Services labor ties to payroll',
        difference,
        0.05,
        CASE WHEN ABS(NVL(difference, 0)) <= 0.05 THEN 'PASS' ELSE 'FAIL' END
    FROM (
        SELECT ROUND(
            (SELECT SUM(total_personnel_cost_usd)
             FROM fact_headcount_monthly
             WHERE month_start = v_month AND department_id = 'D03')
            - (SELECT SUM(amount_usd)
               FROM fact_gl_actuals
               WHERE month_start = v_month AND account_id = 'A5020'),
            2
        ) AS difference
        FROM dual
    );

    INSERT INTO fpa_close_check_results
        (close_month, check_name, difference, tolerance, status)
    SELECT
        v_month,
        'MRR roll-forward violations',
        violation_count,
        0,
        CASE WHEN violation_count = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM (
        SELECT COUNT(*) AS violation_count
        FROM fact_subscription_mrr
        WHERE month_start = v_month
          AND ABS(ending_mrr_usd - (opening_mrr_usd + new_mrr_usd
              + expansion_mrr_usd - contraction_mrr_usd - churn_mrr_usd)) > 0.02
    );

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END sp_run_monthly_close_checks;
/

-- Example: execute the June 2026 close controls.
BEGIN
    sp_run_monthly_close_checks(DATE '2026-06-01');
END;
/

SELECT
    close_month,
    check_name,
    difference,
    tolerance,
    status,
    checked_at
FROM fpa_close_check_results
WHERE close_month = DATE '2026-06-01'
ORDER BY result_id;


-- =============================================================================
-- PART 6: CURATED CSV OUTPUTS
-- Run one query at a time in DBeaver and export the result using the filename
-- above it. Excel and Tableau use the same files.
-- Export the PART 2 result separately as 09_quality_checks.csv.
-- =============================================================================

-- 01_monthly_pnl.csv
SELECT *
FROM v_monthly_pnl
ORDER BY month_start, scenario;


-- 02_pnl_line_monthly.csv
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

-- 03_monthly_kpi.csv
SELECT *
FROM v_monthly_kpi
ORDER BY month_start;

-- 04_arr_bridge.csv
SELECT *
FROM v_arr_bridge_monthly
ORDER BY month_start;

-- 05_headcount_utilization.csv
SELECT *
FROM v_headcount_utilization
ORDER BY month_start, function_group, department_name, region_name;

-- 06_project_margin.csv
SELECT *
FROM v_project_margin
ORDER BY gross_margin_pct, project_id;

-- 07_ar_aging.csv
SELECT *
FROM v_ar_aging
ORDER BY days_past_due DESC, invoice_id;

-- 08_customer_ttm.csv
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
    WHERE month_start BETWEEN DATE '2025-07-01' AND DATE '2026-06-01'
    GROUP BY customer_id, customer_name, segment, industry, region_name
),
ranked AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY total_revenue_usd DESC) AS revenue_rank,
        customer_ttm.*,
        SUM(total_revenue_usd) OVER () AS company_revenue_usd
    FROM customer_ttm
)
SELECT
    revenue_rank,
    customer_id,
    customer_name,
    segment,
    industry,
    region_name,
    ROUND(subscription_revenue_usd, 2) AS subscription_revenue_usd,
    ROUND(services_revenue_usd, 2) AS services_revenue_usd,
    ROUND(total_revenue_usd, 2) AS total_revenue_usd,
    ROUND(total_revenue_usd / NULLIF(company_revenue_usd, 0), 4) AS revenue_share
FROM ranked
ORDER BY revenue_rank;
