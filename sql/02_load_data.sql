-- Loads the Kaggle CSV files into the tables. Run from the project folder:
-- psql -h localhost -U analyst -d olist -f sql/02_load_data.sql

\copy customers      FROM 'data/raw/olist_customers_dataset.csv'          WITH (FORMAT csv, HEADER true)
\copy sellers        FROM 'data/raw/olist_sellers_dataset.csv'            WITH (FORMAT csv, HEADER true)
\copy category_names FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)
\copy products       FROM 'data/raw/olist_products_dataset.csv'           WITH (FORMAT csv, HEADER true)
\copy orders         FROM 'data/raw/olist_orders_dataset.csv'             WITH (FORMAT csv, HEADER true)
\copy order_items    FROM 'data/raw/olist_order_items_dataset.csv'        WITH (FORMAT csv, HEADER true)
\copy order_payments FROM 'data/raw/olist_order_payments_dataset.csv'     WITH (FORMAT csv, HEADER true)
\copy order_reviews  FROM 'data/raw/olist_order_reviews_dataset.csv'      WITH (FORMAT csv, HEADER true)
\copy geolocation    FROM 'data/raw/olist_geolocation_dataset.csv'        WITH (FORMAT csv, HEADER true)

-- Two categories have no English name in the translation file, so I add them by hand.
INSERT INTO category_names VALUES
    ('pc_gamer', 'pc_gamer'),
    ('portateis_cozinha_e_preparadores_de_alimentos', 'portable_kitchen_appliances')
ON CONFLICT DO NOTHING;

-- Refresh table statistics after a bulk load. Without this, PostgreSQL picks slow join plans
-- (the main view took over 5 minutes instead of under a second).
ANALYZE customers, sellers, category_names, products, orders, order_items, order_payments, order_reviews, geolocation;

-- Row counts to compare with the CSV files
SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;
