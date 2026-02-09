CREATE OR REPLACE VIEW churn.v6_customer_offer_spine AS
WITH spine AS (
  SELECT
    customer_unique_id,
    anchor_date,
    risk_band,
    aov_pre_anchor,
    avg_freight_pre_anchor
  FROM churn.v6_baseline_risk_segment
)
SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_band,
  'no_offer'::text AS offer_type,
  0.0::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_band,
  'free_shipping'::text AS offer_type,
  COALESCE(avg_freight_pre_anchor, 0.0)::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_band,
  'discount_5_percent'::text AS offer_type,
  (0.05 * COALESCE(aov_pre_anchor, 0.0))::double precision AS offer_cost
FROM spine

UNION ALL

SELECT
  customer_unique_id,
  anchor_date,
  aov_pre_anchor,
  avg_freight_pre_anchor,
  risk_band,
  'discount_10_percent'::text AS offer_type,
  (0.10 * COALESCE(aov_pre_anchor, 0.0))::double precision AS offer_cost
FROM spine;



CREATE OR REPLACE VIEW churn.v6_p_base_by_risk_band AS
SELECT
    risk_band,
    COUNT(*) AS n_anchors,
    AVG((days_to_next_order IS NOT NULL)::int) AS pct_has_any_next,
    AVG((days_to_next_order IS NOT NULL AND days_to_next_order <= 120)::int) AS p_reorder_120d,
    AVG((days_to_next_order IS NOT NULL AND days_to_next_order <= 90)::int) AS p_reorder_90d,
    AVG((days_to_next_order IS NOT NULL AND days_to_next_order <= 180)::int) AS p_reorder_180d,
    AVG((days_to_next_order IS NOT NULL AND days_to_next_order <= 365)::int) AS p_reorder_365d
FROM churn.v6_baseline_risk_segment
GROUP BY risk_band
ORDER BY risk_band;



CREATE OR REPLACE VIEW churn.v6_4_offer_spine AS
SELECT
  s.customer_unique_id,
  s.anchor_date,
  s.risk_band,
  s.offer_type,
  s.aov_pre_anchor,
  s.avg_freight_pre_anchor,
  s.offer_cost,

  p.p_reorder_90d,
  p.p_reorder_120d,
  p.p_reorder_180d,
  p.p_reorder_365d,

  p.p_reorder_180d AS p_base_default,

  0.25::double precision AS margin_rate,
  (0.25::double precision * COALESCE(s.aov_pre_anchor, 0.0)) AS expected_margin_value
FROM churn.v6_customer_offer_spine s
LEFT JOIN churn.v6_p_base_by_risk_band p
  ON s.risk_band = p.risk_band;




CREATE OR REPLACE VIEW churn.v6_lift_assumption AS
WITH base AS(
    SELECT
    risk_band,
    p_reorder_120d,
    p_reorder_90d,
    p_reorder_180d,
    p_reorder_365d
FROM churn.v6_p_base_by_risk_band

), 
lift_matrix AS(
    SELECT *
    FROM (VALUES
    -- risk_band, offer_type, lift_pct_of_p_base
    ('Low risk (≤90d)',                     'no_offer',            0.00),
    ('Low risk (≤90d)',                     'discount_5_percent',  0.05),
    ('Low risk (≤90d)',                     'free_shipping',       0.07),
    ('Low risk (≤90d)',                     'discount_10_percent', 0.10),

    ('Medium risk (91–120d)',               'no_offer',            0.00),
    ('Medium risk (91–120d)',               'discount_5_percent',  0.10),
    ('Medium risk (91–120d)',               'free_shipping',       0.15),
    ('Medium risk (91–120d)',               'discount_10_percent', 0.18),

    ('High risk (121–180d)',                'no_offer',            0.00),
    ('High risk (121–180d)',                'discount_5_percent',  0.15),
    ('High risk (121–180d)',                'free_shipping',       0.22),
    ('High risk (121–180d)',                'discount_10_percent', 0.25),

    ('Dormant / very high risk (180+d or none)', 'no_offer',            0.00),
    ('Dormant / very high risk (180+d or none)', 'discount_5_percent',  0.20),
    ('Dormant / very high risk (180+d or none)', 'free_shipping',       0.30),
    ('Dormant / very high risk (180+d or none)', 'discount_10_percent', 0.35)
  ) AS t(risk_band, offer_type, lift_pct)
)
SELECT
    m.risk_band,
    m.offer_type,
    m.lift_pct,
    b.p_reorder_90d,
    b.p_reorder_120d,
    b.p_reorder_180d,
    b.p_reorder_365d,

    (b.p_reorder_90d * m.lift_pct)::double precision AS lift_90d,
    (b.p_reorder_120d * m.lift_pct)::double precision AS lift_120d,
    (b.p_reorder_180d * m.lift_pct)::double precision AS lift_180d,
    (b.p_reorder_365d * m.lift_pct)::double precision AS lift_365d,

    (b.p_reorder_180d * m.lift_pct)::double precision AS lift_default
FROM lift_matrix m
LEFT JOIN base b
    ON m.risk_band = b.risk_band;


CREATE OR REPLACE VIEW churn.v6_offer_ev AS
SELECT
    s.customer_unique_id,
    s.anchor_date,
    s.risk_band,
    s.offer_type,

    s.p_base_default,
    l.lift_default,

    LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) AS p_offer_default,
    (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) - s.p_base_default) AS delta_p_default,

    s.expected_margin_value,

    ((LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default,0.0)) - s.p_base_default) * s.expected_margin_value) AS incremental_profit,

    s.offer_cost,

    (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) * s.offer_cost) AS expected_offer_cost,

  (((LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) - s.p_base_default)
      * s.expected_margin_value)
    - (LEAST(1.0::double precision, s.p_base_default + COALESCE(l.lift_default, 0.0)) * s.offer_cost)

  )AS net_ev_default

FROM churn.v6_4_offer_spine s
LEFT JOIN churn.v6_lift_assumption l
  ON s.risk_band = l.risk_band
  AND s.offer_type = l.offer_type;



