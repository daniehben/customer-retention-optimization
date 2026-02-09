# **Step 3 – Baseline Risk Segmentation (From Churn to Time-to-Event)**

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

Customers are assigned to **risk bands** based solely on observed time-to-next-order:

* **Low risk (≤90 days)**: fast returners
* **Medium risk (91–120 days)**: delayed returners
* **High risk (121–180 days)**: very delayed returners
* **Dormant / very high risk (180+ days or no return)**: non-returning customers

These risk bands represent **outcomes**, not predictions.

## Role of behavioral buckets

Behavioral features (recency, tenure, AOV) are added as descriptive buckets to analyze:

* Which types of customers populate each risk band
* Which subsegments exist within the dominant dormant population

These features do not determine risk bands; they explain them.

## Why this matters for next steps

This time-to-event baseline creates a realistic foundation for:

* Targeted intervention strategies (who is worth saving *now*)
* Expected value calculations (who might still return)
* More advanced modeling (survival analysis, uplift, or ranking)

Rather than forcing churn into an unsuitable dataset, the analysis adapts to the true behavioral structure of the data.


