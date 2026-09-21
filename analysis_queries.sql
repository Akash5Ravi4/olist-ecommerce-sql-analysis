--Query 1: Monthly Revenue trend
SELECT
    DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
    ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY order_month
ORDER BY order_month;


--Query 2: Top Product Categories by Revenue
--question: Which product categories generate the most revenue, and how many orders do they represent?
SELECT
    t.product_category_name_english AS category,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_item_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 15;


--Query 3: Delivery Time vs. Review Score
--question: Does how long delivery takes affect how customers rate their order?

SELECT
    r.review_score,
    COUNT(*) AS num_orders,
    ROUND(AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)))::NUMERIC, 2) AS avg_days_early_or_late
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;

-- Query 4: Payment Method Breakdown
-- question: What payment methods do customers use, and how does that relate to order value?
SELECT
    payment_type,
    COUNT(*) AS num_payments,
    ROUND(AVG(payment_value)::NUMERIC, 2) AS avg_payment_value,
    ROUND(AVG(payment_installments)::NUMERIC, 1) AS avg_installments,
    ROUND(SUM(payment_value)::NUMERIC, 2) AS total_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;

-- Query 5: Revenue and Orders by State
--question: Which states generate the most revenue and orders?
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(oi.price + oi.freight_value)::NUMERIC, 2) AS avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

-- Query 6: Seller Performance (revenue, volume, late-shipment rate)
--question: Which sellers generate the most revenue, and how reliably do they ship on time?
SELECT
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    ROUND(SUM(oi.price)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(oi.price)::NUMERIC, 2) AS avg_item_price,
    COUNT(*) FILTER (
        WHERE o.order_delivered_carrier_date > oi.shipping_limit_date
    ) AS late_shipments,
    ROUND(
        COUNT(*) FILTER (WHERE o.order_delivered_carrier_date > oi.shipping_limit_date)::NUMERIC
        / COUNT(*) * 100
    , 2) AS late_shipment_pct
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_delivered_carrier_date IS NOT NULL
GROUP BY oi.seller_id
ORDER BY total_revenue DESC
LIMIT 20;

-- Query 7: Category-Level Review Scores
-- question: Do certain product categories get worse reviews on average, independent of delivery timing?
SELECT
    t.product_category_name_english AS category,
    COUNT(*) AS num_reviews,
    ROUND(AVG(r.review_score)::NUMERIC, 2) AS avg_review_score,
    ROUND(
        AVG(EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)))::NUMERIC
    , 2) AS avg_days_early_or_late
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
JOIN orders o ON oi.order_id = o.order_id
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY t.product_category_name_english
HAVING COUNT(*) >= 30
ORDER BY avg_review_score ASC
LIMIT 20;

--Query 8: Month-on-Month Revenue Growth with LAG()

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month,
        ROUND(SUM(oi.price + oi.freight_value)::NUMERIC, 2) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY order_month
)
SELECT
    order_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY order_month) AS prev_month_revenue,
    ROUND(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_month))
        / LAG(total_revenue) OVER (ORDER BY order_month) * 100
    , 2) AS pct_growth
FROM monthly_revenue
ORDER BY order_month;

-- Query 9: Customer Ranking by Total Spend (window function)
--question: Who are the top customers by lifetime spend, and how do they rank?
WITH customer_spend AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS total_spend,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    ROUND(total_spend::NUMERIC, 2) AS total_spend,
    total_orders,
    RANK() OVER (ORDER BY total_spend DESC) AS spend_rank
FROM customer_spend
ORDER BY spend_rank
LIMIT 20;

-- Query 10: Cohort Retention Analysis
--question: Of customers who made their first purchase in a given month, what percentage came back and ordered again in later months?
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
),
first_purchase AS (
    SELECT
        customer_unique_id,
        MIN(order_month) AS cohort_month
    FROM customer_orders
    GROUP BY customer_unique_id
),
cohort_activity AS (
    SELECT
        f.cohort_month,
        co.order_month,
        (DATE_PART('year', co.order_month) - DATE_PART('year', f.cohort_month)) * 12
            + (DATE_PART('month', co.order_month) - DATE_PART('month', f.cohort_month)) AS month_number,
        COUNT(DISTINCT co.customer_unique_id) AS active_customers
    FROM customer_orders co
    JOIN first_purchase f ON co.customer_unique_id = f.customer_unique_id
    GROUP BY f.cohort_month, co.order_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS num_customers
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.month_number,
    ca.active_customers,
    cs.num_customers AS cohort_size,
    ROUND(ca.active_customers::NUMERIC / cs.num_customers * 100, 2) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs ON ca.cohort_month = cs.cohort_month
ORDER BY ca.cohort_month, ca.month_number;

--Query 11: EXPLAIN ANALYZE + Fixing a Non-Sargable Predicate
EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE EXTRACT(YEAR FROM order_purchase_timestamp) = 2017;

CREATE INDEX idx_orders_purchase_timestamp ON orders(order_purchase_timestamp);

EXPLAIN ANALYZE
SELECT *
FROM orders
WHERE order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp < '2018-01-01';