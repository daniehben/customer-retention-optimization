SELECT
    AVG(recency_days) AS avg_recency,
    MIN(recency_days) AS min_recency,
    MAX(recency_days) AS max_recency,
    AVG(tenure_days) AS avg_tenure,
    MIN(tenure_days) AS min_tenure,
    MAX(tenure_days) AS max_tenure,
    AVG(aov_pre_anchor) AS avg_aov,
    MIN(aov_pre_anchor) AS min_aov,
    MAX(aov_pre_anchor) AS max_aov
FROM churn.v6_anchor_behavior_features



SELECT
  PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY recency_days) AS r_p05,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY recency_days) AS r_p25,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY recency_days) AS r_p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY recency_days) AS r_p75,
  PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY recency_days) AS r_p90,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY recency_days) AS r_p95
FROM churn.v6_anchor_behavior_features;


SELECT
  PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY tenure_days) AS t_p05,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY tenure_days) AS t_p25,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY tenure_days) AS t_p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY tenure_days) AS t_p75,
  PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY tenure_days) AS t_p90,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY tenure_days) AS t_p95
FROM churn.v6_anchor_behavior_features;


SELECT
  PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p05,
  PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p25,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p50,
  PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p75,
  PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p90,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY aov_pre_anchor) AS a_p95
FROM churn.v6_anchor_behavior_features;


SELECT
  COUNT(*) AS n,
  SUM((tenure_days = recency_days)::int) AS n_equal,
  SUM((tenure_days IS NULL OR recency_days IS NULL)::int) AS n_any_null,
  SUM((tenure_days <> recency_days)::int) AS n_not_equal
FROM churn.v6_anchor_behavior_features;


SELECT
  COUNT(*) AS n,
  SUM((first_order_date_pre_anchor = last_order_date_pre_anchor)::int) AS n_first_eq_last,
  ROUND(AVG((first_order_date_pre_anchor = last_order_date_pre_anchor)::int)::numeric, 4) AS pct_first_eq_last
FROM churn.v6_anchor_behavior_features
WHERE first_order_date_pre_anchor IS NOT NULL
  AND last_order_date_pre_anchor IS NOT NULL;


SELECT
  n_orders_pre_anchor,
  COUNT(*) AS n
FROM churn.v6_anchor_behavior_features
GROUP BY 1
ORDER BY 1;
