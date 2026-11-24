-- Analysis queries for The Delivery Gap.
-- Run after 01, 02 and 03: psql -h localhost -U analyst -d olist -f sql/04_analysis_queries.sql
-- Most queries use the order_delivery view (one row per delivered order).
-- A few go back to the base tables to show the joins directly.
-- "Late" means delivered after the promised date (compared as dates).


-- =====================================================================
-- Part 1: data checks
-- =====================================================================

-- Q1. What order statuses are there, and why do I keep only delivered orders?
-- Only delivered orders have both a delivery date and a promise, so only they can be late or on time.
-- Result: 96,478 of 99,441 orders (97.02%) are delivered; the rest are shipped, canceled, etc.
SELECT status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY status
ORDER BY orders DESC;


-- Q2. Orphans and gaps: rows that point to nothing, or are missing something.
-- Result: no orphan orders or items. 775 orders have no items, but none of them are delivered.
--         610 products have no category, and 278 customer zip prefixes are not in the geolocation file.
SELECT 'orders with no customer' AS check_name, COUNT(*) AS rows_found
FROM orders o
LEFT JOIN customers c ON c.customer_id = o.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'orders with no items', COUNT(*)
FROM orders o
WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
UNION ALL
SELECT 'delivered orders with no items', COUNT(*)
FROM orders o
WHERE o.status = 'delivered'
  AND NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id)
UNION ALL
SELECT 'items with a product not in products', COUNT(*)
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'products with no category', COUNT(*)
FROM products
WHERE category_pt IS NULL
UNION ALL
SELECT 'customer zips missing from geolocation', COUNT(*)
FROM customers c
WHERE NOT EXISTS (SELECT 1 FROM zip_locations z WHERE z.zip_prefix = c.zip_prefix);


-- Q3. Nulls and odd dates among delivered orders.
-- Result: 8 delivered orders have no delivery date (dropped by the view, which leaves 96,470).
--         165 orders were handed to the carrier before the purchase time, which looks like a data entry issue.
SELECT COUNT(*) FILTER (WHERE delivered_at IS NULL)              AS no_delivered_at,
       COUNT(*) FILTER (WHERE handed_to_carrier IS NULL)         AS no_handed_to_carrier,
       COUNT(*) FILTER (WHERE approved_at IS NULL)               AS no_approved_at,
       COUNT(*) FILTER (WHERE delivered_at < purchased_at)       AS delivered_before_purchase,
       COUNT(*) FILTER (WHERE handed_to_carrier < purchased_at)  AS shipped_before_purchase,
       COUNT(*)                                                  AS delivered_orders
FROM orders
WHERE status = 'delivered';


-- Q4. Duplicates.
-- Result: no duplicate order ids. 547 orders have 2+ reviews (the view keeps the latest one).
--         2,997 people have more than one customer_id, so repeat buying must use customer_unique_id.
--         The geolocation file has 280,009 exact duplicate rows, which is why the view averages per zip.
WITH review_counts AS (
    SELECT order_id, COUNT(*) AS reviews
    FROM order_reviews
    GROUP BY order_id
),
geo_dupes AS (
    SELECT zip_prefix, lat, lng, COUNT(*) AS copies
    FROM geolocation
    GROUP BY zip_prefix, lat, lng
    HAVING COUNT(*) > 1
)
SELECT 'orders with 2+ reviews' AS check_name, COUNT(*) AS rows_found
FROM review_counts
WHERE reviews > 1
UNION ALL
SELECT 'duplicate order_id in orders', COUNT(*) - COUNT(DISTINCT order_id)
FROM orders
UNION ALL
SELECT 'people with 2+ customer_ids', COUNT(*)
FROM (SELECT customer_unique_id
      FROM customers
      GROUP BY customer_unique_id
      HAVING COUNT(*) > 1) t
UNION ALL
SELECT 'extra copies of geolocation rows', SUM(copies - 1)
FROM geo_dupes;


-- =====================================================================
-- Part 2: how often is the promise missed, and what does it cost in reviews?
-- =====================================================================

-- Q5. Headline numbers: late rate, and median and 90th percentile delivery time.
-- Result: 6.77% of delivered orders were late (6,534 of 96,470).
--         Median delivery is 10 days against a median promise of 24 days; median 12 days early.
--         90% of orders arrive within 23 days.
SELECT COUNT(*)                                                    AS delivered_orders,
       COUNT(*) FILTER (WHERE is_late)                             AS late_orders,
       ROUND(100.0 * AVG(is_late::int), 2)                         AS late_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_early)     AS median_days_early,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days)  AS median_delivery_days,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days)  AS p90_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days)  AS median_promised_days
FROM order_delivery;


-- Q6. Late rate by month (2017-01 to 2018-08; 2016 has too few orders), with change and a 3-month average.
-- Result: usually 3-7% late, but three spikes: 2017-11 (12.40%, Black Friday month),
--         2018-02 (14.13%) and 2018-03 (18.96%, the worst month). 2018-04 then fell by 14.46 points to 4.50%.
WITH monthly AS (
    SELECT purchase_month,
           COUNT(*) AS orders,
           ROUND(100.0 * AVG(is_late::int), 2) AS late_pct
    FROM order_delivery
    WHERE purchase_month BETWEEN '2017-01-01' AND '2018-08-01'
    GROUP BY purchase_month
)
SELECT TO_CHAR(purchase_month, 'YYYY-MM') AS month,
       orders,
       late_pct,
       late_pct - LAG(late_pct) OVER (ORDER BY purchase_month) AS change_vs_last_month,
       ROUND(AVG(late_pct) OVER (ORDER BY purchase_month
                                 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m,
       SUM(orders) OVER (ORDER BY purchase_month) AS running_orders
FROM monthly
ORDER BY purchase_month;


-- Q7. Review score and 1-2 star share by delivery group.
-- Result: late orders average 2.27 stars and 62.4% get 1-2 stars.
--         0-6 days early: 4.17; 7-13 days early: 4.30; 14+ days early: 4.32.
--         Arriving more than a week early adds almost nothing to the score.
SELECT delivery_group,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_orders,
       ROUND(AVG(review_score), 2) AS avg_review,
       ROUND(100.0 * COUNT(*) FILTER (WHERE review_score <= 2) / COUNT(review_score), 1) AS low_review_pct
FROM order_delivery
GROUP BY delivery_group
ORDER BY delivery_group;


-- Q8. A closer look: average review at selected days early (negative = late; ends are capped at -15 and 31).
-- Result: the score climbs fast from 1.72 (15+ days late) to 4.03 (on the day) and 4.26 at 7 days early,
--         then stays flat around 4.3. 1 day late already drops it to 3.73.
WITH by_days AS (
    SELECT CASE WHEN days_early < -14 THEN -15
                WHEN days_early > 30  THEN 31
                ELSE days_early END AS days_early_capped,
           review_score
    FROM order_delivery
    WHERE review_score IS NOT NULL
)
SELECT days_early_capped AS days_early,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 2) AS avg_review
FROM by_days
WHERE days_early_capped IN (-15, -7, -3, -1, 0, 1, 3, 7, 10, 14, 21, 31)
GROUP BY days_early_capped
ORDER BY days_early_capped;


-- =====================================================================
-- Part 3: where do late orders come from?
-- =====================================================================

-- Q9. Late rate by customer state (base tables, states with 500+ orders), ranked.
-- Result: MA is worst at 17.43%, then CE 13.76%, BA 12.16% and RJ 12.11%.
--         RJ matters most because it is a big state (12,350 orders).
SELECT c.state AS customer_state,
       COUNT(*) AS orders,
       ROUND(100.0 * AVG((o.delivered_at::date > o.promised_date)::int), 2) AS late_pct,
       RANK() OVER (ORDER BY AVG((o.delivered_at::date > o.promised_date)::int) DESC) AS late_rank
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.status = 'delivered'
  AND o.delivered_at IS NOT NULL
  AND o.promised_date IS NOT NULL
GROUP BY c.state
HAVING COUNT(*) >= 500
ORDER BY late_rank
LIMIT 10;


-- Q10. Late rate by seller state, with each state's share of all orders and of all late orders.
-- Result: SP sellers handle 71.2% of orders but 77.0% of late ones (7.33% late).
--         MA sellers are the worst at 19.07%, but they are only 388 orders.
SELECT seller_state,
       COUNT(*) AS orders,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
             / SUM(COUNT(*) FILTER (WHERE is_late)) OVER (), 1) AS share_of_late
FROM order_delivery
GROUP BY seller_state
HAVING COUNT(*) >= 300
ORDER BY orders DESC;


-- Q11. Same-state versus cross-state orders.
-- Result: cross-state orders are late 8.05% of the time, same-state 4.50%.
--         Cross-state orders take 13 days (median) against a 27-day promise; same-state 7 against 18.
SELECT CASE WHEN same_state THEN 'same state' ELSE 'different state' END AS route,
       COUNT(*) AS orders,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days) AS median_promised_days
FROM order_delivery
GROUP BY same_state;


-- Q12. Late rate by distance, in five equal-sized bands (NTILE). 478 orders with no distance are left out.
-- Result: the late rate rises steadily with distance, from 4.54% (under 116 km) to 9.70% (877 km and more).
--         The promise also grows with distance (15 to 30 days median), but not quite enough.
WITH banded AS (
    SELECT NTILE(5) OVER (ORDER BY distance_km) AS distance_band,
           distance_km, is_late, delivery_days, promised_days
    FROM order_delivery
    WHERE distance_km IS NOT NULL
)
SELECT distance_band,
       MIN(distance_km) AS min_km,
       MAX(distance_km) AS max_km,
       COUNT(*) AS orders,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_delivery_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days) AS median_promised_days
FROM banded
GROUP BY distance_band
ORDER BY distance_band;


-- Q13. Seller handover: does it matter if the seller hands the parcel to the carrier after the ship-by limit?
-- Result: when the seller shipped late, 20.80% of orders were late, against 5.38% when the seller was on time.
--         Late handovers are only 9% of orders but explain 27.8% of all late orders.
--         So most late orders (72.2%) are lost in transit, not at the seller.
SELECT CASE WHEN seller_shipped_late THEN 'seller shipped late' ELSE 'seller shipped on time' END AS handover,
       COUNT(*) AS orders,
       COUNT(*) FILTER (WHERE is_late) AS late_orders,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
             / SUM(COUNT(*) FILTER (WHERE is_late)) OVER (), 1) AS share_of_all_late
FROM order_delivery
WHERE seller_shipped_late IS NOT NULL      -- 1 order has no carrier date
GROUP BY seller_shipped_late
ORDER BY seller_shipped_late;


-- Q14. Worst sellers by late rate (base tables, sellers with 50+ delivered orders).
-- Here an order counts for every seller in it, not only the first item's seller.
-- Result: the worst seller is late on 30.1% of 73 orders. One MA seller has 389 orders and is late on 19.0%,
--         which is almost all of the MA seller-state result in Q10.
WITH seller_stats AS (
    SELECT s.seller_id,
           s.state AS seller_state,
           COUNT(DISTINCT o.order_id) AS orders,
           COUNT(DISTINCT o.order_id) FILTER (WHERE o.delivered_at::date > o.promised_date) AS late_orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN sellers s      ON s.seller_id = oi.seller_id
    WHERE o.status = 'delivered'
      AND o.delivered_at IS NOT NULL
      AND o.promised_date IS NOT NULL
    GROUP BY s.seller_id, s.state
    HAVING COUNT(DISTINCT o.order_id) >= 50
)
SELECT LEFT(seller_id, 8) AS seller,       -- short id is enough to tell them apart
       seller_state,
       orders,
       late_orders,
       ROUND(100.0 * late_orders / orders, 1) AS late_pct,
       DENSE_RANK() OVER (ORDER BY ROUND(100.0 * late_orders / orders, 1) DESC) AS late_rank
FROM seller_stats
ORDER BY late_rank, orders DESC
LIMIT 10;


-- Q15. Are late orders concentrated in a few sellers?
-- Result: the 50 sellers with the most late orders account for 38.1% of late orders,
--         but they also carry 32.3% of all orders. The top 200 account for 65.3% of late orders.
--         So lateness follows volume more than a few bad sellers.
WITH seller_late AS (
    SELECT seller_id,
           COUNT(*) AS orders,
           COUNT(*) FILTER (WHERE is_late) AS late_orders
    FROM order_delivery
    GROUP BY seller_id
),
ranked AS (
    SELECT seller_id, orders, late_orders,
           ROW_NUMBER() OVER (ORDER BY late_orders DESC, orders DESC) AS rn,
           SUM(late_orders) OVER () AS all_late
    FROM seller_late
)
SELECT COUNT(*) AS sellers_total,
       SUM(late_orders) FILTER (WHERE rn <= 50) AS late_from_top_50,
       ROUND(100.0 * SUM(late_orders) FILTER (WHERE rn <= 50) / MAX(all_late), 1)  AS pct_late_from_top_50,
       ROUND(100.0 * SUM(orders) FILTER (WHERE rn <= 50) / SUM(orders), 1)         AS pct_orders_from_top_50,
       ROUND(100.0 * SUM(late_orders) FILTER (WHERE rn <= 200) / MAX(all_late), 1) AS pct_late_from_top_200
FROM ranked;


-- Q16. Categories by late rate (categories with 500+ orders).
-- Result: the spread is narrow: baby is highest at 8.18%, office_furniture 8.11%, electronics 7.66%.
--         Category is not a strong driver of lateness.
SELECT category,
       COUNT(*) AS orders,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct,
       ROUND(AVG(review_score), 2) AS avg_review,
       RANK() OVER (ORDER BY AVG(is_late::int) DESC) AS late_rank
FROM order_delivery
GROUP BY category
HAVING COUNT(*) >= 500
ORDER BY late_rank
LIMIT 10;


-- =====================================================================
-- Part 4: repeat buying
-- =====================================================================

-- Q17. Do customers whose first order was late come back less?
-- Result: 2.59% of people with a late first order placed a second delivered order, against 3.03% on time.
--         For first orders in 2017 (more time to come back), it is 2.80% against 4.24%.
--         Repeat buying is rare on Olist either way, so this is a small group.
WITH person_orders AS (
    SELECT c.customer_unique_id,
           o.purchased_at,
           (o.delivered_at::date > o.promised_date) AS is_late,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.purchased_at) AS order_no,
           COUNT(*) OVER (PARTITION BY c.customer_unique_id) AS total_orders
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.status = 'delivered'
      AND o.delivered_at IS NOT NULL
      AND o.promised_date IS NOT NULL
)
SELECT CASE WHEN is_late THEN 'first order late' ELSE 'first order on time' END AS first_order,
       COUNT(*) AS customers,
       COUNT(*) FILTER (WHERE total_orders >= 2) AS came_back,
       ROUND(100.0 * COUNT(*) FILTER (WHERE total_orders >= 2) / COUNT(*), 2) AS came_back_pct,
       COUNT(*) FILTER (WHERE purchased_at < '2018-01-01') AS customers_2017,
       ROUND(100.0 * COUNT(*) FILTER (WHERE total_orders >= 2 AND purchased_at < '2018-01-01')
             / COUNT(*) FILTER (WHERE purchased_at < '2018-01-01'), 2) AS came_back_pct_2017
FROM person_orders
WHERE order_no = 1
GROUP BY is_late
ORDER BY is_late;


-- =====================================================================
-- Part 5: is the promise too padded?
-- =====================================================================

-- Q18. Median promised days versus median actual days by customer state (states with 1,000+ orders).
-- Result: every big state is padded by 12-16 days. SP: 19 promised, 7 actual.
--         Even states with high late rates are padded: RJ has a 13-day gap but 12.11% late,
--         which means the delivery times there are spread out, not that the promise is short.
SELECT customer_state,
       COUNT(*) AS orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days) AS median_promised,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS median_actual,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days)
         - PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) AS gap_days,
       ROUND(100.0 * AVG(is_late::int), 2) AS late_pct
FROM order_delivery
GROUP BY customer_state
HAVING COUNT(*) >= 1000
ORDER BY gap_days DESC;


-- Q19. What share of orders arrive far earlier than promised?
-- Result: 78.9% arrive 7+ days early, 43.6% 14+ days early and 14.0% 21+ days early.
--         On average the promise is 24.4 days and the delivery 12.5 days.
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE days_early >= 7)  / COUNT(*), 1) AS pct_7plus_early,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_early >= 14) / COUNT(*), 1) AS pct_14plus_early,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_early >= 21) / COUNT(*), 1) AS pct_21plus_early,
       ROUND(AVG(promised_days), 1) AS avg_promised_days,
       ROUND(AVG(delivery_days), 1) AS avg_delivery_days
FROM order_delivery;


-- Q20. What-if: if every promise were k days shorter, what would the late rate be?
-- Result: 0 days: 6.77%; 3 days: 11.23%; 5 days: 15.02%; 7 days: 21.07%; 10 days: 35.89%.
--         A flat cut for everyone is costly: even 3 days nearly doubles late orders.
--         Any shorter promise would need to be targeted (by route or distance), not the same for all.
SELECT k AS days_cut,
       ROUND(100.0 * AVG((delivered_at::date > promised_date - k)::int), 2) AS late_pct,
       COUNT(*) FILTER (WHERE delivered_at::date > promised_date - k) AS late_orders,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY promised_days - k) AS median_promised_days
FROM order_delivery
CROSS JOIN generate_series(0, 10) AS k
WHERE k IN (0, 3, 5, 7, 10)
GROUP BY k
ORDER BY k;
