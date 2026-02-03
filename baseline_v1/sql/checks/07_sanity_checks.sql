-- SANITY CHECKS FOR FILE 7 -  churn.v5_lift_assumptions

-- ======
-- 1️⃣ Row count = (# buckets × # offers)

-- Why:
-- This table is not customer-level. It must only contain every (bucket × offer) combination exactly once.

-- What to expect:
-- If you have 7 buckets and 4 offers → 28 rows
-- ======

SELECT COUNT(*) AS n_rows
FROM churn.v5_lift_assumptions;


-- ======
-- 2️⃣ One row per (bucket, offer)

-- Why:
-- Ensures there are no duplicates that would silently multiply rows later.

-- Expected:
-- 0 rows returned
-- ======

SELECT
    avg_freight_bucket,
    offer_type,
    COUNT(*) AS n
FROM churn.v5_lift_assumptions
GROUP BY avg_freight_bucket, offer_type
HAVING COUNT(*) > 1;


-- ======
-- 3️⃣ Lift value ranges by offer

-- Why:
-- Catches logic mistakes in CASE expressions (especially nested CASEs).

-- Expected:
-- no_offer → min = max = 0
-- discount_5_percent → min = max = 0.03
-- discount_10_percent → min = max = 0.05
-- free_shipping → min ≈ 0.01, max ≈ 0.08
-- ======

SELECT
    offer_type,
    MIN(assumed_lift) AS min_lift,
    MAX(assumed_lift) AS max_lift,
    COUNT(*) AS n_rows
FROM churn.v5_lift_assumptions
GROUP BY offer_type
ORDER BY offer_type;

-- ======
-- 4️⃣ Free shipping has exactly one row per bucket

-- Why:
-- Free shipping is the only offer whose lift varies by bucket — this confirms that logic is clean.

-- Expected:
-- each bucket appears once
-- ======

SELECT
    avg_freight_bucket,
    COUNT(*) AS n_rows
FROM churn.v5_lift_assumptions
WHERE offer_type = 'free_shipping'
GROUP BY avg_freight_bucket
ORDER BY avg_freight_bucket;


-- SANITY CHECKS FOR churn.v5_customer_p1_by_offer

-- ======
-- 5️⃣ Row count parity with offer_costs

-- Why:
-- Every customer-offer row must survive the joins.

-- Expected:
-- p1_rows = offer_rows
-- If smaller → join coverage issue
-- If larger → duplication (very bad)
-- ======

SELECT
    (SELECT COUNT(*) FROM churn.v5_customer_p1_by_offer) AS p1_rows,
    (SELECT COUNT(*) FROM churn.v5_offer_costs) AS offer_rows;


-- ======
-- 6️⃣ NULL coverage

-- Why:
-- Any NULL here will silently break EV later.

-- Expected:
-- all three = 0
-- If null_lift > 0 → bucket/offer mismatch
-- If null_p0 > 0 → anchor baseline issue
-- ======

SELECT
    SUM(CASE WHEN p0_60d_final IS NULL THEN 1 ELSE 0 END) AS null_p0,
    SUM(CASE WHEN assumed_lift IS NULL THEN 1 ELSE 0 END) AS null_lift,
    SUM(CASE WHEN p1_60d IS NULL THEN 1 ELSE 0 END) AS null_p1
FROM churn.v5_customer_p1_by_offer;


-- ======
-- 7️⃣ Probability bounds check

-- Why:
-- Confirms clamping actually works.

-- Expected:
-- min_p1 >= 0
-- max_p1 <= 1
-- ======


SELECT
    MIN(p1_60d) AS min_p1,
    MAX(p1_60d) AS max_p1
FROM churn.v5_customer_p1_by_offer;


-- ======
-- 8️⃣ Delta sanity

-- Why:
-- Lift should never reduce probability in your current assumptions.

-- Expected:
-- min_delta >= 0
-- max_delta <= max assumed lift
-- If negative → logic error
-- If absurdly large → p0 not bounded correctly
-- ======


SELECT
    MIN(delta_p) AS min_delta,
    MAX(delta_p) AS max_delta
FROM churn.v5_customer_p1_by_offer;


-- ======
-- 9️⃣ No-offer consistency check

-- Why:
-- “No offer” should not change behavior.

-- Expected:
-- n_bad_rows = 0
-- If not → lift logic error
-- ======

SELECT
    COUNT(*) AS n_bad_rows
FROM churn.v5_customer_p1_by_offer
WHERE offer_type = 'no_offer'
  AND ABS(delta_p) > 1e-6;
