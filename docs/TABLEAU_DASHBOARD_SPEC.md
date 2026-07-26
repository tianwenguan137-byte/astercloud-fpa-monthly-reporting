# Tableau Dashboard Specification

## Purpose

Build a four-page Tableau story that answers management questions before it
shows detailed data. Use the prepared CSV files in `data/tableau/` or connect
directly to `data/database/astercloud_fpa.sqlite`.

## Global controls

- Reporting period
- Scenario: Actual, Budget, Q2 Forecast
- Region
- Business line
- Customer segment
- Department / function

Use Actual as the default scenario and June 2026 as the default close month.

## Page 1: Executive Overview

### KPI strip

- H1 Revenue
- Revenue vs Budget
- Gross Margin
- Adjusted EBITDA
- EBITDA Margin
- Ending ARR
- Headcount
- Services Utilization

### Visuals

1. Monthly Revenue: Actual vs Budget vs Q2 Forecast.
2. H1 Favorable Variance by P&L Line.
3. Gross Margin and EBITDA Margin trend.
4. Full-year Budget-to-Forecast summary.
5. Three management callouts:
   - subscription miss from enterprise churn;
   - services miss from timing and utilization;
   - partial cost offset from delayed hiring and lower hosting cost.

Primary files:

- `tableau_monthly_pnl.csv`
- `tableau_monthly_kpi.csv`
- `tableau_variance_ytd.csv`

## Page 2: Revenue and ARR

### Visuals

1. ARR bridge: Opening + New + Expansion - Contraction - Churn = Ending.
2. Revenue by subscription and services.
3. Customer revenue by segment and region.
4. Top-10 revenue concentration.
5. Churn detail table with customer, segment, ARR loss, and renewal month.

Primary files:

- `tableau_arr_bridge.csv`
- `tableau_customer_revenue.csv`

## Page 3: Cost, Headcount, and Services

### Visuals

1. Headcount and personnel cost by function.
2. Services utilization trend.
3. Project margin distribution.
4. Lowest-margin project exceptions.
5. Revenue, realized bill rate, and margin by project type.

Primary files:

- `tableau_headcount_utilization.csv`
- `tableau_project_margin.csv`
- `tableau_pnl_detail.csv`

## Page 4: AR and Collections

### Visuals

1. AR aging by bucket.
2. Open AR by customer and region.
3. Past-due invoice detail.
4. DSO KPI.
5. Credit-risk tier and payment-term mix.

Primary file:

- `tableau_ar_aging.csv`

## Recommended calculated fields

### Signed P&L Amount

```text
IF [statement_section] = "Revenue" THEN [amount_usd]
ELSE -[amount_usd]
END
```

### Favorable Variance

```text
IF [statement_section] = "Revenue" THEN
    SUM(IF [scenario] = "Actual" THEN [amount_usd] END)
    - SUM(IF [scenario] = "Budget" THEN [amount_usd] END)
ELSE
    SUM(IF [scenario] = "Budget" THEN [amount_usd] END)
    - SUM(IF [scenario] = "Actual" THEN [amount_usd] END)
END
```

### Variance Status

```text
IF [Favorable Variance] >= 0 THEN "Favorable"
ELSE "Unfavorable"
END
```

### ARR Movement

Use `new_arr_usd` and `expansion_arr_usd` as positive values. Display
`contraction_arr_usd` and `churn_arr_usd` as negative values.

### Project Margin

```text
SUM([gross_profit_usd]) / SUM([revenue_to_date_usd])
```

### Services Utilization

Use the pre-aggregated `services_utilization_pct`; do not average it across
regions without weighting available hours. For company-level views, use the
monthly KPI extract.

### DSO

For the June 2026 snapshot:

```text
SUM([outstanding_usd])
/
SUM([Trailing 90-Day Revenue])
* 90
```

The Excel management report and SQL validation use approximately 22.3 days.

## Visual design

- Use restrained finance colors:
  - Actual: dark charcoal
  - Budget: medium gray
  - Forecast: teal
  - Favorable: green
  - Unfavorable: red
- Keep currency in millions on executive pages.
- Use complete metric names; avoid unexplained acronyms.
- Do not show more than four series in a chart.
- Use tooltips for account, customer, project, and driver detail.
- Keep variance signs consistent: positive always means favorable.

## Validation before publishing

1. H1 Actual revenue equals $69.6m.
2. H1 Budget revenue equals $73.6m.
3. FY2026 Q2 Forecast revenue equals $145.0m.
4. June ending ARR equals $117.8m.
5. June headcount equals 422.6 FTE.
6. All SQL checks in `sql/03_quality_checks.sql` show `PASS`.
