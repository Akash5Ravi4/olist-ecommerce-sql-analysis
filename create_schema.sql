-- Olist E-Commerce Project — Schema Creation

-- 1. Product category name translation (lookup table, no dependencies)
CREATE TABLE product_category_name_translation (
    product_category_name          VARCHAR(100) PRIMARY KEY,
    product_category_name_english  VARCHAR(100)
);

-- 2. Geolocation (standalone lookup, no FK — many rows per zip prefix)
CREATE TABLE geolocation (
    geolocation_zip_code_prefix  VARCHAR(10),
    geolocation_lat              NUMERIC(10, 6),
    geolocation_lng              NUMERIC(10, 6),
    geolocation_city             VARCHAR(100),
    geolocation_state            VARCHAR(2)
);

-- 3. Customers
CREATE TABLE customers (
    customer_id               VARCHAR(50) PRIMARY KEY,
    customer_unique_id        VARCHAR(50),
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             VARCHAR(100),
    customer_state            VARCHAR(2)
);

-- 4. Sellers
CREATE TABLE sellers (
    seller_id               VARCHAR(50) PRIMARY KEY,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city              VARCHAR(100),
    seller_state             VARCHAR(2)
);

-- 5. Products (references category translation)
CREATE TABLE products (
    product_id                  VARCHAR(50) PRIMARY KEY,
    product_category_name       VARCHAR(100) REFERENCES product_category_name_translation(product_category_name),
    product_name_length         INTEGER,
    product_description_length  INTEGER,
    product_photos_qty          INTEGER,
    product_weight_g            INTEGER,
    product_length_cm           INTEGER,
    product_height_cm           INTEGER,
    product_width_cm            INTEGER
);

-- 6. Orders (references customers)
CREATE TABLE orders (
    order_id                        VARCHAR(50) PRIMARY KEY,
    customer_id                     VARCHAR(50) REFERENCES customers(customer_id),
    order_status                    VARCHAR(20),
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

-- 7. Order items (references orders, products, sellers)
CREATE TABLE order_items (
    order_id             VARCHAR(50) REFERENCES orders(order_id),
    order_item_id         INTEGER,
    product_id            VARCHAR(50) REFERENCES products(product_id),
    seller_id             VARCHAR(50) REFERENCES sellers(seller_id),
    shipping_limit_date   TIMESTAMP,
    price                 NUMERIC(10, 2),
    freight_value         NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 8. Order payments (references orders)
CREATE TABLE order_payments (
    order_id              VARCHAR(50) REFERENCES orders(order_id),
    payment_sequential    INTEGER,
    payment_type          VARCHAR(20),
    payment_installments  INTEGER,
    payment_value         NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- 9. Order reviews (references orders)
CREATE TABLE order_reviews (
    review_id                 VARCHAR(50) PRIMARY KEY,
    order_id                  VARCHAR(50) REFERENCES orders(order_id),
    review_score              INTEGER,
    review_comment_title      VARCHAR(255),
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP
);

-- product_category_name_translation table didnt have pc_gamer and portateis_cozinha_e_preparadores_de_alimentos which are present in other table so we are adding it so that i doesnt have a problem
INSERT INTO product_category_name_translation (product_category_name, product_category_name_english)
VALUES ('pc_gamer', 'pc_gamer');
INSERT INTO product_category_name_translation (product_category_name, product_category_name_english)
VALUES ('portateis_cozinha_e_preparadores_de_alimentos', 'kitchen_portable_appliances');
SELECT * FROM product_category_name_translation WHERE product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos';


-- dummy tabble to remove duplicate from order review
CREATE TABLE order_reviews_staging (
    review_id                 VARCHAR(50),
    order_id                  VARCHAR(50),
    review_score              INTEGER,
    review_comment_title      VARCHAR(255),
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP
);
-- inserting the values of duplicate order review to orginal one by having review id only once as its a primary key
INSERT INTO order_reviews
SELECT DISTINCT ON (review_id) *
FROM order_reviews_staging
ORDER BY review_id, review_answer_timestamp DESC NULLS LAST;
--- deleting duplicate order review
DROP TABLE order_reviews_staging;


SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews;
