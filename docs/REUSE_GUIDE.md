# Reuse Guide

This dataset is deliberately structured so Project 2 can become a driver-based
budget and rolling forecast without replacing the source model.

## Stable elements

Do not change these identifiers after publishing:

- customer IDs;
- employee IDs;
- project IDs;
- account IDs and codes;
- department IDs and cost centers;
- region IDs.

Append new months and scenario versions instead.

## Recommended Project 2 additions

Add these tables beside the current facts:

- `fact_sales_pipeline`
  - opportunity, stage, probability, ACV, expected close month, region, segment;
- `fact_contract_renewal_plan`
  - opening ARR, renewal month, GRR, expansion, price uplift;
- `fact_project_backlog`
  - contracted value, recognized-to-date, remaining backlog, staffing need;
- `fact_hiring_plan`
  - role, department, location, planned start, salary band, hiring probability;
- `fact_opex_driver`
  - vendor, cost type, fixed/variable rule, inflation, contract date;
- `dim_scenario`
  - Budget, Base, Upside, Downside, and rolling forecast versions.

## Suggested forecast drivers

### Subscription revenue

```text
Opening ARR
+ New ARR from weighted pipeline
+ Expansion and price uplift
- Contraction
- Churn
= Ending ARR
```

Monthly recognized revenue should roll from average ARR or customer-level MRR.

### Services revenue

```text
Billable FTE
x Available Hours
x Utilization
x Realized Bill Rate
= Services Revenue
```

Constrain revenue by project backlog and delivery capacity.

### Personnel cost

```text
Opening Headcount
+ Hires
- Attrition
= Ending Headcount

Average Headcount
x Salary
x Merit
+ Bonus
+ Benefits and Payroll Tax
= Personnel Cost
```

### Cloud hosting

Model cost from subscription revenue or usage volume and a hosting unit-cost
rate. Keep the May 2026 commitment renegotiation as a historical reference.

## Scenario versioning

Never overwrite a forecast. Use:

- `2026_Q2_Forecast`
- `2026_Q3_Forecast`
- `FY2027_Budget_v1`
- `FY2027_Budget_v2`

Each version should include creation date, owner, locked actual months, and
assumption set.

## Refresh discipline

1. Append closed actuals.
2. Reconcile actual GL to operating facts.
3. Lock closed months in the current forecast.
4. Refresh drivers for future months.
5. Recalculate scenario outputs.
6. Run checks.
7. Export Tableau and Excel reporting layers.

## Privacy

Continue using invented company, customer, employee, and project information.
Do not merge prior-employer files into the public repository, even if labels are
renamed. Reconstruct the business logic using synthetic records instead.

