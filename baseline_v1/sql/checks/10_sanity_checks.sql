-- FILE 10_sanity_checks.sql SANITY CHECKS

-- ===============================================
-- One row per customer+anchor in the allocator
-- Expected: 0
-- ==============================================

SELECT
    customer_unique_id, anchor_date, COUNT(*) AS row_count
    FROM budget_alloc
    GROUP BY 1,2
    HAVING COUNT(*) > 1;

-- ============================================
-- Selected rows never exceed budget
-- Expected: max_selected_cost <= total_budget
-- =============================================

SELECT 
    MAX(cumulative_cost) AS max_selected_cost
FROM budget_alloc
WHERE is_selected = TRUE;


-- ============================================
-- Total selected cost <= budget (alternative)
-- <= budget
-- =============================================

SELECT
    SUM(offer_cost) AS total_selected_cost
FROM budget_alloc
WHERE is_selected = TRUE;


-- ============================================
-- No negative/zero EV is selected
-- 0
-- =============================================

SELECT
    COUNT(*) AS bad_selected_count
FROM budget_alloc
WHERE is_selected = TRUE
  AND expected_value <= 0;


-- ============================================
-- No NULLs in key decision fields
-- 0
-- =============================================

SELECT
  SUM(CASE WHEN expected_value IS NULL THEN 1 ELSE 0 END) AS null_ev,
  SUM(CASE WHEN ev_per_cost IS NULL THEN 1 ELSE 0 END) AS null_eff,
  SUM(CASE WHEN cumulative_cost IS NULL THEN 1 ELSE 0 END) AS null_cum
FROM budget_alloc;

-- ====================================================
-- Monotonicity: cumulative_cost should never decrease
-- 0
-- ====================================================

WITH t AS(
    SELECT 
        cumulative_cost,
        LAG(cumulative_cost) OVER (
            ORDER BY cumulative_cost) AS prev_cost
    FROM budget_alloc
)
SELECT
    COUNT(*) AS decreasing_count
FROM t
WHERE prev_cost IS NOT NULL
  AND cumulative_cost < prev_cost;


-- ============================================================================
-- Boundary check: first unselected row should be the one that breaks budget
-- last selected cumulative cost ≤ budget
-- first unselected cumulative cost > budget
-- ============================================================================

WITH ordered AS(
    SELECT
        *,
        ROW_NUMBER() OVER(
            ORDER BY ev_per_cost DESC NULLS LAST,
            expected_value DESC) AS rnk
    FROM budget_alloc
),
first_unselected AS(
    SELECT *
    FROM ordered
    WHERE is_selected = FALSE
    ORDER BY rnk
    LIMIT 1
),
last_selected AS(
    SELECT *
    FROM ordered
    WHERE is_selected = TRUE
    ORDER BY rnk DESC
    LIMIT 1
)
SELECT
    (SELECT cumulative_cost FROM last_selected) AS last_selected_cost,
    (SELECT cumulative_cost FROM first_unselected) AS first_unselected_cost;