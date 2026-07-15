-- ============================================================
-- Maven Fuzzy Factory — Full Analytical Queries
--
-- All queries below answer the project's core business questions.
-- 2015 is excluded throughout except where noted, since the
-- dataset's final month (March 2015) is a partial month and would
-- distort year-over-year comparisons.
-- ============================================================


-- ============================================================
-- 1. How has revenue and profit changed over time?
-- ============================================================

WITH cte_monthlymetrics AS
(
    SELECT
        DATE_TRUNC('Month', created_at) AS months,
        SUM(price_usd) AS total_revenue,
        SUM(cogs_usd) AS total_cogs,
        SUM(price_usd) - SUM(cogs_usd) AS total_profit
    FROM orders 
    GROUP BY DATE_TRUNC('Month', created_at)
)
, cte_lastmonth AS
(
    SELECT
        months,
        total_revenue,
        total_cogs,
        total_profit,
        LAG(total_profit) OVER (ORDER BY months) AS last_month_profit
    FROM cte_monthlymetrics 
)
SELECT
    months,
    total_revenue,
    total_cogs,
    total_profit,
    last_month_profit,
    total_profit - last_month_profit AS difference
FROM cte_lastmonth
WHERE months < '2015-01-01'
ORDER BY months;


-- ============================================================
-- 2. Which products contribute the most to revenue and profit?
-- ============================================================

SELECT
    p.product_name,
    SUM(oi.price_usd) AS total_revenue,
    SUM(oi.cogs_usd) AS total_cogs,
    SUM(oi.price_usd) - SUM(oi.cogs_usd) AS gross_profit
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id 
WHERE oi.created_at < '2015-01-01'
GROUP BY p.product_name
ORDER BY gross_profit DESC;


-- ============================================================
-- 3. How significant are refunds across different products?
-- ============================================================

SELECT
    p.product_name,
    SUM(oir.refund_amount_usd) AS total_refund_amount,
    COUNT(DISTINCT oir.order_item_refund_id) AS total_item_refunded,
    ROUND(COUNT(DISTINCT oir.order_item_refund_id) * 100.0 / COUNT(DISTINCT oi.order_item_id), 2) AS refund_rate
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id 
LEFT JOIN order_item_refunds oir 
    ON oi.order_item_id = oir.order_item_id 
WHERE oi.created_at < '2015-01-01'
GROUP BY 
    p.product_id, 
    p.product_name 
ORDER BY total_refund_amount DESC, refund_rate DESC;


-- ============================================================
-- 4. Which marketing initiatives generate the strongest
--    business performance? (by campaign)
-- ============================================================

SELECT
    COALESCE(ws.utm_campaign, 'none') AS utm_campaign,
    COUNT(o.order_id) AS total_order,
    SUM(o.price_usd) AS total_revenue,
    SUM(o.price_usd) - SUM(o.cogs_usd) AS total_profit,
    COUNT(ws.website_session_id) AS total_sessions,
    ROUND(COUNT(o.order_id) * 100.0 / COUNT(ws.website_session_id), 2) AS conversion_rate
FROM website_sessions ws 
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at < '2015-01-01'
GROUP BY 
    ws.utm_campaign
ORDER BY total_profit DESC;


-- ============================================================
-- 5. Which marketing combinations generate the strongest
--    business performance? (source + campaign + content + device)
-- ============================================================

SELECT
    ws.device_type,
    COALESCE(ws.utm_source, 'direct') AS utm_source,
    COALESCE(ws.utm_campaign, 'none') AS utm_campaign,
    COALESCE(ws.utm_content, 'none') AS utm_content,
    COUNT(o.order_id) AS total_order,
    SUM(o.price_usd) AS total_revenue,
    SUM(o.price_usd) - SUM(o.cogs_usd) AS total_profit,
    COUNT(ws.website_session_id) AS total_sessions,
    ROUND(COUNT(o.order_id) * 100.0 / COUNT(ws.website_session_id), 2) AS conversion_rate
FROM website_sessions ws 
LEFT JOIN orders o 
    ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at < '2015-01-01'
GROUP BY 
    ws.utm_source,
    ws.utm_campaign,
    ws.utm_content,
    ws.device_type
ORDER BY total_profit DESC;


-- ============================================================
-- 6. Total revenue by content
-- ============================================================

SELECT
    COALESCE(ws.utm_content, 'organic') AS utm_content,
    SUM(o.price_usd) AS total_revenue
FROM website_sessions ws 
JOIN orders o 
    ON ws.website_session_id = o.website_session_id 
WHERE o.created_at < '2015-01-01'
GROUP BY ws.utm_content
ORDER BY total_revenue DESC;


-- ============================================================
-- 7. Where do customers drop off throughout the purchase funnel?
--
-- Built using sequential CTEs, where each stage joins back to
-- website_pageviews and retains only the sessions that progressed
-- from the prior stage so the funnel reflects genuine step-by-
-- step progression rather than independent page counts.
-- ============================================================

WITH home AS 
(
    SELECT
        wp.website_session_id,
        MIN(wp.created_at) AS min_time
    FROM website_pageviews wp
    WHERE wp.pageview_url IN ('/home', '/lander-1', '/lander-2', '/lander-3', '/lander-4', '/lander-5')
    GROUP BY wp.website_session_id
    HAVING MIN(wp.created_at) < '2015-01-01'
)
, products AS 
(
    SELECT
        h.website_session_id
    FROM home h 
    JOIN website_pageviews wp 
        ON h.website_session_id = wp.website_session_id
    WHERE wp.pageview_url = '/products'
)
, products_details AS
(
    SELECT
        p.website_session_id 
    FROM products p
    JOIN website_pageviews wp 
        ON p.website_session_id = wp.website_session_id
    WHERE wp.pageview_url IN ('/the-birthday-sugar-panda', '/the-forever-love-bear', '/the-hudson-river-mini-bear', '/the-original-mr-fuzzy')
)
, cart AS 
(
    SELECT
        pd.website_session_id 
    FROM products_details pd
    JOIN website_pageviews wp 
        ON pd.website_session_id = wp.website_session_id
    WHERE wp.pageview_url = '/cart'
)
, shipping AS 
(
    SELECT
        c.website_session_id
    FROM cart c
    JOIN website_pageviews wp 
        ON c.website_session_id = wp.website_session_id
    WHERE wp.pageview_url = '/shipping'
)
, billing AS
(
    SELECT
        s.website_session_id 
    FROM shipping s
    JOIN website_pageviews wp 
        ON s.website_session_id = wp.website_session_id
    WHERE wp.pageview_url IN ('/billing', '/billing-2')
)
, thank_you AS
(
    SELECT
        b.website_session_id 
    FROM billing b
    JOIN website_pageviews wp 
        ON b.website_session_id = wp.website_session_id
    WHERE wp.pageview_url = '/thank-you-for-your-order'
)
, funnel AS
(
    SELECT 'Home' AS step, COUNT(*) AS session_count, 1 AS orders FROM home
    UNION
    SELECT 'Products' AS step, COUNT(*) AS session_count, 2 AS orders FROM products
    UNION
    SELECT 'Product Details' AS step, COUNT(*) AS session_count, 3 AS orders FROM products_details
    UNION
    SELECT 'Cart' AS step, COUNT(*) AS session_count, 4 AS orders FROM cart
    UNION
    SELECT 'Shipping' AS step, COUNT(*) AS session_count, 5 AS orders FROM shipping
    UNION
    SELECT 'Billing' AS step, COUNT(*) AS session_count, 6 AS orders FROM billing
    UNION
    SELECT 'Order Complete' AS step, COUNT(*) AS session_count, 7 AS orders FROM thank_you 
)
SELECT
    step,
    session_count,
    LAG(session_count) OVER() AS last_step_session_count,
    session_count - LAG(session_count) OVER() AS difference
FROM funnel
ORDER BY orders ASC;


-- ============================================================
-- 8. How effectively does the website convert visitors into
--    customers? (overall, and trended monthly)
-- ============================================================

-- Overall conversion rate
SELECT
    COUNT(DISTINCT wp.website_session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) AS total_orders,
    ROUND(COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) * 100.0 / COUNT(DISTINCT wp.website_session_id), 2) AS conversion_rate
FROM website_pageviews wp 
WHERE wp.created_at < '2015-01-01';

-- Monthly conversion rate trend
SELECT
    DATE_TRUNC('Month', wp.created_at) AS month,
    COUNT(DISTINCT wp.website_session_id) AS total_sessions,
    SUM(CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS total_orders,
    ROUND(SUM(CASE WHEN wp.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT wp.website_session_id), 2) AS conversion_rate
FROM website_pageviews wp 
WHERE wp.created_at < '2015-01-01'
GROUP BY DATE_TRUNC('Month', wp.created_at);

-- Conversion rate by device
SELECT
    ws.device_type, 
    COUNT(DISTINCT wp.website_session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) AS total_orders,
    ROUND(COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN website_session_id END) * 100.0 / COUNT(DISTINCT wp.website_session_id), 2) AS conversion_rate
FROM website_pageviews wp 
JOIN website_sessions ws 
    ON wp.website_session_id = ws.website_session_id 
WHERE wp.created_at < '2015-01-01'
GROUP BY ws.device_type
ORDER BY conversion_rate DESC;

-- Conversion rate by traffic source
SELECT
    COALESCE(ws.utm_source, 'direct') AS utm_source,
    COUNT(DISTINCT wp.website_session_id) AS total_sessions,
    COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN ws.website_session_id END) AS total_orders,
    ROUND(COUNT(DISTINCT CASE WHEN pageview_url = '/thank-you-for-your-order' THEN ws.website_session_id END) * 100.0 / COUNT(DISTINCT wp.website_session_id), 2) AS conversion_rate
FROM website_pageviews wp 
JOIN website_sessions ws 
    ON wp.website_session_id = ws.website_session_id 
WHERE wp.created_at < '2015-01-01'
GROUP BY ws.utm_source
ORDER BY conversion_rate DESC;


-- ============================================================
-- 9. Cart abandonment rate
-- ============================================================

WITH cart_session AS 
(
    SELECT
        wp.website_session_id
    FROM website_pageviews wp
    WHERE wp.pageview_url = '/cart' AND wp.created_at < '2015-01-01'
    GROUP BY wp.website_session_id
)
, completed_order AS 
(
    SELECT
        wp.website_session_id
    FROM website_pageviews wp 
    WHERE wp.pageview_url = '/thank-you-for-your-order'
)
SELECT
    COUNT(cs.website_session_id) AS cart_sessions,
    COUNT(co.website_session_id) AS completed_orders,
    ROUND((1 - COUNT(co.website_session_id)::numeric / COUNT(cs.website_session_id)) * 100.0, 2) AS cart_abandonment_rate
FROM cart_session cs
LEFT JOIN completed_order co
    ON co.website_session_id = cs.website_session_id;


-- ============================================================
-- 10. Session, order, conversion rate, AOV, and revenue per
--     session — monthly trend
-- ============================================================

SELECT
    DATE_PART('Year', ws.created_at) AS year,
    DATE_PART('Month', ws.created_at) AS month,
    COUNT(DISTINCT ws.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0 / COUNT(DISTINCT ws.website_session_id), 2) AS conversion_rate,
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT o.order_id), 2) AS average_order_value,
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws 
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at < '2015-01-01'
GROUP BY year, month;


-- ============================================================
-- VALIDATION QUERIES
--
-- Used to independently verify that key dashboard metrics (KPIs,
-- revenue, AOV, refund rate, revenue per session) match what SQL
-- computes directly from the source tables.
-- ============================================================

-- Sales KPI check: revenue, AOV, units, and order count
SELECT
    SUM(oi.price_usd) AS revenue,
    ROUND(SUM(oi.price_usd) / COUNT(DISTINCT oi.order_id), 2) AS aov,
    COUNT(DISTINCT oi.order_item_id) AS units,
    COUNT(DISTINCT oi.order_id) AS orders
FROM order_items oi
WHERE oi.created_at < '2015-01-01';

-- Refund check: total refund amount and refund rate
SELECT 
    SUM(oir.refund_amount_usd) AS total_refund,
    COUNT(oir.order_item_id) AS total_items_refunded,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT oir.order_id) * 100.0 / COUNT(DISTINCT o.order_id), 2) AS refund_rate
FROM orders o
LEFT JOIN order_item_refunds oir 
    ON o.order_id = oir.order_id 
WHERE o.created_at < '2015-01-01';

-- Revenue per session, all-time
SELECT
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT ws.website_session_id), 2) AS revenue_per_session
FROM website_sessions ws 
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at < '2015-01-01';

-- Average order value, all-time
SELECT
    ROUND(SUM(o.price_usd) / COUNT(DISTINCT o.order_id), 2) AS average_order_value
FROM website_sessions ws 
LEFT JOIN orders o
    ON ws.website_session_id = o.website_session_id 
WHERE ws.created_at < '2015-01-01';
