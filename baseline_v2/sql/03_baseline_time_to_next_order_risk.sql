
-- 03_baseline_risk_segments_time_to_event.sql
-- Step 3: Baseline risk segmentation using time-to-next-order
-- Why: 60-day churn is too flat in this dataset (low repeat frequency),
-- so we segment customers by observed time-to-return (or dormancy).


-- SANITY CHECKS: Churn is 95% across all, is it the right target definition?

SELECT
  COUNT(*) AS n_anchors,
  AVG((days_to_next_order IS NOT NULL)::int) AS pct_has_any_next,
  AVG((days_to_next_order <= 60)::int)  AS pct_next_60,
  AVG((days_to_next_order <= 90)::int)  AS pct_next_90,
  AVG((days_to_next_order <= 120)::int) AS pct_next_120,
  AVG((days_to_next_order <= 180)::int) AS pct_next_180,
  AVG((days_to_next_order <= 365)::int) AS pct_next_365
FROM churn.v6_churn_outcomes;


SELECT
  MIN(days_to_next_order) AS min_days,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY days_to_next_order) AS p25,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days_to_next_order) AS p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY days_to_next_order) AS p75,
  MAX(days_to_next_order) AS max_days
FROM churn.v6_churn_outcomes
WHERE days_to_next_order IS NOT NULL;



-- TIME-to-EVENT ANALYSIS (NEW TARGET DEFINITION)

CREATE OR REPLACE VIEW churn.v_6_baseline_risk_segment AS
WITH spine AS(
    SELECT
    a.customer_unique_id,
    a.anchor_date,
    a.recency_days,
    a.tenure_days,
    a.aov_pre_anchor,
    o.days_to_next_order,
    a.avg_freight_pre_anchor
FROM churn.v6_anchor_behavior_features a
LEFT JOIN churn.v6_churn_outcomes o
    ON a.customer_unique_id = o.customer_unique_id
    AND a.anchor_date = o.anchor_date
), labeled AS(
    SELECT
        *,
        CASE WHEN days_to_next_order IS NOT NULL AND days_to_next_order <= 90 THEN 1 ELSE 0 END AS next_90d,
        CASE WHEN days_to_next_order IS NOT NULL AND days_to_next_order <= 120 THEN 1 ELSE 0 END AS next_120d,
        CASE WHEN days_to_next_order IS NOT NULL AND days_to_next_order <= 180 THEN 1 ELSE 0 END AS next_180d,
        -- Recency buckets (descriptive)
        CASE
            WHEN recency_days = 1 THEN '1 day'
            WHEN recency_days BETWEEN 2 AND 7 THEN '2–7 days'
            WHEN recency_days BETWEEN 8 AND 30 THEN '8–30 days'
            WHEN recency_days BETWEEN 31 AND 60 THEN '31–60 days'
            WHEN recency_days BETWEEN 61 AND 90 THEN '61–90 days'
            WHEN recency_days BETWEEN 91 AND 180 THEN '91–180 days'
            WHEN recency_days BETWEEN 181 AND 365 THEN '181–365 days'
            ELSE '366+ days'
        END AS recency_bucket,
        -- Tenure buckets (descriptive)
        CASE
        WHEN tenure_days = 1 THEN '1 day'
        WHEN tenure_days BETWEEN 2 AND 7 THEN '2-7 days'
        WHEN tenure_days BETWEEN 8 AND 15 THEN '8-15 days'
        WHEN tenure_days BETWEEN 16 AND 30 THEN '16-30 days'
        WHEN tenure_days BETWEEN 30 AND 90 THEN '31-90 days'
        WHEN tenure_days BETWEEN 91 AND 180 THEN '91-180 days'
        ELSE '180+ days'
    END AS tenure_bucket,
        -- Value buckets (descriptive)
        CASE
            WHEN aov_pre_anchor < 50 THEN 'Low'
            WHEN aov_pre_anchor BETWEEN 50 AND 100 THEN 'Medium'
            ELSE 'High'
        END AS aov_bucket
    FROM spine
), banded AS (
  SELECT
    *, 
    -- Update risk bands based on features to fix future leakage problem
    CASE
      WHEN recency_days <= 9   THEN 'Active (≤p25)'
      WHEN recency_days <= 42  THEN 'Warm (p25–p50)'
      WHEN recency_days <= 144 THEN 'Cold (p50–p75)'
      ELSE 'Dormant (≥p75)'
    END AS recency_band,
    CASE
      WHEN aov_pre_anchor IS NULL THEN 'AOV_Unknown'
      WHEN aov_pre_anchor < 45    THEN 'AOV_Low'
      WHEN aov_pre_anchor < 85    THEN 'AOV_Mid'
      WHEN aov_pre_anchor < 150   THEN 'AOV_High'
      ELSE 'AOV_VeryHigh'
    END AS aov_tier
  FROM labeled
)
SELECT *,
(recency_band || ' | ' || aov_tier) AS risk_segment
FROM banded;



-- ANALYSIS

SELECT risk_segment, COUNT(*) AS n
FROM churn.v_6_baseline_risk_segment
GROUP BY 1
ORDER BY n DESC;

SELECT
  recency_band,
  MIN(recency_days) AS min_r,
  MAX(recency_days) AS max_r,
  COUNT(*) AS n
FROM churn.v_6_baseline_risk_segment
GROUP BY 1
ORDER BY 1;

SELECT
  aov_tier,
  MIN(aov_pre_anchor) AS min_aov,
  MAX(aov_pre_anchor) AS max_aov,
  COUNT(*) AS n
FROM churn.v_6_baseline_risk_segment
GROUP BY 1
ORDER BY 1;


SELECT risk_segment, COUNT(*) AS n
FROM churn.v_6_baseline_risk_segment
GROUP BY 1
ORDER BY n ASC;

SELECT recency_band, aov_tier, COUNT(*) n
FROM churn.v_6_baseline_risk_segment
GROUP BY 1,2
ORDER BY 1,2;



-- 1. How many have any next order at all?
SELECT
  COUNT(*) AS n_anchors,
  AVG((days_to_next_order IS NOT NULL)::int) AS pct_has_any_next
FROM churn.v6_baseline_risk_segments;

-- 2.Distribution of days_to_next_order for those who DO reorder
SELECT
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY days_to_next_order) AS p25,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY days_to_next_order) AS p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY days_to_next_order) AS p75
FROM churn.v6_baseline_risk_segments
WHERE days_to_next_order IS NOT NULL;

-- 3. Inside Dormant, what’s the “best subsegment”? (AOV bucket)
SELECT
  aov_bucket,
  COUNT(*) AS n
FROM churn.v6_baseline_risk_segments
WHERE risk_band LIKE 'Dormant%'
GROUP BY 1
ORDER BY n DESC;

