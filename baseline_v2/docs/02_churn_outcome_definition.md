
# Step 2 — Churn Outcome Definition (60-Day Horizon)

## Objective

After defining a consistent anchor point for repeat customers (Step 1), the next step is to **define a churn outcome** relative to that anchor.

The goal of this step is to create a **clear, binary churn label** that answers the business question:

> *Did this customer place another delivered order within a reasonable time window after becoming a repeat customer?*

This churn label will later be used to:

* Estimate baseline churn risk (`p0`)
* Evaluate intervention lift
* Compute expected value of retention actions

---

## Churn Definition

A customer is considered **churned at 60 days** if:

> **They do not place any delivered order within 60 days after their anchor date.**

Formally:

* **has_post_anchor_order_60d = 1**
  → At least one delivered order occurs within 60 days after the anchor date

* **churn_60d = 1**
  → No delivered orders occur within 60 days after the anchor date

This definition produces a **binary, customer-level churn outcome** aligned with early-warning retention decisions.

---

## Why a 60-Day Window?

The 60-day horizon was chosen deliberately for decision relevance:

* It represents an **early churn signal**, allowing timely intervention
* Most spontaneous repeat purchases occur well before this point
* Customers inactive beyond 60 days have a sharply lower probability of returning without intervention

Exploratory analysis showed that while some customers do return later, these returns are sparse and distributed across a long tail. Extending the churn window would blur the distinction between **high-risk** and **low-risk** customers and delay action.

For this reason, **60 days is used as the primary churn definition**, with longer horizons reserved for optional sensitivity analysis.

---

## Implementation Logic

1. For each customer anchor date:

   * Identify all delivered orders **after** the anchor date
2. Compute the number of days between the anchor date and the **next delivered order**
3. Keep only the **earliest post-anchor delivered order**
4. Assign churn labels based on whether this order occurs within 60 days

Customers with **no post-anchor delivered orders** are treated as churned.

---

## Output View

The churn outcomes are materialized in the following view:

```
churn.v6_churn_outcomes
```

### Key Fields

| Column                    | Description                                        |
| ------------------------- | -------------------------------------------------- |
| customer_unique_id        | Unique customer identifier                         |
| anchor_date               | Repeat-purchase anchor date                        |
| days_to_next_order        | Days until the next delivered order (NULL if none) |
| has_post_anchor_order_60d | 1 if next order occurs ≤ 60 days                   |
| churn_60d                 | 1 if no order occurs within 60 days                |

---

## Sanity Checks Performed

Several validation checks were applied to ensure correctness:

* Each customer appears **once per anchor**
* No negative `days_to_next_order` values
* Customers labeled as churned have either:

  * No post-anchor orders, or
  * A next order occurring strictly after 60 days
* Aggregate churn rate aligns with expectations for repeat customers

These checks confirmed that the churn label is **internally consistent and suitable for downstream modeling**.

---

## Role in the Overall Pipeline

This step converts behavioral timelines into a **decision-ready outcome variable**.

With:

* Step 1 → *When do we start observing the customer?*
* Step 2 → *Did the customer churn after that point?*

the project can now move into **risk estimation and intervention modeling**.

The next step is to estimate **baseline churn probability (`p0`)** using customer behavior observed prior to the anchor date.

---


