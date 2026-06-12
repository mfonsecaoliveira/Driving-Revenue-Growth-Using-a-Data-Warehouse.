/* =====================================================================
   Driving Revenue Growth Using a Data Warehouse
   Analytical Insights — BigQuery SQL
   ---------------------------------------------------------------------
   Source: retail_dm.vw_sales_summary (curated data mart / Platinum layer)
   Dialect: Google BigQuery (Standard SQL)

   Note: the result figures in the report are simulated, built to match
   the lab schema and typical retail patterns. The queries themselves are
   production-shaped and run against the vw_sales_summary view.
   ===================================================================== */


/* ---------------------------------------------------------------------
   Insight 1 — Revenue Trends Over Time
   Monthly revenue, used to surface seasonality and the Q4 peak.
   --------------------------------------------------------------------- */
SELECT
    year,
    month_number,
    month_name,
    SUM(net_amount) AS total_revenue
FROM retail_dm.vw_sales_summary
GROUP BY year, month_number, month_name
ORDER BY year, month_number;


/* ---------------------------------------------------------------------
   Insight 2 — Top-Performing Product Categories
   Revenue by category, ranked. Exposes the Pareto concentration.
   --------------------------------------------------------------------- */
SELECT
    category_name,
    SUM(net_amount) AS revenue
FROM retail_dm.vw_sales_summary
GROUP BY category_name
ORDER BY revenue DESC;


/* ---------------------------------------------------------------------
   Insight 3 — Customer Spend Segmentation
   Top customers by total spend, using a window RANK().
   --------------------------------------------------------------------- */
WITH customer_totals AS (
    SELECT
        customer_id,
        SUM(net_amount) AS total_spent
    FROM retail_dm.vw_sales_summary
    GROUP BY customer_id
)
SELECT
    customer_id,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) AS customer_rank
FROM customer_totals
ORDER BY customer_rank
LIMIT 10;


/* ---------------------------------------------------------------------
   Insight 4 — Channel Performance (Online vs In-Store)
   --------------------------------------------------------------------- */
SELECT
    channel,
    SUM(net_amount) AS revenue
FROM retail_dm.vw_sales_summary
GROUP BY channel
ORDER BY revenue DESC;


/* ---------------------------------------------------------------------
   Insight 5 — Average Order Value & Basket Size
   --------------------------------------------------------------------- */
SELECT
    AVG(net_amount) AS avg_order_value,
    AVG(quantity)   AS avg_units_per_order
FROM retail_dm.vw_sales_summary;


/* ---------------------------------------------------------------------
   Insight 6 — Advanced Customer Segmentation (RFM)
   Recency, Frequency, Monetary scoring with NTILE, then a CASE-based
   segment label. The core of the retention strategy.
   --------------------------------------------------------------------- */
WITH rfm AS (
    SELECT
        customer_id,
        DATE_DIFF(CURRENT_DATE(), MAX(order_date), DAY) AS recency,
        COUNT(DISTINCT order_id)                        AS frequency,
        SUM(net_amount)                                 AS monetary
    FROM retail_dm.vw_sales_summary
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT
        customer_id,
        recency,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency)    AS f_score,
        NTILE(5) OVER (ORDER BY monetary)     AS m_score
    FROM rfm
)
SELECT
    customer_id,
    recency,
    frequency,
    monetary,
    CONCAT('R:', r_score, ' F:', f_score, ' M:', m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2                  THEN 'Lost'
        ELSE 'Needs Attention'
    END AS segment
FROM rfm_scores
ORDER BY monetary DESC;
