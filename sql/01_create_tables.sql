-- Tables for the Olist data, with keys so the joins are checked by the database.
-- Run: psql -h localhost -U analyst -d olist -f sql/01_create_tables.sql

DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders, products,
    category_names, sellers, customers, geolocation CASCADE;

CREATE TABLE customers (
    customer_id        TEXT PRIMARY KEY,   -- one per order
    customer_unique_id TEXT NOT NULL,      -- one per person, used for repeat buyers
    zip_prefix         TEXT,
    city               TEXT,
    state              CHAR(2)
);

CREATE TABLE sellers (
    seller_id  TEXT PRIMARY KEY,
    zip_prefix TEXT,
    city       TEXT,
    state      CHAR(2)
);

CREATE TABLE category_names (
    category_pt TEXT PRIMARY KEY,
    category_en TEXT
);

CREATE TABLE products (
    product_id         TEXT PRIMARY KEY,
    category_pt        TEXT,
    name_length        INT,
    description_length INT,
    photos_qty         INT,
    weight_g           NUMERIC,
    length_cm          NUMERIC,
    height_cm          NUMERIC,
    width_cm           NUMERIC
);

CREATE TABLE orders (
    order_id           TEXT PRIMARY KEY,
    customer_id        TEXT NOT NULL REFERENCES customers (customer_id),
    status             TEXT NOT NULL,
    purchased_at       TIMESTAMP NOT NULL,
    approved_at        TIMESTAMP,
    handed_to_carrier  TIMESTAMP,
    delivered_at       TIMESTAMP,
    promised_date      DATE                -- the delivery date shown to the customer
);

CREATE TABLE order_items (
    order_id        TEXT REFERENCES orders (order_id),
    order_item_id   INT,
    product_id      TEXT REFERENCES products (product_id),
    seller_id       TEXT REFERENCES sellers (seller_id),
    ship_by_limit   TIMESTAMP,
    price           NUMERIC(10, 2),
    freight_value   NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id     TEXT REFERENCES orders (order_id),
    payment_seq  INT,
    payment_type TEXT,
    installments INT,
    amount       NUMERIC(10, 2),
    PRIMARY KEY (order_id, payment_seq)
);

CREATE TABLE order_reviews (
    review_id     TEXT,
    order_id      TEXT REFERENCES orders (order_id),
    score         INT CHECK (score BETWEEN 1 AND 5),
    comment_title TEXT,
    comment_text  TEXT,
    created_on    TIMESTAMP,
    answered_at   TIMESTAMP,
    PRIMARY KEY (review_id, order_id)
);

CREATE TABLE geolocation (
    zip_prefix TEXT,
    lat        DOUBLE PRECISION,
    lng        DOUBLE PRECISION,
    city       TEXT,
    state      CHAR(2)
);
