-- Drop tables if they already exist from previous attempts
DROP TABLE IF EXISTS adverse_reactions;
DROP TABLE IF EXISTS reported_drugs;
DROP TABLE IF EXISTS patient_demographics;

-- 1. Patient Demographics Table (DEMO)
CREATE TABLE patient_demographics (
    caseid TEXT,
    caseversion TEXT,
    i_f_code TEXT,
    mfr_dt TEXT,
    init_dt TEXT,
    fda_dt TEXT,
    rept_cod TEXT,
    mfr_num TEXT,
    mfr_sndr TEXT,
    lit_ref TEXT,
    age TEXT,
    age_cod TEXT,
    age_yr TEXT,
    sex TEXT,
    e_sub TEXT,
    wt TEXT,
    wt_cod TEXT,
    rept_dt TEXT,
    to_mfr TEXT,
    occp_cod TEXT,
    reporter_country TEXT,
    occr_country TEXT
);

-- 2. Reported Drugs Table (DRUG)
CREATE TABLE reported_drugs (
    caseid TEXT,
    id TEXT,
    drug_seq TEXT,
    role_cod TEXT,
    drugname TEXT,
    val_vbm TEXT,
    route TEXT,
    dose_amt TEXT,
    dose_unit TEXT,
    dose_form TEXT,
    dose_freq TEXT
);

-- 3. Adverse Reactions Table (REAC)
CREATE TABLE adverse_reactions (
    caseid TEXT,
    id TEXT,
    pt TEXT,
    drug_rec_act TEXT
);

SELECT 
    d.drugname,
    r.pt AS adverse_reaction,
    COUNT(DISTINCT d.caseid) AS total_cases
FROM reported_drugs d
JOIN adverse_reactions r ON d.caseid = r.caseid
WHERE d.drugname ILIKE '%CELLCEPT%'
GROUP BY d.drugname, r.pt
ORDER BY total_cases DESC
LIMIT 15;

WITH target_drug AS (
    -- Get all unique cases for the target drug
    SELECT DISTINCT caseid 
    FROM reported_drugs 
    WHERE drugname ILIKE '%CELLCEPT%'
),
target_ae_counts AS (
    -- 'A': Cases with Target Drug AND Target Adverse Event
    SELECT r.pt AS adverse_reaction, COUNT(DISTINCT r.caseid) AS a_count
    FROM adverse_reactions r
    JOIN target_drug d ON r.caseid = d.caseid
    GROUP BY r.pt
),
drug_total AS (
    -- 'A + B': Total cases involving the Target Drug
    SELECT COUNT(caseid) AS total_drug_cases FROM target_drug
),
ae_totals AS (
    -- 'A + C': Total cases for each Adverse Event across ALL drugs
    SELECT pt AS adverse_reaction, COUNT(DISTINCT caseid) AS total_ae_cases
    FROM adverse_reactions
    GROUP BY pt
),
db_total AS (
    -- 'A + B + C + D': Total unique cases in the entire database
    SELECT COUNT(DISTINCT caseid) AS total_db_cases FROM adverse_reactions
)
SELECT 
    t.adverse_reaction,
    t.a_count AS cases_with_drug,
    dt.total_drug_cases,
    ae.total_ae_cases AS cases_across_all_drugs,
    -- Calculate PRR: (A / (A+B)) / (C / (C+D))
    ROUND(
        (t.a_count::NUMERIC / NULLIF(dt.total_drug_cases, 0)) 
        / 
        NULLIF(((ae.total_ae_cases - t.a_count)::NUMERIC / NULLIF((db.total_db_cases - dt.total_drug_cases), 0)), 0), 
    2) AS prr_score
FROM target_ae_counts t
JOIN ae_totals ae ON t.adverse_reaction = ae.adverse_reaction
CROSS JOIN drug_total dt
CROSS JOIN db_total db
WHERE t.a_count >= 3  -- Industry standard: require at least 3 cases to reduce noise
ORDER BY prr_score DESC
LIMIT 20;

SELECT * FROM reported_drugs LIMIT 10;
UPDATE reported_drugs
SET drugname = REGEXP_REPLACE(TRIM(drugname), '^[.,;:?\[\]\^`\*\-_]+|[.,;:?\[\]\^`\*\-_]+$', '', 'g');

UPDATE reported_drugs
SET drugname = UPPER(REGEXP_REPLACE(TRIM(drugname), '^[.,;:?\[\]\^`\*\-_]+|[.,;:?\[\]\^`\*\-_]+$', '', 'g'))
WHERE drugname IS NOT NULL;

UPDATE reported_drugs
SET drugname = UPPER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(drugname), '^[|!]+|[|!]+$', '', 'g'), '\?', '-', 'g'))
WHERE drugname IS NOT NULL;

UPDATE reported_drugs
SET drugname = UPPER(REGEXP_REPLACE(TRIM(drugname), '^\(|\)+$', '', 'g'))
WHERE drugname IS NOT NULL;

UPDATE reported_drugs
SET drugname = UPPER(REGEXP_REPLACE(TRIM(drugname), '^%+|%+$', '', 'g'))
WHERE drugname IS NOT NULL;

UPDATE reported_drugs
SET drugname = UPPER(REGEXP_REPLACE(REGEXP_REPLACE(TRIM(drugname), '^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$', '', 'g'), '\^', ' ', 'g'))
WHERE drugname IS NOT NULL;

WITH drug_event_counts AS (
    SELECT 
        d.drugname,
        a.pt AS adverse_reaction,
        COUNT(DISTINCT d.caseid) AS a_count
    FROM reported_drugs d
    JOIN adverse_reactions a ON d.caseid = a.caseid
    WHERE d.drugname IS NOT NULL AND a.pt IS NOT NULL
    GROUP BY d.drugname, a.pt
),
drug_totals AS (
    SELECT 
        d.drugname,
        COUNT(DISTINCT d.caseid) AS total_drug_reports
    FROM reported_drugs d
    WHERE d.drugname IS NOT NULL
    GROUP BY d.drugname
),
event_totals AS (
    SELECT 
        a.pt AS adverse_reaction,
        COUNT(DISTINCT a.caseid) AS total_event_reports
    FROM adverse_reactions a
    WHERE a.pt IS NOT NULL
    GROUP BY a.pt
),
grand_total AS (
    SELECT COUNT(DISTINCT caseid) AS total_cases FROM reported_drugs
)
SELECT 
    de.drugname,
    de.adverse_reaction,
    de.a_count AS cases_with_drug_and_event,
    dt.total_drug_reports,
    et.total_event_reports,
    gt.total_cases,
    ROUND(
        (de.a_count::numeric / NULLIF(dt.total_drug_reports, 0)) / 
        NULLIF(((et.total_event_reports - de.a_count)::numeric / NULLIF(gt.total_cases - dt.total_drug_reports, 0)), 0), 2
    ) AS prr
FROM drug_event_counts de
JOIN drug_totals dt ON de.drugname = dt.drugname
JOIN event_totals et ON de.adverse_reaction = et.adverse_reaction
CROSS JOIN grand_total gt
WHERE dt.total_drug_reports >= 5
  AND de.a_count >= 3
  AND (gt.total_cases - dt.total_drug_reports) > 0
ORDER BY prr DESC
