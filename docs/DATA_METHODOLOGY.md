# Data Methodology

## 1. Objective

The goal is to create a reusable synthetic dataset that behaves like the finance
data of a North American, mid-sized B2B SaaS company with an internal
professional-services organization.

The dataset must be safe to publish, coherent across finance and operating
tables, and rich enough to support:

- monthly actual versus budget and forecast reporting;
- ARR and customer-retention analysis;
- project revenue, utilization, and margin analysis;
- headcount and personnel-cost analysis;
- invoice, collection, and AR-aging analysis;
- a later driver-based budget and forecast model.

## 2. Three kinds of numbers

Every important value belongs to one of three categories:

### Public benchmark

A fact disclosed by an external source. Examples include Workday's FY2025
subscription mix and growth, Globant's 2024 gross margin, SaaS Capital's survey
median growth, and BLS compensation statistics.

### Modeling assumption

A transparent choice made for the fictional company. Examples include the
$78.0m FY2023 subscription-revenue starting point, a 3% annual contractual
uplift, segment-level churn probabilities, and the FY2026 budget growth rates.

### Simulated result

An output created by deterministic business rules and a seeded random process.
Examples include individual customer ACV, employee salary, project timing,
payment delay, and the monthly actual-versus-budget variance.

The repository never labels a modeling assumption or simulated result as a
publicly reported fact.

## 3. Company profile

`AsterCloud Solutions Inc.` is fictional. It sells workflow and planning
software to North American businesses and also performs implementation,
optimization, training, and managed services.

Key design choices:

| Item | Modeled profile | Rationale |
| --- | --- | --- |
| FY2023 revenue | $95.0m | Large enough for a full FP&A organization but still private-company scale |
| FY2025 revenue | $130.5m | Produces a mature growth profile rather than venture-stage hypergrowth |
| FY2025 mix | ~84% subscription / ~16% services | More services-heavy than Workday so project FP&A remains material |
| FY2025 subscription GM | ~77% | Below Workday's public-company scale because support and cloud operations are less leveraged |
| FY2025 services GM | ~33% | Close to the economics of a healthy technology-services delivery model |
| Fiscal year | Calendar year | Simplifies monthly FP&A reporting |
| Reporting cutoff | 2026-06-30 | Supports YTD actuals and a 6+6 forecast |

## 4. Public anchors and translation

### Workday FY2025 Form 10-K

URL:
https://www.sec.gov/Archives/edgar/data/1327811/000132781125000056/wday-20250131.htm

The filing reports:

- subscription services at about 91% of FY2025 revenue;
- subscription growth of 17% and professional-services growth of 11%;
- gross revenue retention of about 98%;
- ratable subscription revenue recognition;
- T&M and fixed-price services recognized over time;
- cloud hosting, support, delivery labor, subcontractors, product development,
  sales and marketing, and G&A as major cost categories.

Translation: AsterCloud uses the same economic structure but a lower
subscription mix, lower scale efficiency, and lower retention than Workday.

### Globant 2024 Form 20-F

URL:
https://www.sec.gov/Archives/edgar/data/1557860/000162828025009110/glob-20241231.htm

Globant reported a 35.7% 2024 gross margin and describes project economics
driven by bill rates, staffing mix, utilization, wage inflation, T&M contracts,
and fixed-price progress.

Translation: AsterCloud's services organization is calibrated around low-to-mid
30% gross margins, with monthly variation caused by utilization, subcontractor
mix, and project timing.

### SaaS Capital 2025 benchmark

URL:
https://www.saas-capital.com/research/private-saas-company-growth-rate-benchmarks/

The survey reports a 25% median growth rate for private B2B SaaS respondents and
a positive relationship between net revenue retention and growth.

Translation: AsterCloud's FY2026 subscription budget growth is 18%, below the
survey median because the fictional company is larger and more mature.

### BLS compensation data

URLs:

- https://www.bls.gov/news.release/archives/ecec_09122025.htm
- https://www.bls.gov/oes/2024/may/oes_ind.htm

Translation: BLS data provides directional salary and benefits anchors.
AsterCloud applies job-family salary bands, geographic multipliers, annual merit
increases, bonus accrual, benefits, and payroll tax. These are not BLS
microdata, and no employee record is real.

## 5. Generation logic

### Customers and subscriptions

- 300 synthetic customer records across Enterprise, Mid-Market, and SMB.
- ACV follows bounded log-normal distributions by segment.
- Contract starts are distributed between 2020 and June 2026.
- MRR rolls monthly using new, expansion, contraction, and churn movements.
- A 3% contractual uplift is applied during renewal months.
- Annual churn probabilities are 1.8% Enterprise, 4.0% Mid-Market, and 7.0% SMB.
- Subscription revenue uses average opening and ending MRR in event months.
- FY2023 subscription revenue is scaled to exactly $78.0m; all customer-level
  amounts retain their relative distribution.

### Projects and services

- 220 synthetic projects across implementation, optimization, training, and
  managed services.
- Thirty projects begin in the second half of 2022 and enter the reporting
  window as opening backlog, avoiding an artificial January 2023 start-up
  effect. Transaction facts begin in January 2023.
- Contracts are T&M or fixed price.
- Revenue is recognized over the complete planned delivery curve; only the
  portion inside the reporting window is included in the fact table.
- Annual services revenue is calibrated to $17.0m in 2023, $19.5m in 2024,
  $21.5m in 2025, and $10.4m in H1 2026.
- Project billable hours are allocated from employee-month timesheet capacity
  using a persistent delivery-intensity factor by project type and contract.
- A small, seeded overrun cohort is applied more often to fixed-price work,
  creating realistic project-margin exceptions without changing total
  services-team capacity.
- Direct project labor equals allocated billable hours multiplied by the
  services organization's loaded cost per available hour. Internal and bench
  capacity remains in the services P&L, so project contribution margin is not
  artificially penalized for organization-wide idle time.
- Subcontractor and travel costs vary by project type.
- Project revenue, subcontractors, and travel tie to GL services accounts;
  total services compensation ties from employee-month payroll to the GL.

### Employees and payroll

- 505 anonymized employee IDs; no names or personal data.
- Salary is driven by job family, level, region, and bounded variation.
- Annual merit increase is 3.5%.
- Monthly personnel cost includes base salary, variable compensation accrual,
  benefits, and employer payroll tax.
- FTE, salary, and cost are generated for each active employee-month.
- Professional-services employees also receive available, billable, internal,
  and bench hours.

### GL actuals

The GL is a presentation ledger: revenue and expense amounts are positive.
Account metadata identifies the statement section and favorable direction.

Actual entries are built from the operating facts:

- subscription revenue from MRR;
- services revenue and project costs from project financials;
- compensation from employee-month payroll;
- hosting from subscription revenue and unit-cost assumptions;
- commissions from revenue;
- marketing, tools, facilities, IT, recruiting, professional fees, bad debt,
  travel, and D&A from documented cost drivers.

### Budget and forecast

FY2026 Budget starts with the 2025 monthly pattern and applies account-specific
growth or cost assumptions. It is stored at:

`month + account + department + region + business line`.

The 2026 Q2 Forecast is a 6+6 forecast:

- January-June equals closed actuals;
- July-December revises the budget for churn, services timing, hiring delays,
  cloud savings, and selected cost pressure.

### Invoices and AR

- Subscription invoices follow annual or quarterly cadence.
- Services invoices are raised in arrears.
- Payment terms vary by segment.
- Payment delay varies by credit-risk tier.
- Open and partially paid invoices feed the AR-aging view as of 2026-06-30.

## 6. Designed business events

The following events create a coherent management narrative:

1. One large enterprise customer churns in April 2026.
2. A second enterprise customer churns in June 2026.
3. Services utilization is soft in Q1 and improves in May-June.
4. Cloud hosting unit cost falls after a May vendor renegotiation.
5. Hiring delays create favorable payroll variance but constrain growth.

These events appear in source facts, GL results, planning views, and management
outputs. They are not dashboard-only labels.

## 7. Reproducibility and controls

- Random seed: `20250725`.
- Generated tables use stable prefixed IDs.
- Monetary values are stored to two decimals.
- The SQL control suite verifies:
  - subscription revenue to GL;
  - services revenue to GL;
  - services payroll to GL;
  - invoice equation;
  - twelve budget and forecast periods;
  - nonnegative MRR;
  - valid utilization;
  - foreign-key integrity.

## 8. Limitations

- This is a management-reporting model, not a complete GAAP ledger.
- It does not include balance sheet, cash flow statement, taxes, equity, stock
  compensation, deferred commissions, or full ASC 606 contract schedules.
- Canadian compensation is reported in USD-equivalent values; detailed FX
  remeasurement is outside scope.
- Budget and forecast are at a higher grain than actual transactions, as is
  common in FP&A.
- Public benchmarks define plausible ranges; they do not prove that any one
  simulated customer, employee, or project would exist in reality.
