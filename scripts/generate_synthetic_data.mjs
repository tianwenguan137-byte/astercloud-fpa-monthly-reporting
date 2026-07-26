import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = path.resolve(SCRIPT_DIR, "..");
const CSV_DIR = path.join(PROJECT_DIR, "data", "csv");
const REPORT_START_MONTH = "2023-01-01";
const AS_OF_MONTH = "2026-06-01";
const AS_OF_DATE = "2026-06-30";
const SEED = 20250725;

function mulberry32(seed) {
  return function random() {
    let t = (seed += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const random = mulberry32(SEED);

function normal(mean = 0, stdDev = 1) {
  const u = Math.max(random(), 1e-12);
  const v = Math.max(random(), 1e-12);
  return mean + stdDev * Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

function clamp(value, minimum, maximum) {
  return Math.min(maximum, Math.max(minimum, value));
}

function round(value, decimals = 2) {
  const scale = 10 ** decimals;
  return Math.round((value + Number.EPSILON) * scale) / scale;
}

function choice(items) {
  return items[Math.floor(random() * items.length)];
}

function weightedChoice(items) {
  const draw = random();
  let cumulative = 0;
  for (const item of items) {
    cumulative += item.weight;
    if (draw <= cumulative) return item.value;
  }
  return items.at(-1).value;
}

function monthSerial(month) {
  const [year, monthNumber] = month.slice(0, 7).split("-").map(Number);
  return year * 12 + monthNumber - 1;
}

function monthFromSerial(serial) {
  const year = Math.floor(serial / 12);
  const monthNumber = (serial % 12) + 1;
  return `${year}-${String(monthNumber).padStart(2, "0")}-01`;
}

function addMonths(month, count) {
  return monthFromSerial(monthSerial(month) + count);
}

function monthsBetween(start, end) {
  const result = [];
  for (let serial = monthSerial(start); serial <= monthSerial(end); serial += 1) {
    result.push(monthFromSerial(serial));
  }
  return result;
}

function yearOf(month) {
  return Number(month.slice(0, 4));
}

function monthNumber(month) {
  return Number(month.slice(5, 7));
}

function quarterOf(month) {
  return `Q${Math.ceil(monthNumber(month) / 3)}`;
}

function isoDateFromOffset(baseDate, dayOffset) {
  const date = new Date(`${baseDate}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() + dayOffset);
  return date.toISOString().slice(0, 10);
}

function csvEscape(value) {
  if (value === null || value === undefined) return "";
  const stringValue = String(value);
  if (/[",\n]/.test(stringValue)) return `"${stringValue.replaceAll('"', '""')}"`;
  return stringValue;
}

async function writeCsv(fileName, rows, columns) {
  const lines = [columns.join(",")];
  for (const row of rows) {
    lines.push(columns.map((column) => csvEscape(row[column])).join(","));
  }
  await fs.writeFile(path.join(CSV_DIR, fileName), `${lines.join("\n")}\n`, "utf8");
}

const regions = [
  {
    region_id: "R01",
    region_name: "US West",
    primary_hub: "San Francisco CA",
    country: "United States",
    currency: "USD",
    salary_index: 1.16,
    revenue_weight: 0.3,
  },
  {
    region_id: "R02",
    region_name: "US Central",
    primary_hub: "Austin TX",
    country: "United States",
    currency: "USD",
    salary_index: 0.96,
    revenue_weight: 0.24,
  },
  {
    region_id: "R03",
    region_name: "US East",
    primary_hub: "New York NY",
    country: "United States",
    currency: "USD",
    salary_index: 1.1,
    revenue_weight: 0.34,
  },
  {
    region_id: "R04",
    region_name: "Canada",
    primary_hub: "Toronto ON",
    country: "Canada",
    currency: "CAD",
    salary_index: 0.82,
    revenue_weight: 0.12,
  },
];

const departments = [
  ["D00", "Revenue Operations", "Revenue", "CC-000", "Chief Revenue Officer"],
  ["D01", "Cloud Operations", "Cost of Revenue", "CC-100", "VP Cloud Operations"],
  ["D02", "Customer Support", "Cost of Revenue", "CC-110", "VP Customer Success"],
  ["D03", "Professional Services", "Cost of Revenue", "CC-120", "VP Professional Services"],
  ["D04", "Sales", "Sales & Marketing", "CC-200", "Chief Revenue Officer"],
  ["D05", "Marketing", "Sales & Marketing", "CC-210", "Chief Marketing Officer"],
  ["D06", "Product & Engineering", "Research & Development", "CC-300", "Chief Product Officer"],
  ["D07", "Finance", "General & Administrative", "CC-400", "Chief Financial Officer"],
  ["D08", "People", "General & Administrative", "CC-410", "Chief People Officer"],
  ["D09", "Legal & Compliance", "General & Administrative", "CC-420", "General Counsel"],
  ["D10", "Information Technology", "General & Administrative", "CC-430", "Chief Information Officer"],
  ["D11", "Executive", "General & Administrative", "CC-440", "Chief Executive Officer"],
].map(([department_id, department_name, function_group, cost_center, budget_owner]) => ({
  department_id,
  department_name,
  function_group,
  cost_center,
  budget_owner,
}));

const accounts = [
  ["A4000", "4000", "Subscription Revenue", "Revenue", "Subscription Revenue", "Subscription", "Higher is favorable", 10],
  ["A4010", "4010", "Implementation and Consulting Revenue", "Revenue", "Professional Services Revenue", "Services", "Higher is favorable", 20],
  ["A4020", "4020", "Training Revenue", "Revenue", "Professional Services Revenue", "Services", "Higher is favorable", 30],
  ["A5000", "5000", "Cloud Hosting", "Cost of Revenue", "Cost of Subscription", "Subscription", "Lower is favorable", 40],
  ["A5010", "5010", "Customer Support Compensation", "Cost of Revenue", "Cost of Subscription", "Subscription", "Lower is favorable", 50],
  ["A5020", "5020", "Services Delivery Compensation", "Cost of Revenue", "Cost of Services", "Services", "Lower is favorable", 60],
  ["A5030", "5030", "Services Subcontractors", "Cost of Revenue", "Cost of Services", "Services", "Lower is favorable", 70],
  ["A5040", "5040", "Project Travel and Other", "Cost of Revenue", "Cost of Services", "Services", "Lower is favorable", 80],
  ["A5050", "5050", "Third-Party Subscription Tools", "Cost of Revenue", "Cost of Subscription", "Subscription", "Lower is favorable", 90],
  ["A6100", "6100", "Sales Compensation", "Operating Expense", "Sales & Marketing", "Corporate", "Lower is favorable", 100],
  ["A6110", "6110", "Sales Commissions", "Operating Expense", "Sales & Marketing", "Corporate", "Lower is favorable", 110],
  ["A6120", "6120", "Marketing Compensation", "Operating Expense", "Sales & Marketing", "Corporate", "Lower is favorable", 120],
  ["A6130", "6130", "Marketing Programs", "Operating Expense", "Sales & Marketing", "Corporate", "Lower is favorable", 130],
  ["A6200", "6200", "Product and Engineering Compensation", "Operating Expense", "Research & Development", "Corporate", "Lower is favorable", 140],
  ["A6210", "6210", "Engineering Tools and Test Infrastructure", "Operating Expense", "Research & Development", "Corporate", "Lower is favorable", 150],
  ["A6300", "6300", "G&A Compensation", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 160],
  ["A6310", "6310", "Facilities and Workplace", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 170],
  ["A6320", "6320", "Corporate IT and Software", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 180],
  ["A6330", "6330", "Professional Fees", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 190],
  ["A6340", "6340", "Recruiting", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 200],
  ["A6350", "6350", "Corporate Travel and Entertainment", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 210],
  ["A6360", "6360", "Bad Debt Expense", "Operating Expense", "General & Administrative", "Corporate", "Lower is favorable", 220],
  ["A6370", "6370", "Depreciation and Amortization", "D&A", "Depreciation & Amortization", "Corporate", "Lower is favorable", 230],
].map(
  ([account_id, account_code, account_name, statement_section, pnl_line, business_line, favorable_direction, sort_order]) => ({
    account_id,
    account_code,
    account_name,
    statement_section,
    pnl_line,
    business_line,
    natural_balance: statement_section === "Revenue" ? "Credit" : "Debit",
    favorable_direction,
    sort_order,
  }),
);

const accountById = new Map(accounts.map((account) => [account.account_id, account]));
const regionById = new Map(regions.map((region) => [region.region_id, region]));
const departmentById = new Map(departments.map((department) => [department.department_id, department]));
const actualMonths = monthsBetween("2023-01-01", AS_OF_MONTH);
const planMonths = monthsBetween("2026-01-01", "2026-12-01");

const dateMonths = monthsBetween("2023-01-01", "2026-12-01").map((month) => ({
  month_start: month,
  calendar_year: yearOf(month),
  calendar_quarter: quarterOf(month),
  month_number: monthNumber(month),
  month_name: new Date(`${month}T00:00:00Z`).toLocaleString("en-US", { month: "long", timeZone: "UTC" }),
  fiscal_year: `FY${yearOf(month)}`,
  fiscal_quarter: `${yearOf(month)} ${quarterOf(month)}`,
  period_status: monthSerial(month) <= monthSerial(AS_OF_MONTH) ? "Actual" : "Future",
}));

const customerPrefixes = [
  "Northstar",
  "BluePeak",
  "Evergreen",
  "Harbor",
  "Summit",
  "Redwood",
  "Clearwater",
  "Ironwood",
  "Silverline",
  "BrightPath",
  "Cedar",
  "Frontier",
  "Atlas",
  "Meridian",
  "Nova",
  "Keystone",
  "Crescent",
  "Vantage",
  "Beacon",
  "Pioneer",
  "Oakridge",
  "Highland",
  "Westbridge",
  "Stonegate",
  "Lakeview",
];

const customerSuffixes = [
  "Health",
  "Retail",
  "Logistics",
  "Financial",
  "Manufacturing",
  "Media",
  "Energy",
  "Technology",
  "Foods",
  "Education",
  "Mobility",
  "Insurance",
];

const industries = [
  "Healthcare",
  "Retail and E-commerce",
  "Financial Services",
  "Manufacturing",
  "Technology",
  "Business Services",
  "Logistics",
  "Energy",
];

function chooseRegion() {
  return weightedChoice(regions.map((region) => ({ value: region.region_id, weight: region.revenue_weight })));
}

function chooseCustomerStartMonth() {
  const bucket = weightedChoice([
    { value: "pre", weight: 0.62 },
    { value: "2023", weight: 0.13 },
    { value: "2024", weight: 0.11 },
    { value: "2025", weight: 0.09 },
    { value: "2026", weight: 0.05 },
  ]);
  if (bucket === "pre") {
    return monthFromSerial(monthSerial("2020-01-01") + Math.floor(random() * 36));
  }
  const count = bucket === "2026" ? 6 : 12;
  return `${bucket}-${String(1 + Math.floor(random() * count)).padStart(2, "0")}-01`;
}

const customers = [];
for (let index = 1; index <= 300; index += 1) {
  const segment = weightedChoice([
    { value: "Enterprise", weight: 0.24 },
    { value: "Mid-Market", weight: 0.46 },
    { value: "SMB", weight: 0.3 },
  ]);
  const baseAnnualContract =
    segment === "Enterprise"
      ? clamp(Math.exp(normal(Math.log(900000), 0.43)), 350000, 2500000)
      : segment === "Mid-Market"
        ? clamp(Math.exp(normal(Math.log(185000), 0.4)), 70000, 480000)
        : clamp(Math.exp(normal(Math.log(45000), 0.35)), 18000, 110000);
  const startMonth = chooseCustomerStartMonth();
  const paymentTerms =
    segment === "Enterprise"
      ? weightedChoice([
          { value: 45, weight: 0.55 },
          { value: 60, weight: 0.35 },
          { value: 30, weight: 0.1 },
        ])
      : segment === "Mid-Market"
        ? weightedChoice([
            { value: 30, weight: 0.55 },
            { value: 45, weight: 0.35 },
            { value: 60, weight: 0.1 },
          ])
        : weightedChoice([
            { value: 30, weight: 0.8 },
            { value: 15, weight: 0.2 },
          ]);
  const creditRisk = weightedChoice([
    { value: "A", weight: segment === "Enterprise" ? 0.72 : 0.55 },
    { value: "B", weight: segment === "Enterprise" ? 0.23 : 0.35 },
    { value: "C", weight: segment === "Enterprise" ? 0.05 : 0.1 },
  ]);
  const billingCadence =
    segment === "Enterprise"
      ? weightedChoice([
          { value: "Annual", weight: 0.85 },
          { value: "Quarterly", weight: 0.15 },
        ])
      : segment === "Mid-Market"
        ? weightedChoice([
            { value: "Annual", weight: 0.6 },
            { value: "Quarterly", weight: 0.4 },
          ])
        : weightedChoice([
            { value: "Annual", weight: 0.3 },
            { value: "Quarterly", weight: 0.7 },
          ]);
  const customerName = `${choice(customerPrefixes)} ${choice(customerSuffixes)} ${String(index).padStart(3, "0")}`;
  customers.push({
    customer_id: `C${String(index).padStart(4, "0")}`,
    customer_name: customerName,
    industry: choice(industries),
    segment,
    region_id: chooseRegion(),
    contract_start_month: startMonth,
    renewal_month: monthNumber(startMonth),
    billing_cadence: billingCadence,
    payment_terms_days: paymentTerms,
    credit_risk_tier: creditRisk,
    initial_acv_usd: round(baseAnnualContract),
    churn_month: "",
    current_arr_usd: 0,
  });
}

const forcedChurnCustomers = customers
  .filter((customer) => customer.segment === "Enterprise" && monthSerial(customer.contract_start_month) < monthSerial("2023-01-01"))
  .sort((left, right) => right.initial_acv_usd - left.initial_acv_usd)
  .slice(0, 2);

const forcedChurnByCustomer = new Map([
  [forcedChurnCustomers[0].customer_id, "2026-04-01"],
  [forcedChurnCustomers[1].customer_id, "2026-06-01"],
]);

const subscriptionRows = [];
for (const customer of customers) {
  const startSerial = monthSerial(customer.contract_start_month);
  let endingMrr =
    startSerial < monthSerial("2023-01-01") ? customer.initial_acv_usd / 12 : 0;
  let churned = false;
  for (const month of actualMonths) {
    const serial = monthSerial(month);
    if (serial < startSerial || churned) continue;
    const openingMrr = endingMrr;
    let newMrr = 0;
    let expansionMrr = 0;
    let contractionMrr = 0;
    let churnMrr = 0;
    if (serial === startSerial) {
      newMrr = customer.initial_acv_usd / 12;
    } else if (monthNumber(month) === customer.renewal_month) {
      const priceIncrease = openingMrr * 0.03;
      const expansionProbability = customer.segment === "Enterprise" ? 0.72 : customer.segment === "Mid-Market" ? 0.58 : 0.42;
      expansionMrr =
        priceIncrease +
        (random() < expansionProbability
          ? openingMrr * clamp(normal(customer.segment === "Enterprise" ? 0.075 : 0.055, 0.025), 0.015, 0.14)
          : 0);
      if (random() < (customer.segment === "Enterprise" ? 0.08 : 0.14)) {
        contractionMrr = openingMrr * clamp(normal(0.045, 0.02), 0.01, 0.1);
      }
      const annualChurnProbability = customer.segment === "Enterprise" ? 0.018 : customer.segment === "Mid-Market" ? 0.04 : 0.07;
      const churnDraw = random();
      if (!forcedChurnByCustomer.has(customer.customer_id) && churnDraw < annualChurnProbability) {
        churnMrr = openingMrr + expansionMrr - contractionMrr;
      }
    }
    if (forcedChurnByCustomer.get(customer.customer_id) === month) {
      churnMrr = openingMrr + expansionMrr - contractionMrr;
    }
    endingMrr = Math.max(0, openingMrr + newMrr + expansionMrr - contractionMrr - churnMrr);
    const recognizedRevenue = (openingMrr + endingMrr) / 2;
    subscriptionRows.push({
      month_start: month,
      customer_id: customer.customer_id,
      region_id: customer.region_id,
      segment: customer.segment,
      plan_tier: customer.segment === "Enterprise" ? "Enterprise Suite" : customer.segment === "Mid-Market" ? "Business" : "Core",
      opening_mrr_usd: openingMrr,
      new_mrr_usd: newMrr,
      expansion_mrr_usd: expansionMrr,
      contraction_mrr_usd: contractionMrr,
      churn_mrr_usd: churnMrr,
      ending_mrr_usd: endingMrr,
      recognized_revenue_usd: recognizedRevenue,
    });
    if (churnMrr > 0 && endingMrr === 0) {
      customer.churn_month = month;
      churned = true;
    }
  }
}

const rawSubscription2023 = subscriptionRows
  .filter((row) => yearOf(row.month_start) === 2023)
  .reduce((sum, row) => sum + row.recognized_revenue_usd, 0);
const subscriptionScale = 78000000 / rawSubscription2023;
for (const row of subscriptionRows) {
  for (const field of [
    "opening_mrr_usd",
    "new_mrr_usd",
    "expansion_mrr_usd",
    "contraction_mrr_usd",
    "churn_mrr_usd",
    "ending_mrr_usd",
    "recognized_revenue_usd",
  ]) {
    row[field] = round(row[field] * subscriptionScale);
  }
}
for (const customer of customers) {
  customer.initial_acv_usd = round(customer.initial_acv_usd * subscriptionScale);
  const current = subscriptionRows.findLast(
    (row) => row.customer_id === customer.customer_id && row.month_start === AS_OF_MONTH,
  );
  customer.current_arr_usd = current ? round(current.ending_mrr_usd * 12) : 0;
}

const departmentProfiles = {
  D01: { job_family: "Cloud Engineering", salary: 132000, weight: 0.065 },
  D02: { job_family: "Customer Support", salary: 82000, weight: 0.095 },
  D03: { job_family: "Implementation Consulting", salary: 108000, weight: 0.18 },
  D04: { job_family: "Enterprise Sales", salary: 112000, weight: 0.18 },
  D05: { job_family: "Marketing", salary: 105000, weight: 0.055 },
  D06: { job_family: "Software Engineering", salary: 148000, weight: 0.295 },
  D07: { job_family: "Finance and Accounting", salary: 108000, weight: 0.04 },
  D08: { job_family: "People Operations", salary: 98000, weight: 0.025 },
  D09: { job_family: "Legal and Compliance", salary: 158000, weight: 0.02 },
  D10: { job_family: "Corporate IT", salary: 118000, weight: 0.025 },
  D11: { job_family: "Executive Leadership", salary: 255000, weight: 0.02 },
};

function chooseDepartment() {
  return weightedChoice(
    Object.entries(departmentProfiles).map(([departmentId, profile]) => ({
      value: departmentId,
      weight: profile.weight,
    })),
  );
}

function chooseEmployeeStartMonth(index) {
  if (index <= 330) return monthFromSerial(monthSerial("2019-01-01") + Math.floor(random() * 48));
  if (index <= 385) return monthFromSerial(monthSerial("2023-01-01") + Math.floor(random() * 12));
  if (index <= 435) return monthFromSerial(monthSerial("2024-01-01") + Math.floor(random() * 12));
  if (index <= 480) return monthFromSerial(monthSerial("2025-01-01") + Math.floor(random() * 12));
  return monthFromSerial(monthSerial("2026-01-01") + Math.floor(random() * 6));
}

function chooseEmployeeRegion(departmentId) {
  if (departmentId === "D06" || departmentId === "D01") {
    return weightedChoice([
      { value: "R01", weight: 0.4 },
      { value: "R02", weight: 0.3 },
      { value: "R03", weight: 0.15 },
      { value: "R04", weight: 0.15 },
    ]);
  }
  if (departmentId === "D04" || departmentId === "D03" || departmentId === "D02") return chooseRegion();
  return weightedChoice([
    { value: "R02", weight: 0.45 },
    { value: "R03", weight: 0.3 },
    { value: "R01", weight: 0.15 },
    { value: "R04", weight: 0.1 },
  ]);
}

const employees = [];
for (let index = 1; index <= 505; index += 1) {
  const departmentId = chooseDepartment();
  const level = weightedChoice([
    { value: "Associate", weight: 0.2 },
    { value: "Professional", weight: 0.3 },
    { value: "Senior", weight: 0.27 },
    { value: "Manager", weight: 0.14 },
    { value: "Director", weight: 0.07 },
    { value: "VP", weight: 0.02 },
  ]);
  const levelFactor = {
    Associate: 0.72,
    Professional: 0.9,
    Senior: 1.1,
    Manager: 1.28,
    Director: 1.6,
    VP: 2.15,
  }[level];
  const startMonth = chooseEmployeeStartMonth(index);
  const regionId = chooseEmployeeRegion(departmentId);
  const salary =
    departmentProfiles[departmentId].salary *
    levelFactor *
    regionById.get(regionId).salary_index *
    clamp(normal(1, 0.08), 0.82, 1.22);
  let endMonth = "";
  const attritionProbability = monthSerial(startMonth) < monthSerial("2025-01-01") ? 0.18 : 0.06;
  if (random() < attritionProbability) {
    const earliestEnd = Math.max(monthSerial("2023-01-01"), monthSerial(startMonth) + 8);
    if (earliestEnd <= monthSerial(AS_OF_MONTH)) {
      endMonth = monthFromSerial(earliestEnd + Math.floor(random() * (monthSerial(AS_OF_MONTH) - earliestEnd + 1)));
    }
  }
  employees.push({
    employee_id: `E${String(index).padStart(4, "0")}`,
    department_id: departmentId,
    region_id: regionId,
    job_family: departmentProfiles[departmentId].job_family,
    level,
    employment_type: random() < 0.985 ? "Full-time" : "Part-time",
    start_month: startMonth,
    end_month: endMonth,
    annual_base_salary_at_hire_usd: round(salary),
  });
}

const headcountRows = [];
const utilizationRows = [];
for (const employee of employees) {
  const startSerial = Math.max(monthSerial(employee.start_month), monthSerial("2023-01-01"));
  const endSerial = employee.end_month ? monthSerial(employee.end_month) - 1 : monthSerial(AS_OF_MONTH);
  if (startSerial > endSerial) continue;
  for (let serial = startSerial; serial <= endSerial; serial += 1) {
    const month = monthFromSerial(serial);
    const meritYears = Math.max(0, yearOf(month) - yearOf(employee.start_month));
    const annualBase = employee.annual_base_salary_at_hire_usd * 1.035 ** meritYears;
    const fte = employee.employment_type === "Part-time" ? 0.6 : 1;
    const monthlyBase = (annualBase / 12) * fte;
    const bonusTarget =
      employee.department_id === "D04"
        ? employee.level === "VP" || employee.level === "Director"
          ? 0.3
          : 0.2
        : employee.level === "VP"
          ? 0.2
          : employee.level === "Director"
            ? 0.14
            : 0.08;
    const bonusAccrual = monthlyBase * bonusTarget;
    const benefits = monthlyBase * 0.15;
    const payrollTaxes = monthlyBase * 0.0765;
    const totalPersonnelCost = monthlyBase + bonusAccrual + benefits + payrollTaxes;
    headcountRows.push({
      month_start: month,
      employee_id: employee.employee_id,
      department_id: employee.department_id,
      region_id: employee.region_id,
      fte,
      monthly_base_salary_usd: round(monthlyBase),
      bonus_accrual_usd: round(bonusAccrual),
      benefits_usd: round(benefits),
      payroll_taxes_usd: round(payrollTaxes),
      total_personnel_cost_usd: round(totalPersonnelCost),
    });
    if (employee.department_id === "D03") {
      const availableHours = 166.4 - weightedChoice([
        { value: 0, weight: 0.25 },
        { value: 8, weight: 0.45 },
        { value: 16, weight: 0.25 },
        { value: 24, weight: 0.05 },
      ]);
      let baseUtilization = 0.755;
      if (monthNumber(month) === 1 || monthNumber(month) === 2) baseUtilization -= 0.035;
      if (monthNumber(month) === 12) baseUtilization -= 0.05;
      if (yearOf(month) === 2026 && monthNumber(month) <= 3) baseUtilization -= 0.035;
      if (yearOf(month) === 2026 && monthNumber(month) >= 5) baseUtilization += 0.015;
      const utilizationRate = clamp(normal(baseUtilization, 0.055), 0.48, 0.9);
      const billableHours = availableHours * utilizationRate;
      const internalHours = Math.min(availableHours - billableHours, availableHours * clamp(normal(0.1, 0.025), 0.04, 0.18));
      utilizationRows.push({
        month_start: month,
        employee_id: employee.employee_id,
        region_id: employee.region_id,
        available_hours: round(availableHours, 1),
        billable_hours: round(billableHours, 1),
        internal_hours: round(internalHours, 1),
        bench_hours: round(availableHours - billableHours - internalHours, 1),
        utilization_rate: round(billableHours / availableHours, 4),
      });
    }
  }
}

const projectTypes = {
  Implementation: { weight: 0.45, minMonths: 4, maxMonths: 12, rawValue: 520000 },
  Optimization: { weight: 0.25, minMonths: 2, maxMonths: 7, rawValue: 270000 },
  Training: { weight: 0.12, minMonths: 1, maxMonths: 2, rawValue: 70000 },
  "Managed Services": { weight: 0.18, minMonths: 6, maxMonths: 18, rawValue: 360000 },
};

function chooseProjectStartMonth(index) {
  if (index <= 30) {
    const month = 6 + Math.floor(random() * 7);
    return `2022-${String(month).padStart(2, "0")}-01`;
  }
  const bucket = weightedChoice([
    { value: 2023, weight: 0.28 },
    { value: 2024, weight: 0.27 },
    { value: 2025, weight: 0.3 },
    { value: 2026, weight: 0.15 },
  ]);
  const monthCount = bucket === 2026 ? 6 : 12;
  return `${bucket}-${String(1 + Math.floor(random() * monthCount)).padStart(2, "0")}-01`;
}

const projects = [];
const rawProjectMonths = [];
const projectDeliveryIntensityById = new Map();
for (let index = 1; index <= 220; index += 1) {
  const projectType = weightedChoice(
    Object.entries(projectTypes).map(([type, profile]) => ({ value: type, weight: profile.weight })),
  );
  const profile = projectTypes[projectType];
  const startMonth = chooseProjectStartMonth(index);
  const activeCustomers = customers.filter(
    (customer) =>
      monthSerial(customer.contract_start_month) <= monthSerial(startMonth) &&
      (!customer.churn_month || monthSerial(customer.churn_month) > monthSerial(startMonth)),
  );
  const customer = choice(activeCustomers);
  const durationMonths = profile.minMonths + Math.floor(random() * (profile.maxMonths - profile.minMonths + 1));
  const endMonth = monthFromSerial(monthSerial(startMonth) + durationMonths - 1);
  const segmentFactor = customer.segment === "Enterprise" ? 1.7 : customer.segment === "Mid-Market" ? 0.9 : 0.35;
  const rawContractValue = profile.rawValue * segmentFactor * clamp(normal(1, 0.3), 0.45, 1.9);
  const contractType =
    projectType === "Training"
      ? "Fixed Price"
      : weightedChoice([
          { value: "Time and Materials", weight: 0.64 },
          { value: "Fixed Price", weight: 0.36 },
        ]);
  const projectId = `P${String(index).padStart(4, "0")}`;
  const baseDeliveryIntensity = {
    Implementation: 1.08,
    Optimization: 0.96,
    Training: 0.78,
    "Managed Services": 0.88,
  }[projectType];
  const overrunProbability = contractType === "Fixed Price" ? 0.11 : 0.035;
  const overrunFactor =
    random() < overrunProbability ? clamp(normal(1.45, 0.12), 1.25, 1.7) : 1;
  projectDeliveryIntensityById.set(
    projectId,
    clamp(
      baseDeliveryIntensity *
        (contractType === "Fixed Price" ? 1.04 : 1) *
        normal(1, 0.08) *
        overrunFactor,
      0.65,
      1.75,
    ),
  );
  const project = {
    project_id: projectId,
    customer_id: customer.customer_id,
    region_id: customer.region_id,
    project_type: projectType,
    contract_type: contractType,
    start_month: startMonth,
    planned_end_month: endMonth,
    status: monthSerial(endMonth) <= monthSerial(AS_OF_MONTH) ? "Completed" : "In Progress",
    contract_value_usd: 0,
    blended_bill_rate_usd: 0,
    actual_margin_pct: 0,
  };
  projects.push(project);
  const plannedProjectMonths = monthsBetween(startMonth, endMonth);
  const weights = plannedProjectMonths.map((_, monthIndex) => {
    if (projectType === "Managed Services" || contractType === "Time and Materials") return 1 + normal(0, 0.06);
    const midpoint = (plannedProjectMonths.length - 1) / 2;
    return Math.max(0.25, 1.25 - Math.abs(monthIndex - midpoint) / Math.max(1, midpoint + 0.5));
  });
  const totalWeight = weights.reduce((sum, value) => sum + value, 0);
  plannedProjectMonths.forEach((month, monthIndex) => {
    if (
      monthSerial(month) < monthSerial(REPORT_START_MONTH) ||
      monthSerial(month) > monthSerial(AS_OF_MONTH)
    ) {
      return;
    }
    rawProjectMonths.push({
      month_start: month,
      project_id: project.project_id,
      customer_id: customer.customer_id,
      region_id: customer.region_id,
      project_type: projectType,
      raw_revenue: rawContractValue * (weights[monthIndex] / totalWeight),
    });
  });
}

const servicesTargetByYear = new Map([
  [2023, 17000000],
  [2024, 19500000],
  [2025, 21500000],
  [2026, 10400000],
]);
const serviceScaleByYear = new Map();
for (const [year, target] of servicesTargetByYear) {
  const rawTotal = rawProjectMonths
    .filter((row) => yearOf(row.month_start) === year)
    .reduce((sum, row) => sum + row.raw_revenue, 0);
  serviceScaleByYear.set(year, target / rawTotal);
}

const servicePersonnelByMonth = new Map();
for (const row of headcountRows.filter((headcount) => headcount.department_id === "D03")) {
  servicePersonnelByMonth.set(
    row.month_start,
    (servicePersonnelByMonth.get(row.month_start) || 0) + row.total_personnel_cost_usd,
  );
}
const availableHoursByMonth = new Map();
const billableHoursByMonth = new Map();
for (const row of utilizationRows) {
  availableHoursByMonth.set(
    row.month_start,
    (availableHoursByMonth.get(row.month_start) || 0) + row.available_hours,
  );
  billableHoursByMonth.set(
    row.month_start,
    (billableHoursByMonth.get(row.month_start) || 0) + row.billable_hours,
  );
}

const projectDeliveryWeightByMonth = new Map();
for (const row of rawProjectMonths) {
  const revenue = row.raw_revenue * serviceScaleByYear.get(yearOf(row.month_start));
  row.revenue_usd = revenue;
  row.delivery_weight = revenue * projectDeliveryIntensityById.get(row.project_id);
  projectDeliveryWeightByMonth.set(
    row.month_start,
    (projectDeliveryWeightByMonth.get(row.month_start) || 0) + row.delivery_weight,
  );
}

const projectFinancialRows = rawProjectMonths.map((row) => {
  const deliveryShare = row.delivery_weight / (projectDeliveryWeightByMonth.get(row.month_start) || 1);
  const billableHours = (billableHoursByMonth.get(row.month_start) || 0) * deliveryShare;
  const costPerAvailableHour =
    (servicePersonnelByMonth.get(row.month_start) || 0) /
    Math.max(availableHoursByMonth.get(row.month_start) || 0, 1);
  const directLaborCost = billableHours * costPerAvailableHour;
  const subcontractorRate =
    row.project_type === "Implementation"
      ? clamp(normal(0.09, 0.035), 0.02, 0.18)
      : row.project_type === "Optimization"
        ? clamp(normal(0.06, 0.025), 0.01, 0.13)
        : clamp(normal(0.025, 0.015), 0, 0.08);
  const travelRate = row.project_type === "Training" ? 0.022 : clamp(normal(0.012, 0.006), 0.002, 0.03);
  const subcontractorCost = row.revenue_usd * subcontractorRate;
  const travelCost = row.revenue_usd * travelRate;
  return {
    month_start: row.month_start,
    project_id: row.project_id,
    customer_id: row.customer_id,
    region_id: row.region_id,
    revenue_usd: round(row.revenue_usd),
    direct_labor_cost_usd: round(directLaborCost),
    subcontractor_cost_usd: round(subcontractorCost),
    travel_cost_usd: round(travelCost),
    gross_profit_usd: round(row.revenue_usd - directLaborCost - subcontractorCost - travelCost),
    billable_hours: round(billableHours, 1),
  };
});

for (const project of projects) {
  const rows = projectFinancialRows.filter((row) => row.project_id === project.project_id);
  const revenue = rows.reduce((sum, row) => sum + row.revenue_usd, 0);
  const grossProfit = rows.reduce((sum, row) => sum + row.gross_profit_usd, 0);
  const billableHours = rows.reduce((sum, row) => sum + row.billable_hours, 0);
  const elapsed = rows.length;
  const plannedDuration = monthSerial(project.planned_end_month) - monthSerial(project.start_month) + 1;
  const completionPct = Math.min(1, elapsed / plannedDuration);
  project.contract_value_usd = round(revenue / Math.max(completionPct, 0.2));
  project.blended_bill_rate_usd = round(revenue / Math.max(billableHours, 1));
  project.actual_margin_pct = round(grossProfit / Math.max(revenue, 1), 4);
}

const glActuals = [];
let glRowNumber = 1;
function addGlRow({
  month,
  accountId,
  departmentId,
  regionId,
  customerId = "",
  projectId = "",
  businessLine,
  amount,
  sourceSystem,
  entryType,
}) {
  if (!Number.isFinite(amount) || Math.abs(amount) < 0.005) return;
  glActuals.push({
    gl_row_id: `GL${String(glRowNumber).padStart(7, "0")}`,
    month_start: month,
    account_id: accountId,
    department_id: departmentId,
    region_id: regionId,
    customer_id: customerId,
    project_id: projectId,
    business_line: businessLine,
    amount_usd: round(Math.abs(amount)),
    source_system: sourceSystem,
    entry_type: entryType,
  });
  glRowNumber += 1;
}

for (const row of subscriptionRows) {
  addGlRow({
    month: row.month_start,
    accountId: "A4000",
    departmentId: "D00",
    regionId: row.region_id,
    customerId: row.customer_id,
    businessLine: "Subscription",
    amount: row.recognized_revenue_usd,
    sourceSystem: "Subscription Billing",
    entryType: "Revenue Recognition",
  });
}

for (const row of projectFinancialRows) {
  const project = projects.find((candidate) => candidate.project_id === row.project_id);
  addGlRow({
    month: row.month_start,
    accountId: project.project_type === "Training" ? "A4020" : "A4010",
    departmentId: "D00",
    regionId: row.region_id,
    customerId: row.customer_id,
    projectId: row.project_id,
    businessLine: "Services",
    amount: row.revenue_usd,
    sourceSystem: "Project Accounting",
    entryType: "Revenue Recognition",
  });
  addGlRow({
    month: row.month_start,
    accountId: "A5030",
    departmentId: "D03",
    regionId: row.region_id,
    customerId: row.customer_id,
    projectId: row.project_id,
    businessLine: "Services",
    amount: row.subcontractor_cost_usd,
    sourceSystem: "Accounts Payable",
    entryType: "Vendor Cost",
  });
  addGlRow({
    month: row.month_start,
    accountId: "A5040",
    departmentId: "D03",
    regionId: row.region_id,
    customerId: row.customer_id,
    projectId: row.project_id,
    businessLine: "Services",
    amount: row.travel_cost_usd,
    sourceSystem: "Expense Management",
    entryType: "Project Expense",
  });
}

const personnelAccountByDepartment = {
  D01: "A5010",
  D02: "A5010",
  D03: "A5020",
  D04: "A6100",
  D05: "A6120",
  D06: "A6200",
  D07: "A6300",
  D08: "A6300",
  D09: "A6300",
  D10: "A6300",
  D11: "A6300",
};

const personnelByMonthDeptRegion = new Map();
const headcountByMonthDeptRegion = new Map();
const hiresByMonthRegion = new Map();
for (const row of headcountRows) {
  const key = `${row.month_start}|${row.department_id}|${row.region_id}`;
  personnelByMonthDeptRegion.set(key, (personnelByMonthDeptRegion.get(key) || 0) + row.total_personnel_cost_usd);
  headcountByMonthDeptRegion.set(key, (headcountByMonthDeptRegion.get(key) || 0) + row.fte);
}
for (const employee of employees) {
  if (monthSerial(employee.start_month) >= monthSerial("2023-01-01") && monthSerial(employee.start_month) <= monthSerial(AS_OF_MONTH)) {
    const key = `${employee.start_month}|${employee.region_id}`;
    hiresByMonthRegion.set(key, (hiresByMonthRegion.get(key) || 0) + 1);
  }
}

for (const [key, amount] of personnelByMonthDeptRegion) {
  const [month, departmentId, regionId] = key.split("|");
  addGlRow({
    month,
    accountId: personnelAccountByDepartment[departmentId],
    departmentId,
    regionId,
    businessLine: departmentId === "D03" ? "Services" : departmentId === "D01" || departmentId === "D02" ? "Subscription" : "Corporate",
    amount,
    sourceSystem: "Payroll",
    entryType: "Personnel Cost",
  });
}

function actualRevenueByMonthRegion(month, regionId, businessLine) {
  return glActuals
    .filter(
      (row) =>
        row.month_start === month &&
        row.region_id === regionId &&
        row.business_line === businessLine &&
        accountById.get(row.account_id).statement_section === "Revenue",
    )
    .reduce((sum, row) => sum + row.amount_usd, 0);
}

for (const month of actualMonths) {
  for (const region of regions) {
    const subscriptionRevenue = actualRevenueByMonthRegion(month, region.region_id, "Subscription");
    const servicesRevenue = actualRevenueByMonthRegion(month, region.region_id, "Services");
    const totalRevenue = subscriptionRevenue + servicesRevenue;
    if (subscriptionRevenue > 0) {
      let hostingRate = 0.109 - 0.0015 * (yearOf(month) - 2023);
      if (yearOf(month) === 2026 && monthNumber(month) <= 3) hostingRate += 0.004;
      if (yearOf(month) === 2026 && monthNumber(month) >= 5) hostingRate -= 0.008;
      addGlRow({
        month,
        accountId: "A5000",
        departmentId: "D01",
        regionId: region.region_id,
        businessLine: "Subscription",
        amount: subscriptionRevenue * hostingRate * clamp(normal(1, 0.015), 0.96, 1.04),
        sourceSystem: "Cloud Cost Management",
        entryType: "Cloud Consumption",
      });
      addGlRow({
        month,
        accountId: "A5050",
        departmentId: "D01",
        regionId: region.region_id,
        businessLine: "Subscription",
        amount: subscriptionRevenue * 0.014,
        sourceSystem: "Accounts Payable",
        entryType: "Third-Party License",
      });
    }
    if (totalRevenue > 0) {
      addGlRow({
        month,
        accountId: "A6110",
        departmentId: "D04",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: subscriptionRevenue * 0.047 + servicesRevenue * 0.02,
        sourceSystem: "Sales Compensation",
        entryType: "Commission Accrual",
      });
      const marketingSeasonality = monthNumber(month) >= 10 ? 1.24 : monthNumber(month) <= 3 ? 1.1 : 0.92;
      addGlRow({
        month,
        accountId: "A6130",
        departmentId: "D05",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: totalRevenue * 0.035 * marketingSeasonality,
        sourceSystem: "Accounts Payable",
        entryType: "Marketing Spend",
      });
      addGlRow({
        month,
        accountId: "A6350",
        departmentId: "D07",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: totalRevenue * (monthNumber(month) === 12 ? 0.0025 : 0.004),
        sourceSystem: "Expense Management",
        entryType: "Corporate Travel",
      });
      addGlRow({
        month,
        accountId: "A6360",
        departmentId: "D07",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: totalRevenue * 0.003,
        sourceSystem: "General Ledger",
        entryType: "Bad Debt Provision",
      });
    }
    const totalFteInRegion = departments.reduce(
      (sum, department) => sum + (headcountByMonthDeptRegion.get(`${month}|${department.department_id}|${region.region_id}`) || 0),
      0,
    );
    const engineeringFte =
      (headcountByMonthDeptRegion.get(`${month}|D06|${region.region_id}`) || 0) +
      (headcountByMonthDeptRegion.get(`${month}|D01|${region.region_id}`) || 0);
    if (engineeringFte > 0) {
      addGlRow({
        month,
        accountId: "A6210",
        departmentId: "D06",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: engineeringFte * 1450 + subscriptionRevenue * 0.0045,
        sourceSystem: "Accounts Payable",
        entryType: "Engineering Tooling",
      });
    }
    if (totalFteInRegion > 0) {
      addGlRow({
        month,
        accountId: "A6310",
        departmentId: "D10",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: totalFteInRegion * (region.region_id === "R01" || region.region_id === "R03" ? 760 : 590),
        sourceSystem: "Lease Administration",
        entryType: "Facilities",
      });
      addGlRow({
        month,
        accountId: "A6320",
        departmentId: "D10",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: totalFteInRegion * 410,
        sourceSystem: "Accounts Payable",
        entryType: "Corporate Software",
      });
    }
    const hires = hiresByMonthRegion.get(`${month}|${region.region_id}`) || 0;
    if (hires > 0) {
      addGlRow({
        month,
        accountId: "A6340",
        departmentId: "D08",
        regionId: region.region_id,
        businessLine: "Corporate",
        amount: hires * clamp(normal(11800, 1500), 8500, 16000),
        sourceSystem: "Recruiting",
        entryType: "Hiring Cost",
      });
    }
  }
  const totalMonthlyRevenue = glActuals
    .filter((row) => row.month_start === month && accountById.get(row.account_id).statement_section === "Revenue")
    .reduce((sum, row) => sum + row.amount_usd, 0);
  addGlRow({
    month,
    accountId: "A6330",
    departmentId: "D07",
    regionId: "R02",
    businessLine: "Corporate",
    amount: totalMonthlyRevenue * (monthNumber(month) <= 3 ? 0.018 : 0.012),
    sourceSystem: "Accounts Payable",
    entryType: "Professional Fees",
  });
  addGlRow({
    month,
    accountId: "A6370",
    departmentId: "D10",
    regionId: "R02",
    businessLine: "Corporate",
    amount: totalMonthlyRevenue * 0.018,
    sourceSystem: "Fixed Assets",
    entryType: "Depreciation",
  });
}

const actual2025ByKeyMonth = new Map();
for (const row of glActuals.filter((actual) => yearOf(actual.month_start) === 2025)) {
  const key = `${row.account_id}|${row.department_id}|${row.region_id}|${row.business_line}|${row.month_start}`;
  actual2025ByKeyMonth.set(key, (actual2025ByKeyMonth.get(key) || 0) + row.amount_usd);
}

const budgetGrowthByAccount = {
  A4000: 1.18,
  A4010: 1.14,
  A4020: 1.14,
  A5000: 1.105,
  A5010: 1.105,
  A5020: 1.11,
  A5030: 1.08,
  A5040: 1.1,
  A5050: 1.13,
  A6100: 1.13,
  A6110: 1.15,
  A6120: 1.11,
  A6130: 1.1,
  A6200: 1.14,
  A6210: 1.12,
  A6300: 1.1,
  A6310: 1.06,
  A6320: 1.11,
  A6330: 1.08,
  A6340: 1.18,
  A6350: 1.1,
  A6360: 1.12,
  A6370: 1.1,
};

const budgetGroupKeys = new Set(
  [...actual2025ByKeyMonth.keys()].map((key) => key.split("|").slice(0, 4).join("|")),
);
const budgetRows = [];
let budgetRowNumber = 1;
for (const groupKey of budgetGroupKeys) {
  const [accountId, departmentId, regionId, businessLine] = groupKey.split("|");
  const monthlyActuals = monthsBetween("2025-01-01", "2025-12-01").map(
    (month) => actual2025ByKeyMonth.get(`${groupKey}|${month}`) || 0,
  );
  const actualAnnual = monthlyActuals.reduce((sum, value) => sum + value, 0);
  if (actualAnnual <= 0) continue;
  const targetAnnual = actualAnnual * budgetGrowthByAccount[accountId];
  monthlyActuals.forEach((actualValue, monthIndex) => {
    const fallbackShare = 1 / 12;
    const share = actualAnnual > 0 ? actualValue / actualAnnual : fallbackShare;
    budgetRows.push({
      budget_row_id: `B${String(budgetRowNumber).padStart(6, "0")}`,
      budget_version: "FY2026_Budget_v1",
      month_start: planMonths[monthIndex],
      account_id: accountId,
      department_id: departmentId,
      region_id: regionId,
      business_line: businessLine,
      amount_usd: round(targetAnnual * share),
      budget_driver: accountById.get(accountId).statement_section === "Revenue" ? "Growth and retention plan" : "Headcount and unit-cost plan",
    });
    budgetRowNumber += 1;
  });
}

const actual2026ByGroupMonth = new Map();
for (const row of glActuals.filter((actual) => yearOf(actual.month_start) === 2026)) {
  const key = `${row.account_id}|${row.department_id}|${row.region_id}|${row.business_line}|${row.month_start}`;
  actual2026ByGroupMonth.set(key, (actual2026ByGroupMonth.get(key) || 0) + row.amount_usd);
}

const forecastFactorByAccount = {
  A4000: 0.955,
  A4010: 0.92,
  A4020: 0.94,
  A5000: 0.92,
  A5010: 0.98,
  A5020: 0.955,
  A5030: 0.97,
  A5040: 0.95,
  A5050: 0.97,
  A6100: 0.96,
  A6110: 0.95,
  A6120: 0.97,
  A6130: 1.02,
  A6200: 0.955,
  A6210: 0.98,
  A6300: 0.985,
  A6310: 1,
  A6320: 1.01,
  A6330: 1.08,
  A6340: 0.72,
  A6350: 0.94,
  A6360: 1.1,
  A6370: 0.99,
};

const forecastRows = [];
let forecastRowNumber = 1;
for (const budgetRow of budgetRows) {
  const groupKey = `${budgetRow.account_id}|${budgetRow.department_id}|${budgetRow.region_id}|${budgetRow.business_line}`;
  const actualKey = `${groupKey}|${budgetRow.month_start}`;
  const isActualized = monthSerial(budgetRow.month_start) <= monthSerial(AS_OF_MONTH);
  const amount = isActualized
    ? actual2026ByGroupMonth.get(actualKey) || 0
    : budgetRow.amount_usd * forecastFactorByAccount[budgetRow.account_id];
  forecastRows.push({
    forecast_row_id: `F${String(forecastRowNumber).padStart(6, "0")}`,
    forecast_version: "2026_Q2_Forecast",
    month_start: budgetRow.month_start,
    account_id: budgetRow.account_id,
    department_id: budgetRow.department_id,
    region_id: budgetRow.region_id,
    business_line: budgetRow.business_line,
    period_type: isActualized ? "Actualized" : "Forecast",
    amount_usd: round(amount),
    forecast_driver: isActualized ? "Closed actual" : "Q2 reforecast adjustment",
  });
  forecastRowNumber += 1;
}

const forecastActualizedKeys = new Set(
  forecastRows
    .filter((row) => row.period_type === "Actualized")
    .map(
      (row) =>
        `${row.account_id}|${row.department_id}|${row.region_id}|${row.business_line}|${row.month_start}`,
    ),
);
for (const [actualKey, amount] of actual2026ByGroupMonth) {
  if (forecastActualizedKeys.has(actualKey)) continue;
  const [accountId, departmentId, regionId, businessLine, month] = actualKey.split("|");
  forecastRows.push({
    forecast_row_id: `F${String(forecastRowNumber).padStart(6, "0")}`,
    forecast_version: "2026_Q2_Forecast",
    month_start: month,
    account_id: accountId,
    department_id: departmentId,
    region_id: regionId,
    business_line: businessLine,
    period_type: "Actualized",
    amount_usd: round(amount),
    forecast_driver: "Closed actual outside original budget grain",
  });
  forecastRowNumber += 1;
}

const subscriptionByCustomerMonth = new Map(
  subscriptionRows.map((row) => [`${row.customer_id}|${row.month_start}`, row]),
);
const invoices = [];
let invoiceNumber = 1;

function paymentOutcome(customer, issueDate, dueDate, invoiceAmount) {
  const riskDelay = customer.credit_risk_tier === "A" ? normal(-2, 8) : customer.credit_risk_tier === "B" ? normal(8, 14) : normal(24, 24);
  const plannedPaidDate = isoDateFromOffset(dueDate, Math.round(riskDelay));
  const badDebtProbability = customer.credit_risk_tier === "C" ? 0.018 : customer.credit_risk_tier === "B" ? 0.004 : 0.001;
  const isBadDebt = random() < badDebtProbability;
  const partial = !isBadDebt && random() < 0.025;
  if (isBadDebt || plannedPaidDate > AS_OF_DATE) {
    const partialAmount = partial ? invoiceAmount * weightedChoice([
      { value: 0.25, weight: 0.3 },
      { value: 0.5, weight: 0.5 },
      { value: 0.75, weight: 0.2 },
    ]) : 0;
    const overdue = dueDate < AS_OF_DATE;
    return {
      paid_date: "",
      amount_paid_usd: round(partialAmount),
      outstanding_usd: round(invoiceAmount - partialAmount),
      invoice_status: partial ? "Partially Paid" : overdue ? "Past Due" : "Open",
      days_to_pay: "",
    };
  }
  const issue = new Date(`${issueDate}T00:00:00Z`);
  const paid = new Date(`${plannedPaidDate}T00:00:00Z`);
  return {
    paid_date: plannedPaidDate,
    amount_paid_usd: round(invoiceAmount),
    outstanding_usd: 0,
    invoice_status: "Paid",
    days_to_pay: Math.round((paid - issue) / 86400000),
  };
}

for (const customer of customers) {
  for (const year of [2024, 2025, 2026]) {
    const cadenceMonths = customer.billing_cadence === "Annual" ? 12 : 3;
    for (let offset = 0; offset < 12; offset += cadenceMonths) {
      const invoiceMonthNumber = ((customer.renewal_month - 1 + offset) % 12) + 1;
      const invoiceYear = year + Math.floor((customer.renewal_month - 1 + offset) / 12);
      const month = `${invoiceYear}-${String(invoiceMonthNumber).padStart(2, "0")}-01`;
      if (monthSerial(month) > monthSerial(AS_OF_MONTH) || monthSerial(month) < monthSerial(customer.contract_start_month)) continue;
      if (customer.churn_month && monthSerial(month) >= monthSerial(customer.churn_month)) continue;
      const subscription = subscriptionByCustomerMonth.get(`${customer.customer_id}|${month}`);
      if (!subscription || subscription.ending_mrr_usd <= 0) continue;
      const issueDate = `${month.slice(0, 7)}-01`;
      const invoiceAmount = subscription.ending_mrr_usd * cadenceMonths;
      const dueDate = isoDateFromOffset(issueDate, customer.payment_terms_days);
      const outcome = paymentOutcome(customer, issueDate, dueDate, invoiceAmount);
      invoices.push({
        invoice_id: `INV${String(invoiceNumber).padStart(7, "0")}`,
        customer_id: customer.customer_id,
        project_id: "",
        invoice_type: "Subscription",
        issue_date: issueDate,
        due_date: dueDate,
        paid_date: outcome.paid_date,
        invoice_amount_usd: round(invoiceAmount),
        amount_paid_usd: outcome.amount_paid_usd,
        outstanding_usd: outcome.outstanding_usd,
        invoice_status: outcome.invoice_status,
        payment_terms_days: customer.payment_terms_days,
        days_to_pay: outcome.days_to_pay,
        as_of_date: AS_OF_DATE,
      });
      invoiceNumber += 1;
    }
  }
}

for (const row of projectFinancialRows.filter((projectMonth) => yearOf(projectMonth.month_start) >= 2024)) {
  const customer = customers.find((candidate) => candidate.customer_id === row.customer_id);
  const issueMonth = addMonths(row.month_start, 1);
  const issueDate = `${issueMonth.slice(0, 7)}-05`;
  if (issueDate > AS_OF_DATE) continue;
  const dueDate = isoDateFromOffset(issueDate, customer.payment_terms_days);
  const outcome = paymentOutcome(customer, issueDate, dueDate, row.revenue_usd);
  invoices.push({
    invoice_id: `INV${String(invoiceNumber).padStart(7, "0")}`,
    customer_id: row.customer_id,
    project_id: row.project_id,
    invoice_type: "Professional Services",
    issue_date: issueDate,
    due_date: dueDate,
    paid_date: outcome.paid_date,
    invoice_amount_usd: row.revenue_usd,
    amount_paid_usd: outcome.amount_paid_usd,
    outstanding_usd: outcome.outstanding_usd,
    invoice_status: outcome.invoice_status,
    payment_terms_days: customer.payment_terms_days,
    days_to_pay: outcome.days_to_pay,
    as_of_date: AS_OF_DATE,
  });
  invoiceNumber += 1;
}

const sources = [
  {
    source_id: "SRC-01",
    source_title: "Workday FY2025 Form 10-K",
    organization: "Workday Inc. / SEC EDGAR",
    source_period: "Fiscal year ended 2025-01-31",
    url: "https://www.sec.gov/Archives/edgar/data/1327811/000132781125000056/wday-20250131.htm",
    accessed_date: "2026-07-25",
    use_in_model: "Subscription and services revenue model; revenue recognition; retention and cost taxonomy",
    notes: "Workday reported 91% subscription revenue; 17% subscription growth; 11% services growth; 98% gross revenue retention.",
  },
  {
    source_id: "SRC-02",
    source_title: "Globant 2024 Form 20-F",
    organization: "Globant S.A. / SEC EDGAR",
    source_period: "Year ended 2024-12-31",
    url: "https://www.sec.gov/Archives/edgar/data/1557860/000162828025009110/glob-20241231.htm",
    accessed_date: "2026-07-25",
    use_in_model: "Professional services gross-margin calibration and project revenue recognition",
    notes: "Globant reported a 35.7% gross margin in 2024 and describes T&M and fixed-price recognition.",
  },
  {
    source_id: "SRC-03",
    source_title: "2025 Private B2B SaaS Growth Rate Benchmarks",
    organization: "SaaS Capital",
    source_period: "2025 survey",
    url: "https://www.saas-capital.com/research/private-saas-company-growth-rate-benchmarks/",
    accessed_date: "2026-07-25",
    use_in_model: "Growth-rate range and relationship between retention and growth",
    notes: "Survey of more than 1,000 private B2B SaaS companies; median growth reported at 25%.",
  },
  {
    source_id: "SRC-04",
    source_title: "Employer Costs for Employee Compensation - June 2025",
    organization: "U.S. Bureau of Labor Statistics",
    source_period: "June 2025",
    url: "https://www.bls.gov/news.release/archives/ecec_09122025.htm",
    accessed_date: "2026-07-25",
    use_in_model: "Direction for salary loading and benefits",
    notes: "Private-industry benefits represented 29.8% of total compensation. The model uses a narrower cash payroll load plus bonus accrual.",
  },
  {
    source_id: "SRC-05",
    source_title: "May 2024 OEWS National Industry-Specific Wage Estimates",
    organization: "U.S. Bureau of Labor Statistics",
    source_period: "May 2024",
    url: "https://www.bls.gov/oes/2024/may/oes_ind.htm",
    accessed_date: "2026-07-25",
    use_in_model: "Relative salary bands by job family and industry",
    notes: "Used as a directional anchor; all employee-level compensation is synthetic.",
  },
];

const assumptions = [
  ["ASM-01", "Company profile", "Reporting currency", "USD", "Currency", "All periods", "Model convention", "", "Single reporting currency; Canadian payroll converted into USD-equivalent salary bands."],
  ["ASM-02", "Company profile", "Reporting cutoff", AS_OF_DATE, "Date", "2026 Q2", "Model convention", "", "June 2026 is treated as a fully closed month."],
  ["ASM-03", "Revenue", "2023 subscription revenue calibration", 78000000, "USD", "FY2023", "Scaled anchor", "SRC-01", "Sets the company at mid-market scale while preserving customer-level mix."],
  ["ASM-04", "Revenue", "2023 services revenue calibration", 17000000, "USD", "FY2023", "Scaled anchor", "SRC-02", "Project revenue is scaled annually to a credible services mix."],
  ["ASM-05", "Revenue", "Subscription recognition", "Ratable monthly", "Method", "All periods", "Accounting logic", "SRC-01", "Revenue uses average opening and ending MRR for event months."],
  ["ASM-06", "Revenue", "Services recognition", "Over time", "Method", "All periods", "Accounting logic", "SRC-01;SRC-02", "T&M and fixed-price projects are recognized as work is performed."],
  ["ASM-07", "Retention", "Annual churn probability", "1.8% Enterprise; 4.0% Mid-Market; 7.0% SMB", "Rate", "All periods", "Model assumption", "SRC-01;SRC-03", "Lower than SMB benchmarks and below Workday's disclosed 98% GRR for a scaled private-company profile."],
  ["ASM-08", "Pricing", "Annual contractual uplift", 0.03, "Rate", "Renewal month", "Model assumption", "SRC-01", "Applied at renewal before expansion or contraction events."],
  ["ASM-09", "Compensation", "Annual merit increase", 0.035, "Rate", "Each January", "Model assumption", "SRC-04;SRC-05", "Applied consistently across job families."],
  ["ASM-10", "Compensation", "Benefits load", 0.15, "Rate of base salary", "Monthly", "Model assumption", "SRC-04", "Health retirement and other cash benefits; payroll taxes and bonus are separate."],
  ["ASM-11", "Compensation", "Employer payroll tax", 0.0765, "Rate of base salary", "Monthly", "Model assumption", "SRC-04", "Simplified U.S.-equivalent payroll-tax load used for all regions."],
  ["ASM-12", "Planning", "FY2026 subscription budget growth", 0.18, "Growth rate", "FY2026", "Management plan", "SRC-03", "Below the 25% private B2B SaaS survey median because the simulated company is larger and more mature."],
  ["ASM-13", "Planning", "FY2026 services budget growth", 0.14, "Growth rate", "FY2026", "Management plan", "SRC-02", "Reflects implementation capacity and expected attach rates."],
  ["ASM-14", "Planning", "Q2 forecast subscription adjustment", -0.045, "Variance vs budget", "Jul-Dec 2026", "Business event", "", "Reflects two enterprise churn events and slower expansion."],
  ["ASM-15", "Planning", "Q2 forecast services adjustment", -0.08, "Variance vs budget", "Jul-Dec 2026", "Business event", "", "Reflects lower utilization and delayed implementation starts."],
  ["ASM-16", "Data generation", "Random seed", SEED, "Integer", "All periods", "Reproducibility control", "", "Re-running the generator with the same seed reproduces the same dataset."],
  ["ASM-17", "Project accounting", "Direct labor allocation", "Billable-hours share at loaded cost per available hour", "Method", "All periods", "Synthetic timesheet logic", "SRC-02;SRC-04", "Client projects absorb billable delivery labor; internal and bench capacity remains in the services P&L rather than being forced into project margin."],
].map(([assumption_id, category, assumption_name, value, unit, period, basis_type, source_id, rationale]) => ({
  assumption_id,
  category,
  assumption_name,
  value,
  unit,
  period,
  basis_type,
  source_id,
  rationale,
}));

const businessEvents = [
  {
    event_id: "EVT-01",
    event_month: "2026-04-01",
    event_name: "Enterprise renewal loss",
    affected_area: "Subscription revenue",
    description: `Forced full churn for ${forcedChurnCustomers[0].customer_id}; creates a visible Q2 revenue variance.`,
  },
  {
    event_id: "EVT-02",
    event_month: "2026-06-01",
    event_name: "Second enterprise renewal loss",
    affected_area: "Subscription revenue",
    description: `Forced full churn for ${forcedChurnCustomers[1].customer_id}; lowers the second-half ARR base.`,
  },
  {
    event_id: "EVT-03",
    event_month: "2026-01-01",
    event_name: "Professional services utilization softness",
    affected_area: "Services revenue and margin",
    description: "Q1 utilization is reduced before recovering in May and June.",
  },
  {
    event_id: "EVT-04",
    event_month: "2026-05-01",
    event_name: "Cloud vendor commitment renegotiation",
    affected_area: "Subscription gross margin",
    description: "Hosting unit cost is reduced beginning in May 2026.",
  },
  {
    event_id: "EVT-05",
    event_month: "2026-01-01",
    event_name: "Hiring plan delay",
    affected_area: "R&D and services operating capacity",
    description: "Actual 2026 hiring is below the budgeted run rate; payroll is favorable but capacity is constrained.",
  },
];

await fs.mkdir(CSV_DIR, { recursive: true });

await writeCsv("dim_date_month.csv", dateMonths, [
  "month_start",
  "calendar_year",
  "calendar_quarter",
  "month_number",
  "month_name",
  "fiscal_year",
  "fiscal_quarter",
  "period_status",
]);
await writeCsv("dim_region.csv", regions, [
  "region_id",
  "region_name",
  "primary_hub",
  "country",
  "currency",
  "salary_index",
  "revenue_weight",
]);
await writeCsv("dim_department.csv", departments, [
  "department_id",
  "department_name",
  "function_group",
  "cost_center",
  "budget_owner",
]);
await writeCsv("dim_account.csv", accounts, [
  "account_id",
  "account_code",
  "account_name",
  "statement_section",
  "pnl_line",
  "business_line",
  "natural_balance",
  "favorable_direction",
  "sort_order",
]);
await writeCsv("dim_customer.csv", customers, [
  "customer_id",
  "customer_name",
  "industry",
  "segment",
  "region_id",
  "contract_start_month",
  "renewal_month",
  "billing_cadence",
  "payment_terms_days",
  "credit_risk_tier",
  "initial_acv_usd",
  "churn_month",
  "current_arr_usd",
]);
await writeCsv("dim_project.csv", projects, [
  "project_id",
  "customer_id",
  "region_id",
  "project_type",
  "contract_type",
  "start_month",
  "planned_end_month",
  "status",
  "contract_value_usd",
  "blended_bill_rate_usd",
  "actual_margin_pct",
]);
await writeCsv("dim_employee.csv", employees, [
  "employee_id",
  "department_id",
  "region_id",
  "job_family",
  "level",
  "employment_type",
  "start_month",
  "end_month",
  "annual_base_salary_at_hire_usd",
]);
await writeCsv("fact_subscription_mrr.csv", subscriptionRows, [
  "month_start",
  "customer_id",
  "region_id",
  "segment",
  "plan_tier",
  "opening_mrr_usd",
  "new_mrr_usd",
  "expansion_mrr_usd",
  "contraction_mrr_usd",
  "churn_mrr_usd",
  "ending_mrr_usd",
  "recognized_revenue_usd",
]);
await writeCsv("fact_headcount_monthly.csv", headcountRows, [
  "month_start",
  "employee_id",
  "department_id",
  "region_id",
  "fte",
  "monthly_base_salary_usd",
  "bonus_accrual_usd",
  "benefits_usd",
  "payroll_taxes_usd",
  "total_personnel_cost_usd",
]);
await writeCsv("fact_utilization_monthly.csv", utilizationRows, [
  "month_start",
  "employee_id",
  "region_id",
  "available_hours",
  "billable_hours",
  "internal_hours",
  "bench_hours",
  "utilization_rate",
]);
await writeCsv("fact_project_financials.csv", projectFinancialRows, [
  "month_start",
  "project_id",
  "customer_id",
  "region_id",
  "revenue_usd",
  "direct_labor_cost_usd",
  "subcontractor_cost_usd",
  "travel_cost_usd",
  "gross_profit_usd",
  "billable_hours",
]);
await writeCsv("fact_gl_actuals.csv", glActuals, [
  "gl_row_id",
  "month_start",
  "account_id",
  "department_id",
  "region_id",
  "customer_id",
  "project_id",
  "business_line",
  "amount_usd",
  "source_system",
  "entry_type",
]);
await writeCsv("fact_budget.csv", budgetRows, [
  "budget_row_id",
  "budget_version",
  "month_start",
  "account_id",
  "department_id",
  "region_id",
  "business_line",
  "amount_usd",
  "budget_driver",
]);
await writeCsv("fact_forecast.csv", forecastRows, [
  "forecast_row_id",
  "forecast_version",
  "month_start",
  "account_id",
  "department_id",
  "region_id",
  "business_line",
  "period_type",
  "amount_usd",
  "forecast_driver",
]);
await writeCsv("fact_invoice.csv", invoices, [
  "invoice_id",
  "customer_id",
  "project_id",
  "invoice_type",
  "issue_date",
  "due_date",
  "paid_date",
  "invoice_amount_usd",
  "amount_paid_usd",
  "outstanding_usd",
  "invoice_status",
  "payment_terms_days",
  "days_to_pay",
  "as_of_date",
]);
await writeCsv("model_assumptions.csv", assumptions, [
  "assumption_id",
  "category",
  "assumption_name",
  "value",
  "unit",
  "period",
  "basis_type",
  "source_id",
  "rationale",
]);
await writeCsv("model_sources.csv", sources, [
  "source_id",
  "source_title",
  "organization",
  "source_period",
  "url",
  "accessed_date",
  "use_in_model",
  "notes",
]);
await writeCsv("business_events.csv", businessEvents, [
  "event_id",
  "event_month",
  "event_name",
  "affected_area",
  "description",
]);

const manifest = {
  project: "AsterCloud FP&A Monthly Reporting",
  company: "AsterCloud Solutions Inc. (fictional)",
  generated_at: new Date().toISOString(),
  as_of_date: AS_OF_DATE,
  random_seed: SEED,
  row_counts: {
    dim_date_month: dateMonths.length,
    dim_region: regions.length,
    dim_department: departments.length,
    dim_account: accounts.length,
    dim_customer: customers.length,
    dim_project: projects.length,
    dim_employee: employees.length,
    fact_subscription_mrr: subscriptionRows.length,
    fact_headcount_monthly: headcountRows.length,
    fact_utilization_monthly: utilizationRows.length,
    fact_project_financials: projectFinancialRows.length,
    fact_gl_actuals: glActuals.length,
    fact_budget: budgetRows.length,
    fact_forecast: forecastRows.length,
    fact_invoice: invoices.length,
  },
};
await fs.writeFile(path.join(PROJECT_DIR, "data", "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8");

console.log(JSON.stringify(manifest, null, 2));
