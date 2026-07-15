-- ============================================================
-- Maven Fuzzy Factory — Exploratory Data Analysis
--
-- Purpose: initial investigation of the dataset prior to writing
-- the main analytical queries. Covers schema exploration, dimension
-- value checks, date range checks, and headline measure checks.
-- ============================================================


-- ============================================================
-- 1. SCHEMA EXPLORATION
-- Reviewing all tables, columns, and data types before writing
-- any analytical queries.
-- ============================================================

SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public';

SELECT table_name, COUNT(column_name) AS column_count
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_name;


-- ============================================================
-- 2. DIMENSION EXPLORATION
-- Checking the distinct values in each categorical column to
-- understand what values exist before grouping or filtering
-- on them.
-- ============================================================

-- All product names
SELECT DISTINCT product_name 
FROM products;

-- All campaigns that have run
SELECT DISTINCT utm_campaign 
FROM website_sessions;

-- All content variants used
SELECT DISTINCT utm_content 
FROM website_sessions;

-- All traffic sources
SELECT DISTINCT utm_source 
FROM website_sessions;

-- All device types used to access the site
SELECT DISTINCT device_type 
FROM website_sessions;

-- All referrer values
SELECT DISTINCT http_referer 
FROM website_sessions;

-- All pageview URLs
SELECT DISTINCT pageview_url 
FROM website_pageviews;


-- ============================================================
-- DATA QUALITY FINDING
--
-- The dimension exploration above revealed NULL-like values in
-- website_sessions across utm_campaign, utm_content, utm_source,
-- and http_referer. In this context, a NULL represents a session
-- that did not originate from a paid campaign/ad — i.e. direct or
-- organic traffic — rather than missing data.
--
-- However, these values were stored as the literal text string
-- "NULL", not an actual SQL NULL. This required an explicit fix
-- so downstream aggregations (COALESCE, GROUP BY, etc.) would
-- treat them correctly.
-- ============================================================

UPDATE website_sessions
SET
    utm_campaign = REPLACE(utm_campaign, 'NULL', NULL),
    utm_content = REPLACE(utm_content, 'NULL', NULL),
    utm_source = REPLACE(utm_source, 'NULL', NULL),
    http_referer = REPLACE(http_referer, 'NULL', NULL)
WHERE utm_campaign = 'NULL' 
   OR utm_content = 'NULL' 
   OR utm_source = 'NULL' 
   OR http_referer = 'NULL';

-- Recheck to confirm no literal-string "NULL" values remain
SELECT *
FROM website_sessions
WHERE utm_source = 'NULL';


-- ============================================================
-- 3. DATE RANGE EXPLORATION
-- Establishing the time span covered by the dataset.
-- ============================================================

SELECT
    MIN(o.created_at) AS earliest_order,
    MAX(o.created_at) AS latest_order,
    DATE_PART('year', MAX(o.created_at)) - DATE_PART('year', MIN(o.created_at)) AS year_span 
FROM orders o;


-- ============================================================
-- 4. HEADLINE MEASURE CHECKS
-- Quick top-line numbers. 
-- ============================================================

SELECT SUM(price_usd) AS total_revenue FROM orders;

SELECT AVG(price_usd) AS avg_revenue FROM orders;

SELECT SUM(items_purchased) AS total_items_sold FROM orders;

SELECT SUM(cogs_usd) AS total_cogs FROM orders;

SELECT SUM(refund_amount_usd) AS total_refunds FROM order_item_refunds;

SELECT COUNT(order_id) AS total_orders FROM orders;

SELECT COUNT(product_id) AS total_products FROM products;

-- Unique customers who have made a purchase
SELECT COUNT(DISTINCT user_id) AS total_purchasing_users FROM orders;

-- Unique customers who have visited the site (purchased or not)
SELECT COUNT(DISTINCT user_id) AS total_visiting_users FROM website_sessions;


-- ============================================================
-- 5. MAGNITUDE ANALYSIS
-- Breaking down revenue and refunds by product and by campaign
-- to see where volume concentrates.
-- ============================================================

-- Revenue and units sold by product
SELECT
    p.product_name,
    SUM(oi.price_usd) AS total_revenue,
    COUNT(oi.order_item_id) AS total_items_sold
FROM products p
JOIN order_items oi
    ON p.product_id = oi.product_id 
GROUP BY 
    p.product_id,
    p.product_name
ORDER BY total_revenue DESC;

-- Refund amount and item count by product
SELECT
    p.product_name,
    SUM(oir.refund_amount_usd) AS total_refunds,
    COUNT(oir.order_item_refund_id) AS total_items_refunded
FROM products p
JOIN order_items oi 
    ON p.product_id = oi.product_id 
LEFT JOIN order_item_refunds oir 
    ON oi.order_item_id = oir.order_item_id
GROUP BY p.product_name
ORDER BY total_refunds DESC;

-- Revenue by campaign / content / source combination
SELECT
    ws.utm_campaign,
    ws.utm_content,
    ws.utm_source,
    SUM(o.price_usd) AS total_revenue
FROM website_sessions ws 
JOIN orders o 
    ON ws.website_session_id = o.website_session_id
JOIN products p 
    ON o.primary_product_id = p.product_id 
GROUP BY 
    ws.utm_campaign,
    ws.utm_content,
    ws.utm_source
ORDER BY total_revenue DESC;


-- ============================================================
-- 6. RANKING ANALYSIS
-- Identifying top-performing months and years by revenue.
-- ============================================================

-- Highest-revenue month within each year
WITH cte_monthly_sales AS
(
    SELECT
        DATE_PART('Year', o.created_at) AS year_number,
        DATE_PART('Month', o.created_at) AS month_number,
        TO_CHAR(o.created_at, 'YYYY') AS year_name,
        TO_CHAR(o.created_at, 'FMMonth') AS month_name,
        SUM(o.price_usd) AS total_revenue,
        ROW_NUMBER() OVER (PARTITION BY DATE_PART('Year', o.created_at) ORDER BY SUM(o.price_usd) DESC) AS rank_by_sales
    FROM orders o
    GROUP BY 
        DATE_PART('Year', o.created_at),
        DATE_PART('Month', o.created_at),
        TO_CHAR(o.created_at, 'YYYY'),
        TO_CHAR(o.created_at, 'FMMonth')
)
SELECT
    year_name,
    month_name,
    total_revenue,
    rank_by_sales 
FROM cte_monthly_sales 
ORDER BY year_number;

-- Revenue by campaign, by year
SELECT
    ws.utm_campaign AS campaign,
    DATE_PART('Year', o.created_at) AS year_number,
    SUM(o.price_usd) AS total_revenue
FROM website_sessions ws 
JOIN orders o 
    ON ws.website_session_id = o.website_session_id 
GROUP BY 
    campaign,
    year_number
ORDER BY campaign, total_revenue DESC;
