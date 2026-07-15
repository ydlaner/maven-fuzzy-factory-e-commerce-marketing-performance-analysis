-- ============================================================
-- Maven Fuzzy Factory — Database Schema (DDL)
-- Defines all 6 tables and their primary/foreign key relationships.
-- ============================================================

-- Table: products
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    product_name VARCHAR(50) NOT NULL
);

-- Table: website_sessions
CREATE TABLE website_sessions (
    website_session_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    user_id INT NOT NULL,
    is_repeat_session INT NOT NULL,
    utm_source VARCHAR(50),
    utm_campaign VARCHAR(50),
    utm_content VARCHAR(50),
    device_type VARCHAR(50) NOT NULL,
    http_referer VARCHAR(50)
);

-- Table: website_pageviews
CREATE TABLE website_pageviews (
    website_pageview_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    website_session_id INT NOT NULL,
    pageview_url VARCHAR(50) NOT NULL
);

ALTER TABLE website_pageviews 
    ADD CONSTRAINT fk_websitepageviews_websitesessions
    FOREIGN KEY (website_session_id)
    REFERENCES website_sessions (website_session_id);

-- Table: orders
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    website_session_id INT NOT NULL,
    user_id INT NOT NULL,
    primary_product_id INT NOT NULL,
    items_purchased INT NOT NULL,
    price_usd DECIMAL(10,2) NOT NULL,
    cogs_usd DECIMAL(10,2) NOT NULL
);

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_products
    FOREIGN KEY (primary_product_id)
    REFERENCES products (product_id);

ALTER TABLE orders
    ADD CONSTRAINT fk_orders_websitesessions
    FOREIGN KEY (website_session_id)
    REFERENCES website_sessions (website_session_id);

-- Table: order_items
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    is_primary_item INT NOT NULL,
    price_usd DECIMAL(10,2) NOT NULL,
    cogs_usd DECIMAL(10,2) NOT NULL
);

ALTER TABLE order_items
    ADD CONSTRAINT fk_orderitems_products
    FOREIGN KEY (product_id)
    REFERENCES products (product_id);

ALTER TABLE order_items
    ADD CONSTRAINT fk_orderitems_orders
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id);

-- Table: order_item_refunds
CREATE TABLE order_item_refunds (
    order_item_refund_id INT PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    order_item_id INT NOT NULL,
    order_id INT NOT NULL,
    refund_amount_usd DECIMAL(10,2) NOT NULL
);
  
ALTER TABLE order_item_refunds
    ADD CONSTRAINT fk_orderitemrefunds_orders
    FOREIGN KEY (order_id)
    REFERENCES orders (order_id);

ALTER TABLE order_item_refunds
    ADD CONSTRAINT fk_orderitemrefunds_orderitems
    FOREIGN KEY (order_item_id)
    REFERENCES order_items (order_item_id);
