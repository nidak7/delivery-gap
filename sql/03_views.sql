-- Views that turn the raw tables into one clean row per delivered order.
-- Every query, the notebook and the dashboard use these, so "late" means the same thing everywhere.
-- Run: psql -h localhost -U analyst -d olist -f sql/03_views.sql

DROP VIEW IF EXISTS order_delivery CASCADE;
DROP MATERIALIZED VIEW IF EXISTS zip_locations CASCADE;

-- The geolocation file has many rows per zip prefix, so I keep one average point per prefix.
CREATE MATERIALIZED VIEW zip_locations AS
SELECT zip_prefix,
       AVG(lat) AS lat,
       AVG(lng) AS lng
FROM geolocation
GROUP BY zip_prefix;

CREATE INDEX ON zip_locations (zip_prefix);
CREATE INDEX IF NOT EXISTS idx_items_order ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_reviews_order ON order_reviews (order_id);

CREATE VIEW order_delivery AS
WITH latest_review AS (
    -- a few orders have more than one review; keep the latest one
    SELECT DISTINCT ON (order_id) order_id, score
    FROM order_reviews
    ORDER BY order_id, answered_at DESC
),
items AS (
    SELECT order_id,
           COUNT(*)                AS items,
           SUM(price)              AS order_value,
           SUM(freight_value)      AS freight_value,
           COUNT(DISTINCT seller_id) AS sellers,
           MIN(ship_by_limit)      AS ship_by_limit
    FROM order_items
    GROUP BY order_id
),
first_item AS (
    -- the seller and category of the first item stand in for the order
    SELECT oi.order_id, oi.seller_id, COALESCE(cn.category_en, 'unknown') AS category
    FROM order_items oi
    LEFT JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_names cn ON cn.category_pt = p.category_pt
    WHERE oi.order_item_id = 1
)
SELECT o.order_id,
       c.customer_unique_id,
       c.state                                           AS customer_state,
       s.seller_id,
       s.state                                           AS seller_state,
       fi.category,
       o.purchased_at,
       DATE_TRUNC('month', o.purchased_at)::date         AS purchase_month,
       o.delivered_at,
       o.promised_date,
       o.delivered_at::date - o.purchased_at::date       AS delivery_days,
       o.promised_date - o.purchased_at::date            AS promised_days,
       o.promised_date - o.delivered_at::date            AS days_early,     -- negative = late
       (o.delivered_at::date > o.promised_date)          AS is_late,
       CASE
           WHEN o.delivered_at::date > o.promised_date THEN '1. Late'
           WHEN o.promised_date - o.delivered_at::date < 7 THEN '2. 0-6 days early'
           WHEN o.promised_date - o.delivered_at::date < 14 THEN '3. 7-13 days early'
           ELSE '4. 14+ days early'
       END                                               AS delivery_group,
       (o.handed_to_carrier > i.ship_by_limit)           AS seller_shipped_late,
       i.items,
       i.sellers,
       i.order_value,
       i.freight_value,
       (c.state = s.state)                               AS same_state,
       ROUND((6371 * 2 * ASIN(SQRT(
             POWER(SIN(RADIANS(zc.lat - zs.lat) / 2), 2) +
             COS(RADIANS(zs.lat)) * COS(RADIANS(zc.lat)) *
             POWER(SIN(RADIANS(zc.lng - zs.lng) / 2), 2))))::numeric, 0) AS distance_km,
       lr.score                                          AS review_score
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
JOIN items i            ON i.order_id = o.order_id
JOIN first_item fi      ON fi.order_id = o.order_id
JOIN sellers s          ON s.seller_id = fi.seller_id
LEFT JOIN latest_review lr ON lr.order_id = o.order_id
LEFT JOIN zip_locations zc ON zc.zip_prefix = c.zip_prefix
LEFT JOIN zip_locations zs ON zs.zip_prefix = s.zip_prefix
WHERE o.status = 'delivered'
  AND o.delivered_at IS NOT NULL
  AND o.promised_date IS NOT NULL;
