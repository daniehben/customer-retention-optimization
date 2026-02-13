SELECT
  (SELECT COUNT(*) FROM churn.v1_7_c_decision_output_customers) AS v7c_rows,
  (SELECT COUNT(*) FROM churn.v7e_activation_feed_customers) AS v7e_rows;

SELECT *
FROM churn.v7_e_activation_feed_customers
LIMIT 3