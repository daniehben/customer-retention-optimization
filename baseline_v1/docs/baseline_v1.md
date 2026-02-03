# Customer Retention Optimization — Baseline V1

## Executive Summary

Baseline V1 evaluates a rule-based retention strategy using bucket-level churn probabilities (p0) and expected value logic.  
The goal is not to optimize performance, but to **expose the limitations of coarse probability assumptions before introducing machine learning**.

Result:
- Only **4 out of 2,784 customers (0.14%)** show positive expected value
- Budget allocation becomes value-destructive almost immediately
- Offer selection collapses into a narrow, unrealistic recommendation

This baseline establishes a **control condition** against which all future improvements are measured.

---

## 1. Problem Definition

The business problem is framed as a decision problem:

> Given a limited retention budget, which customers should receive incentives such that expected retained value exceeds incentive cost?

This project deliberately begins **without machine learning**, using:
- Rule-based churn probabilities
- Transparent cost assumptions
- Expected value accounting
- Budget-constrained decision logic

---

## 2. Baseline V1 Assumptions (p0)

Churn probabilities (p0) are assigned at the **bucket level**, based on:
- Average freight bucket
- Offer type (5% discount, 10% discount, free shipping)
- Global fallback probabilities for sparse segments

Key characteristics:
- Very few distinct probability values
- No customer-level differentiation
- Heavy reliance on fallback logic

These probabilities feed into:
- Expected Gain
- Expected Cost
- Net Expected Value (EV)

---

## 3. Visualization Findings

### 3.1 Baseline Churn Probability Distribution (p0)

**Insight**
- Probabilities collapse into ~6 discrete values
- Customers within buckets are indistinguishable

**Implication**
There is almost no ranking resolution. Optimization downstream is structurally limited.

---

### 3.2 Customer Volume by Freight Bucket

**Insight**
- Customer volume is highly concentrated
- Several buckets are extremely sparse

**Implication**
Fallback assumptions dominate low-volume segments, introducing noise rather than signal.

---

### 3.3 Offer Economics: Expected Cost vs Expected Gain

**Insight**
- Most customer-offer combinations fall below break-even
- Expected gains cluster tightly due to coarse probabilities

**Implication**
Offers appear unprofitable not because they are bad, but because p0 lacks precision.

---

### 3.4 Net Expected Value Distribution

**Insight**
- Net EV mass concentrates just below zero
- Very few positive outcomes exist
- Offer types heavily overlap

**Implication**
Baseline probabilities compress value signals and erase differentiation.

---

### 3.5 Customers with Positive Expected Value

**Result**
- 4 out of 2,784 customers
- 0.14% positive EV rate

**Interpretation**
This is a modeling failure, not a business reality.

---

### 3.6 Budget Allocation Curve — Baseline V1

**Insight**
- Initial spend yields minimal value
- Additional spend rapidly destroys value
- No stable plateau exists

**Decision Rule Tested**
Allocate budget from highest Net EV downward.

**Outcome**
Under Baseline V1, any meaningful budget allocation is value-destructive.

---

### 3.7 Offer Mix Under Budget Constraint

**Insight**
- Selection collapses to a tiny subset of offers
- Diversity disappears due to probability compression

**Implication**
Baseline V1 produces unrealistic, brittle recommendations.

---

## 4. Why Baseline V1 Fails (On Purpose)

Baseline V1 fails because:
1. Bucket-level probabilities eliminate ranking resolution
2. Fallback logic dominates sparse segments
3. Expected gains collapse into narrow bands
4. Budget optimization amplifies small probability errors

This failure is **diagnostic**, not accidental.

---

## 5. Why This Baseline Matters

Baseline V1 provides:
- A transparent benchmark
- A reproducible control condition
- Clear justification for model sophistication

Any future uplift can now be measured against:
- Positive EV rate
- Budget efficiency
- Value preservation under scale

---

## 6. Next Steps

Planned improvements:
- Customer-level churn modeling
- Probability calibration
- Offer-specific uplift estimation
- Budget-aware optimization
- Scenario comparison vs Baseline V1

Baseline V1 remains the reference point.


