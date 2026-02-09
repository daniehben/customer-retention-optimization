-- Analysis 1 — Offer viability audit
-- Which offer types survive Model A at all?

SELECT
    offer_type,
    COUNT(*) AS n_anchors,
    AVG(net_ev_default) AS avg_ev,
    SUM(CASE WHEN net_ev_default > 0 THEN 1 ELSE 0 END) AS n_positive_ev,
    SUM(CASE WHEN net_ev_default > 0 THEN 1 ELSE 0 END)::float / COUNT(*) AS pct_positive_ev
FROM churn.v6_offer_ev
GROUP BY 1
ORDER BY avg_ev DESC;


-- Analysis 2 — Risk band × offer matrix 
-- Are incentives ever justified, and for whom?

SELECT
  risk_band,
  offer_type,
  COUNT(*) AS n,
  AVG(net_ev_default) AS avg_ev,
  SUM(CASE WHEN net_ev_default > 0 THEN 1 ELSE 0 END)::float / COUNT(*) AS pct_positive
FROM churn.v6_offer_ev
GROUP BY risk_band, offer_type
ORDER BY risk_band, offer_type;


-- Analysis 3 — Cost pressure vs value pressure
-- why EV is negative

SELECT
  offer_type,
  AVG(incremental_profit) AS avg_incremental_profit,
  AVG(expected_offer_cost) AS avg_expected_cost,
  AVG(net_ev_default) AS avg_net_ev
FROM churn.v6_offer_ev
GROUP BY offer_type
ORDER BY avg_net_ev;


-- Analysis 4 — Who is being punished the most?
-- Are high-value customers being penalized by % discounts?

SELECT
  offer_type,
  NTILE(4) OVER (ORDER BY aov_pre_anchor) AS aov_quartile,
  AVG(net_ev_default) AS avg_ev
FROM churn.v6_offer_ev
GROUP BY offer_type, aov_quartile
ORDER BY offer_type, aov_quartile;
