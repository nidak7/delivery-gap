# Data

## Source

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) on Kaggle. It has about 100,000 orders placed on the Olist marketplace between 2016 and 2018. The data is anonymised by Olist.

Licence: CC BY-NC-SA 4.0 (non-commercial use, with credit, shared under the same licence).

## Download

The raw files go in `data/raw`, which is not committed. With the Kaggle command line tool set up:

```
kaggle datasets download -d olistbr/brazilian-ecommerce --unzip -p data/raw
```

Then load them with the SQL files (see `sql/README.md`).

## Tables

| Table | CSV file | Rows | One row per |
|---|---|---|---|
| customers | olist_customers_dataset.csv | 99,441 | order's customer id (`customer_unique_id` is the real person) |
| sellers | olist_sellers_dataset.csv | 3,095 | seller |
| products | olist_products_dataset.csv | 32,951 | product |
| category_names | product_category_name_translation.csv | 71 (+2 added by hand) | Portuguese category name, with the English name |
| orders | olist_orders_dataset.csv | 99,441 | order, with purchase, carrier, delivery and promised dates |
| order_items | olist_order_items_dataset.csv | 112,650 | item in an order, with seller, price, freight and ship-by limit |
| order_payments | olist_order_payments_dataset.csv | 103,886 | payment for an order |
| order_reviews | olist_order_reviews_dataset.csv | 99,224 | review of an order |
| geolocation | olist_geolocation_dataset.csv | 1,000,163 | zip prefix point (many per prefix, with duplicates) |

## Export: data/export/order_delivery.csv

The `order_delivery` view saved as a CSV, one row per delivered order (96,470 rows).

| Column | Meaning |
|---|---|
| order_id | order id |
| customer_unique_id | the person who bought |
| customer_state | customer's state |
| seller_id | seller of the first item |
| seller_state | that seller's state |
| category | English category of the first item ('unknown' if missing) |
| purchased_at | purchase time |
| purchase_month | first day of the purchase month |
| delivered_at | time the customer received it |
| promised_date | delivery date shown to the customer |
| delivery_days | days from purchase to delivery |
| promised_days | days from purchase to the promised date |
| days_early | promised date minus delivery date (negative = late) |
| is_late | delivered after the promised date |
| delivery_group | '1. Late', '2. 0-6 days early', '3. 7-13 days early', '4. 14+ days early' |
| seller_shipped_late | seller handed it to the carrier after the ship-by limit |
| items | number of items |
| sellers | number of different sellers |
| order_value | sum of item prices |
| freight_value | sum of freight |
| same_state | customer and seller are in the same state |
| distance_km | straight-line distance from seller zip to customer zip (478 missing) |
| review_score | latest review score, 1-5 (646 missing) |
