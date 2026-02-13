CREATE OR REPLACE VIEW churn.v_7a_scenario_params AS
SELECT
  'BASE'::text AS scenario_id,
  0.25::double precision AS margin,
  1.00::double precision AS lift_multiplier,
  1.00::double precision AS shipping_cost_multiplier,
  0.10::double precision AS budget_rate

UNION ALL
SELECT
  'MARGIN_20'::text,
  0.20::double precision,
  1.00::double precision,
  1.00::double precision,
  0.10::double precision

UNION ALL
SELECT
  'MARGIN_30'::text,
  0.30::double precision,
  1.00::double precision,
  1.00::double precision,
  0.10::double precision

UNION ALL
SELECT
  'LIFT_075'::text,
  0.25::double precision,
  0.75::double precision,
  1.00::double precision,
  0.10::double precision

UNION ALL
SELECT
  'LIFT_125'::text,
  0.25::double precision,
  1.25::double precision,
  1.00::double precision,
  0.10::double precision

UNION ALL
SELECT
  'SHIP_120'::text,
  0.25::double precision,
  1.00::double precision,
  1.20::double precision,
  0.10::double precision;




CREATE OR REPLACE VIEW churn.v_7a_budget_pool_by_scenario AS
WITH base AS(
    SELECT
        b.customer_unique_id,
        b.anchor_date,
        b.risk_segment,
        b.aov_pre_anchor,
        p.p_reorder_180d,
        date_trunc('month', b.anchor_date) AS decision_month
    FROM churn.v_6_baseline_risk_segment b
    LEFT JOIN churn.v_6_p_base_by_risk_segment p 
        ON b.risk_segment = p.risk_segment
), scenario_params AS (
SELECT 
    b.*,
    s.scenario_id,
    s.margin,
    s.budget_rate
FROM base b
CROSS JOIN churn.v_7a_scenario_params s
),
gp AS(
    SELECT
    *,
    (margin * COALESCE(aov_pre_anchor,0.0) * COALESCE(p_reorder_180d,0.0)) AS expected_gp_per_anchor
FROM scenario_params
),
aggs AS(
    SELECT
        scenario_id,
        decision_month,
        SUM(expected_gp_per_anchor) AS period_expected_gp,
        COUNT(*) AS anchor_count,
        SUM(CASE WHEN p_reorder_180d IS NULL THEN 1 ELSE 0 END) AS missing_p_rows
    FROM gp
    GROUP BY scenario_id, decision_month
)
SELECT
    a.scenario_id,
    a.decision_month,
    a.period_expected_gp,
    a.anchor_count,
    a.missing_p_rows,
    s.budget_rate,
    (a.period_expected_gp * s.budget_rate) AS budget_amount
FROM aggs a
LEFT JOIN churn.v_7a_scenario_params s
    ON a.scenario_id = s.scenario_id




CREATE OR REPLACE VIEW churn.v_7a_offer_ev_by_scenario AS
WITH base AS(
    SELECT
        customer_unique_id,
        anchor_date,
        risk_segment,
        offer_type,

        p_base_default,
        lift_default,
        expected_margin_value,
        offer_cost

    FROM churn.v_6_offer_ev
),
joined AS(
    SELECT 
        b.*,
        sp.scenario_id,
        sp.margin AS scenario_margin,
        sp.lift_multiplier,
        sp.shipping_cost_multiplier,
        0.25::double precision AS base_margin
    
    FROM base b
    CROSS JOIN churn.v_7a_scenario_params sp
),
recalc AS(
    SELECT
        j.*,
        /* 1) Benefit under scenario (margin changes benefit only) */
        (j.expected_margin_value *(j.scenario_margin / j.base_margin)) AS expected_margin_value_scn,
        /* 2) Lift under scenario (lift changes delta_p only) */
        (COALESCE(j.lift_default, 0.0) * j.lift_multiplier) AS lift_scn,
        /* 3) Cost under scenario (shipping changes cost only for free_shipping) */
        CASE
            WHEN j.offer_type = 'free_shipping'
                THEN j.offer_cost * j.shipping_cost_multiplier
            ELSE j.offer_cost
        END AS offer_cost_scn

    FROM joined j
),

final AS(
    SELECT
        r.*,
        /* 4) Probabilities under scenario */
        LEAST(1.0::double precision, r.p_base_default + r.lift_scn) AS p_offer_scn,
        (LEAST(1.0::double precision, r.p_base_default + r.lift_scn) - r.p_base_default) AS delta_p_scn,
        /* 5) Profit + expected cost under scenario */
        (
      (LEAST(1.0::double precision, r.p_base_default + r.lift_scn) - r.p_base_default)
      * r.expected_margin_value_scn
        ) AS incremental_profit_scn,

        (
      LEAST(1.0::double precision, r.p_base_default + r.lift_scn)
      * r.offer_cost_scn
    ) AS expected_offer_cost_scn,
        /* 6) Net EV under scenario */
        (
      (
        (LEAST(1.0::double precision, r.p_base_default + r.lift_scn) - r.p_base_default)
        * r.expected_margin_value_scn
      )
      -
      (
        LEAST(1.0::double precision, r.p_base_default + r.lift_scn)
        * r.offer_cost_scn
      )
    ) AS net_ev_scn

    FROM recalc r

)       
SELECT
    customer_unique_id,
    anchor_date,
    risk_segment,
    offer_type,
    scenario_id,
    /* keep defaults for auditing */
    p_base_default,
    lift_default,
    expected_margin_value,
    offer_cost,
    /* scenario params */
    scenario_margin,
    lift_multiplier,
    shipping_cost_multiplier,
    /* scenario outputs */
    expected_margin_value_scn,
    lift_scn,
    p_offer_scn,
    delta_p_scn,
    incremental_profit_scn,
    offer_cost_scn,
    expected_offer_cost_scn,
    net_ev_scn

FROM final;





