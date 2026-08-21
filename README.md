# AsterCloud FP&A Power BI

Power BI implementation of the AsterCloud monthly FP&A reporting case. It uses the same nine SQL-processed reporting datasets as the Excel and Tableau deliverables, so no additional business data was created for this version.

![Executive overview preview](preview/powerbi_executive_overview.png)

## Deliverable

- `AsterCloud_FPA_PowerBI.pbip`: Power BI Project entry point.
- `AsterCloud_FPA_PowerBI.SemanticModel/`: Power Query M, relationships, and DAX measures in TMDL format.
- `AsterCloud_FPA_PowerBI.Report/`: four PBIR report pages and their visual definitions.
- `data/processed/`: the nine SQL reporting outputs used by Power BI, Tableau, and Excel.
- `data/raw/dim_date_month.csv`: the shared month dimension.
- `preview/powerbi_executive_overview.png`: static design preview for GitHub and HR review.

## Report Pages

1. **Executive Overview**: H1 revenue, variance, margins, EBITDA, ARR, FTE, utilization, monthly trend, P&L variance, and full-year outlook.
2. **Revenue & ARR**: recurring revenue mix, ARR movements, customer segment mix, and customer concentration.
3. **Cost & Operations**: personnel cost, headcount, services utilization, and project-margin detail.
4. **AR & Collections**: receivables aging, regional exposure, and invoice-level collection priorities.

## Power BI Workflow

```text
SQL-processed CSV outputs
        -> Power Query import and data types
        -> month-dimension relationships
        -> reusable DAX measures
        -> four management-reporting pages
```

The semantic model reads the public repository through the `RepositoryRawBaseUrl` Power Query parameter. The same CSV files are also included in this folder for transparent review.

## Open in Power BI Desktop

1. Use Power BI Desktop on Windows.
2. Open `AsterCloud_FPA_PowerBI.pbip`.
3. When prompted for `raw.githubusercontent.com` credentials, choose **Anonymous**.
4. Refresh the model.
5. Save as `.pbix` if a single-file workbook is needed.

## Model Notes

- `DimDate` filters the monthly P&L, KPI, ARR, headcount, and utilization tables.
- Project margin, customer TTM, AR aging, and quality checks remain snapshot tables at their own grains.
- DAX contains actual, budget, forecast, favorable-variance, ARR, headcount, utilization, project-margin, and collections measures.
- The data is synthetic and calibrated to realistic B2B SaaS FP&A ranges. It does not contain real employer data.

Power BI Desktop is a Windows application. This repository provides the editable PBIP source; the included PNG is a data-accurate design preview, not a screenshot from Power BI Desktop.
