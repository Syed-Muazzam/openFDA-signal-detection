# openFDA-signal-detection
End-to-end pharmacovigilance pipeline and Power BI dashboard analyzing openFDA FAERS data. Features automated PostgreSQL ETL, string cleaning, and Proportional Reporting Ratio (PRR) statistical signal detection.

# FAERS Pharmacovigilance Signal Detection

A data engineering and visualization pipeline that extracts drug safety signals from the openFDA FAERS (FDA Adverse Event Reporting System) database. It uses PostgreSQL to calculate Proportional Reporting Ratios (PRR) and Power BI for interactive dashboarding.

![Dashboard Preview](dashboard/faers_surveillance.pdf)

## Tech Stack
* **Database:** PostgreSQL
* **Visualization:** Power BI
* **Data Source:** openFDA FAERS Quarterly ASCII Data

## Methodology: Proportional Reporting Ratio (PRR)
The PRR identifies statistically significant disproportionality in adverse drug reactions.

* **Formula:** `PRR = (A / (A + B)) / (C / (C + D))`
  * `A`: Target drug + Target adverse event
  * `B`: Target drug + All other events
  * `C`: All other drugs + Target adverse event
  * `D`: All other drugs + All other events

**Signal Thresholds Used:**
* PRR $\ge$ 2.0
* Target cases (`A`) $\ge$ 3
* Total drug reports (`A + B`) $\ge$ 5

## Data Pipeline
1. **Schema & Ingestion:** Normalized FAERS data loaded into three core tables: `patient_demographics`, `reported_drugs`, and `adverse_reactions`.
2. **Data Cleaning:** Sequential PostgreSQL `REGEXP_REPLACE` statements to strip trailing punctuation, standardize case, and trim whitespace from raw pharmaceutical strings.
3. **Signal Calculation:** Modular CTEs compute denominators utilizing safe division (`NULLIF`) to prevent zero-division errors during PRR generation.
4. **Visualization:** Power BI dashboard surfaces KPI counts, top reported events by PT, and a detailed matrix of high-priority PRR signals.

## Repository Structure
* `sql/faers_pipeline.sql` - PostgreSQL DDL, regex cleaning steps, and the PRR CTE query.
* `dashboard/faers_surveillance.pbix` - Power BI dashboard file.
* `assets/dashboard_hero.png` - Dashboard UI screenshot.

## Usage
1. Execute `sql/faers_pipeline.sql` to initialize tables and views.
2. Import FAERS data into PostgreSQL.
3. Run the regex cleaning updates.
4. Point the Power BI `.pbix` file to the PostgreSQL instance to visualize the PRR query results.

