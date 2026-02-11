# **Step 3 – Baseline Outcome Segmentation (Time-to-Event) + Why It Cannot Drive Decisions**

## Original approach

The initial plan for baseline segmentation relied on a fixed churn definition (no reorder within 60 days after an anchor date). This approach assumed that churn would vary meaningfully across customers and could be explained by behavioral features such as recency, tenure, and order value.

## Issue discovered

Sanity checks revealed that this assumption did not hold for the dataset:

* Only ~7.5% of anchor events had any subsequent order
* More than 95% of customers were labeled as churned at 60 days
* Churn rates were nearly flat across all behavioral segments

This indicated that the dataset exhibits **low repeat frequency**, making short-window churn an uninformative target. A binary churn label collapsed most customers into the same outcome, eliminating segmentation power.

## Pivot to time-to-event framing

To preserve information and enable meaningful segmentation, the analysis shifted from a binary churn label to a **time-to-next-order** framework.

Instead of asking *“Did the customer churn within X days?”*, the analysis asks:

> *“If the customer returned, how long did it take — and if not, how long have they been dormant?”*

This reframing allows customer behavior to be compared on a continuous time dimension rather than a single cutoff.

## Risk band definition

Risk band definition (outcome-based, post-anchor)

To describe return behavior in a low-repeat dataset, customers are assigned to observed return-speed bands using days_to_next_order, which is measured after the anchor date:

* **Low risk (≤90 days)**: returned quickly after the anchor

* **Medium risk (91–120 days)**: returned, but with delay

* **High risk (121–180 days)**: returned very late

* **Dormant / very high risk (180+ days or no return)**: did not return within the observed window (or never returned)

These bands are intentionally outcome-based. They are useful for:

* Understanding how long it takes customers to come back (when they do)

* Measuring baseline reorder rates by horizon (e.g., 90/120/180/365 days)

* Benchmarking how “hard” different customer groups are to win back

#### Important limitation (deployability):
Because these bands are defined using future information (days_to_next_order), they cannot be used as decision-time risk segments for incentive targeting. In a real retention workflow, the business does not know the next order date at the moment it decides whether to intervene. Using outcome-defined bands inside the EV policy would introduce future leakage and can distort baseline probabilities toward extreme values (near 0 or 1), which later collapses lift (delta_p) and expected value.

For that reason, Phase 4/5 keeps these bands as a descriptive baseline and shifts the decision segmentation to feature-based risk segments derived only from pre-anchor information (recency + AOV tiers).
Customers are assigned to **risk bands** based solely on observed time-to-next-order:


## Second issue discovered: decision-time validity (future leakage)

While outcome-based risk bands are useful for describing customer return behavior, they are not valid as inputs to a real retention decision. The bands are defined using days_to_next_order, which is only known after the anchor date. That means using these bands to choose incentives would introduce future leakage: the policy would implicitly depend on outcomes that were not available at the time the business would actually act.

This distinction matters because Phase 4/5 requires a baseline probability (p_base) that reflects uncertainty at decision time. If the segmentation key is outcome-derived, baseline rates can become artificially extreme (near 0/1), which collapses incremental lift (delta_p) and makes expected value outputs dominated by costs rather than incremental profit.


## Role of behavioral buckets

Behavioral features (recency, tenure, AOV) are added as descriptive buckets to analyze:

* Which types of customers populate each risk band
* Which subsegments exist within the dominant dormant population

These features do not determine risk bands; they explain them.

## Why this matters for next steps

This Step 3 work produced two complementary assets:

A descriptive baseline: time-to-next-order bands that summarize return speed and dormancy patterns in a low-repeat dataset.

A decision constraint: the realization that outcome-defined bands cannot be used as decision-time segmentation for incentive targeting without leakage.

Therefore, Phase 4/5 keeps days_to_next_order as the evaluation target (to compute reorder probabilities by segment and horizon), but shifts the segmentation used for the offer decision engine to feature-based risk segments built only from pre-anchor information (e.g., recency bands and AOV tiers). This change preserves deployability, restores meaningful baseline probabilities, and prevents expected value calculations from collapsing into “cost-only” recommendations.


