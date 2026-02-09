CREATE OR REPLACE VIEW churn.v6_phase5_b_eligibility AS
WITH base AS(
  SELECT
    customer_unique_id,
    anchor_date,
    risk_band,
    aov_pre_anchor,
    avg_freight_pre_anchor
  FROM churn.v6_baseline_risk_segment
),
aov_thresholds AS(
  SELECT
    risk_band,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY aov_pre_anchor) AS aov_25th_percentile,
    PERCENTILE_CONT(0.35)
      WITHIN GROUP (ORDER BY aov_pre_anchor) AS aov_threshold

  FROM base
  WHERE 
    risk_band IN ('High risk (121–180d)','Dormant / very high risk (180+d or none)')
    AND aov_pre_anchor IS NOT NULL
  GROUP BY risk_band
),
gates AS(
  SELECT
  b.customer_unique_id,
  b.anchor_date,
  b.risk_band,
  b.aov_pre_anchor,
  b.avg_freight_pre_anchor,
  /* Gate 1: Risk band eligibility */
  CASE 
    WHEN b.risk_band IN (
      'High risk (121–180d)',
      'Dormant / very high risk (180+d or none)'
      ) THEN 1
    ELSE 0
  END AS gate_risk_pass,
  /* Helpful flags for auditability */
    CASE WHEN b.aov_pre_anchor IS NULL THEN 1 ELSE 0 END AS is_missing_aov,
    CASE
      WHEN b.aov_pre_anchor IS NOT NULL
       AND t.aov_threshold IS NOT NULL
       AND b.aov_pre_anchor < t.aov_threshold
      THEN 1 ELSE 0
    END AS is_below_value_threshold,

    CASE WHEN b.avg_freight_pre_anchor IS NULL THEN 1 ELSE 0 END AS is_missing_freight,
    CASE
      WHEN b.avg_freight_pre_anchor IS NOT NULL
       AND b.aov_pre_anchor IS NOT NULL
       AND b.avg_freight_pre_anchor > 0.5 * b.aov_pre_anchor
      THEN 1 ELSE 0
    END AS is_high_freight_cost,
  /* Gate 2: Value eligibility based on AOV */
  CASE 
    WHEN b.aov_pre_anchor IS NULL THEN 0
    WHEN t.aov_threshold IS NULL THEN 0
    WHEN b.aov_pre_anchor >= t.aov_threshold THEN 1
    ELSE 0
  END AS gate_value_pass,
  /* Gate 3: Structural exclusion (freight burden) */
  CASE
    WHEN b.avg_freight_pre_anchor IS NULL THEN 1
    WHEN b.aov_pre_anchor IS NULL THEN 1
    WHEN b.avg_freight_pre_anchor > 0.5 * b.aov_pre_anchor THEN 1
    ELSE 0
  END AS gate_structural_exclusion

  FROM base b
LEFT JOIN aov_thresholds t
  ON b.risk_band = t.risk_band
)
SELECT
  customer_unique_id,
  anchor_date,
  risk_band,
  aov_pre_anchor,
  avg_freight_pre_anchor,

  gate_risk_pass,
  gate_value_pass,
  gate_structural_exclusion,
  /* Keep the audit flags in the final view (helpful for analysis + documentation) */
  is_missing_aov,
  is_below_value_threshold,
  is_missing_freight,
  is_high_freight_cost,
  /* Final eligibility decision */
  CASE
    WHEN gate_risk_pass = 1
      AND gate_value_pass = 1
      AND gate_structural_exclusion = 0 
    THEN 1
    ELSE 0
  END AS final_pass,
  /* Eligibility label */
  CASE 
    WHEN gate_risk_pass = 1
      AND gate_value_pass = 1
      AND gate_structural_exclusion = 0 
    THEN 'eligible_for_review'
    ELSE 'ineligible'
  END AS eligibility_status,
  /* Reason for ineligibility */
  CASE
    WHEN gate_risk_pass = 0 THEN 'risk_band_not_eligible'
    WHEN is_missing_aov = 1 THEN 'missing_aov'
    WHEN is_below_value_threshold = 1 THEN 'below_value_threshold'
    WHEN is_missing_freight = 1 THEN 'missing_freight'
    WHEN is_high_freight_cost = 1 THEN 'high_freight_cost'
    ELSE NULL
  END AS ineligibility_reason

FROM gates;



