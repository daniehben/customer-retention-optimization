-- TESTS

-- Grain Check

SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT (customer_unique_id, anchor_date)) AS distinct_anchors
FROM churn.v6_phase5_b_eligibility;

-- How many eligible?

SELECT eligibility_status, COUNT(*)
FROM churn.v6_phase5_b_eligibility
GROUP BY 1;

-- WHY are they ineligible?

SELECT ineligibility_reason, COUNT(*)
FROM churn.v6_phase5_b_eligibility
WHERE eligibility_status = 'ineligible'
GROUP BY 1
ORDER BY 2 DESC;

-- Sanity: eligible should be only High/Dormant

SELECT risk_band, eligibility_status, COUNT(*)
FROM churn.v6_phase5_b_eligibility
GROUP BY 1,2
ORDER BY 1,2;

SELECT risk_band, COUNT(*) AS n
FROM churn.v6_baseline_risk_segment
GROUP BY 1
ORDER BY 2 DESC;



-- Percent eligible within eligible risk bands only

SELECT
  risk_band,
  COUNT(*) AS n_anchors,
  SUM((eligibility_status = 'eligible_for_review')::int) AS n_eligible,
  AVG((eligibility_status = 'eligible_for_review')::int) AS pct_eligible
FROM churn.v6_phase5_b_eligibility
GROUP BY 1
ORDER BY 1;


-- 2) AOV distribution for Dormant (to see if p25 is too low)

SELECT
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY aov_pre_anchor) AS p25,
  PERCENTILE_CONT(0.35) WITHIN GROUP (ORDER BY aov_pre_anchor) AS p35,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY aov_pre_anchor) AS p50
FROM churn.v6_phase5_b_eligibility
WHERE risk_band = 'Dormant / very high risk (180+d or none)'
AND aov_pre_anchor IS NOT NULL;


-- 3) How many eligible have very low AOV anyway?
SELECT
  COUNT(*) AS eligible,
  SUM((aov_pre_anchor < 10)::int) AS eligible_aov_lt_10
FROM churn.v6_phase5_b_eligibility
WHERE eligibility_status = 'eligible_for_review'
  AND aov_pre_anchor IS NOT NULL;

-- AFTER CHANGING FROM 0.25 -> 0.35

SELECT eligibility_status, COUNT(*)
FROM churn.v6_phase5_b_eligibility
GROUP BY 1;


SELECT ineligibility_reason, COUNT(*)
FROM churn.v6_phase5_b_eligibility
WHERE eligibility_status = 'ineligible'
GROUP BY 1
ORDER BY 2 DESC;

-- Sanity: eligible should be only High/Dormant

SELECT risk_band, eligibility_status, COUNT(*)
FROM churn.v6_phase5_b_eligibility
GROUP BY 1,2
ORDER BY 1,2;



SELECT
  risk_band,
  COUNT(*) AS n,
  SUM((eligibility_status='eligible_for_review')::int) AS n_eligible,
  AVG((eligibility_status='eligible_for_review')::int) AS pct_eligible
FROM churn.v6_phase5_b_eligibility
WHERE risk_band IN ('High risk (121–180d)','Dormant / very high risk (180+d or none)')
GROUP BY 1;


SELECT ineligibility_reason, COUNT(*)
FROM churn.v6_phase5_b_eligibility
WHERE eligibility_status = 'ineligible'
GROUP BY 1
ORDER BY 2 DESC;
