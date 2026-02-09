# Step 1 — Anchor Definition & Behavioral Feature Baseline (V2)

## Objective

Define a **single, customer-level anchor date** and compute **pre-anchor behavioral features** to support churn probability estimation (p0) and downstream retention decision modeling.

This step replaces the earlier anchor logic used in V1 and corrects several structural issues discovered through systematic sanity checks.

---

## Anchor Definition (Final)

### Definition

**Anchor Date = the customer’s 2nd delivered order date (calendar date).**

This ensures:

* The customer has demonstrated **repeat behavior**
* All features are computed strictly **before** a meaningful retention decision point
* The anchor is **stable, unique, and customer-level**

### Output View

`churn.v6_anchor_customers`

### Grain

* **1 row per customer**
* Key: `customer_unique_id`
* Anchor column: `anchor_date`

### Source

* `churn.v2_order_spine`

  * `customer_unique_id`
  * `order_delivered_customer_date`

### Implementation Summary

1. Filter to delivered orders only.
2. Rank delivered orders per customer by delivery date (ascending).
3. Select the 2nd delivered order.
4. Cast timestamps to `date` for consistency with downstream feature logic.

```sql
CREATE OR REPLACE VIEW churn.v6_anchor_customers AS
WITH deliveries AS (
  SELECT
    customer_unique_id,
    order_delivered_customer_date::date AS delivered_date,
    ROW_NUMBER() OVER (
      PARTITION BY customer_unique_id
      ORDER BY order_delivered_customer_date::date ASC
    ) AS delivered_rank
  FROM churn.v2_order_spine
  WHERE order_delivered_customer_date IS NOT NULL
)
SELECT
  customer_unique_id,
  delivered_date AS anchor_date
FROM deliveries
WHERE delivered_rank = 2;
```

---

## Behavioral Features at Anchor

### Output View

`churn.v6_anchor_behavior_features`

### Grain

* **1 row per customer per anchor** (1:1 with `v6_anchor_customers`)

### Feature Window

All behavioral features are computed using **orders strictly before `anchor_date`**.

### Features Included

* `n_orders_pre_anchor`
* `first_order_date_pre_anchor`
* `last_order_date_pre_anchor`
* `recency_days`
* `tenure_days`
* `aov_pre_anchor`
* `avg_freight_pre_anchor`
* `expected_order_value_at_anchor`
* `avg_freight_bucket`

### Inputs

* `churn.v6_anchor_customers`
* `churn.v2_order_spine`
* `churn.v2_order_items`
* `churn.v5_customer_value_at_anchor`
* `churn.v3_freight_customers`

### Implementation Summary

```sql
CREATE OR REPLACE VIEW churn.v6_anchor_behavior_features AS
WITH features AS (
  SELECT
    a.customer_unique_id,
    a.anchor_date,
    COUNT(o.order_id) AS n_orders_pre_anchor,
    MIN(o.order_delivered_customer_date) AS first_order_date_pre_anchor,
    MAX(o.order_delivered_customer_date) AS last_order_date_pre_anchor,
    AVG(i.order_value) AS aov_pre_anchor,
    AVG(i.order_freight) AS avg_freight_pre_anchor
  FROM churn.v6_anchor_customers a
  LEFT JOIN churn.v2_order_spine o
    ON a.customer_unique_id = o.customer_unique_id
   AND o.order_delivered_customer_date IS NOT NULL
   AND o.order_delivered_customer_date::date < a.anchor_date
  LEFT JOIN churn.v2_order_items i
    ON o.order_id = i.order_id
  GROUP BY a.customer_unique_id, a.anchor_date
)
SELECT
  f.customer_unique_id,
  f.anchor_date,
  f.n_orders_pre_anchor,
  f.last_order_date_pre_anchor,
  f.first_order_date_pre_anchor,
  (f.anchor_date - f.last_order_date_pre_anchor) AS recency_days,
  (f.anchor_date - f.first_order_date_pre_anchor) AS tenure_days,
  f.aov_pre_anchor,
  f.avg_freight_pre_anchor,
  e.expected_order_value_at_anchor,
  fc.avg_freight_bucket
FROM features f
LEFT JOIN churn.v5_customer_value_at_anchor e
  ON f.customer_unique_id = e.customer_unique_id
 AND f.anchor_date = e.anchor_date
LEFT JOIN churn.v3_freight_customers fc
  ON f.customer_unique_id = fc.customer_unique_id
 AND f.anchor_date = fc.anchor_date;
```

---

## Sanity Checks & Why Anchors Were Recreated

During V2 development, multiple sanity checks revealed structural issues in earlier anchor logic (`v5_p0_anchor_customers`). These checks directly motivated the recreation of anchors at the **customer level**.

### 1. Grain Validation

**Expectation:**
One row per customer.

```sql
SELECT
  COUNT(*) AS n_rows,
  COUNT(DISTINCT customer_unique_id) AS n_customers
FROM churn.v6_anchor_behavior_features;
```

✔ Confirmed 1:1 mapping.

---

### 2. Minimum Delivered Orders Check

**Expectation:**
All anchored customers must have **≥ 2 delivered orders**.

```sql
SELECT COUNT(*)
FROM churn.v6_anchor_customers a
LEFT JOIN (
  SELECT customer_unique_id, COUNT(*) AS n_delivered
  FROM churn.v2_order_spine
  WHERE order_delivered_customer_date IS NOT NULL
  GROUP BY 1
) x USING (customer_unique_id)
WHERE x.n_delivered < 2;
```

✔ Returned **0 rows**, confirming anchor validity.

---

### 3. Recency Distribution Check

Used to validate time logic and detect leakage or inverted windows.

```sql
SELECT
  MIN(recency_days),
  MAX(recency_days),
  AVG(recency_days)
FROM churn.v6_anchor_behavior_features;
```

✔ Values are positive and within a realistic range.

---

### 4. Zero Pre-Anchor History Check

Some customers show `n_orders_pre_anchor = 0`.

```sql
SELECT COUNT(*)
FROM churn.v6_anchor_behavior_features
WHERE n_orders_pre_anchor = 0;
```

✔ These cases are **expected** and explained below.

---

### 5. First vs Second Delivery Equality Check

A subset of customers have **multiple delivered orders on the same calendar date**.

```sql
-- anchors equal to first delivered date
```

✔ Confirmed that:

* First and second delivered timestamps differ
* Date casting collapses them to the same `::date`

These customers are **valid repeat customers** and are intentionally retained.

---

## Known & Accepted Edge Cases

* **Same-day deliveries:**
  Customers with multiple delivered orders on the same calendar date will have:

  * `anchor_date = first_delivered_date`
  * `n_orders_pre_anchor = 0`

* **Reason for acceptance:**
  These customers still exhibit repeat behavior at the timestamp level and do not introduce leakage.

This behavior is **measured, documented, and intentional**.




