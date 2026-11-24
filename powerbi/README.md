# Power BI dashboard

The dashboard is a Power BI Project (`DeliveryGap.pbip`) with four pages. It reads one file, `data/export/order_delivery.csv` (96,470 delivered orders), into one table called `orders`.

## Open the project

1. In `DeliveryGap.SemanticModel/definition/expressions.tmdl`, set `DataFile` to the full path of `order_delivery.csv` on your machine. The committed file has a placeholder path (`C:\path\to\delivery-gap\data\export\order_delivery.csv`), so the report will not load until you change it.
2. Open `DeliveryGap.pbip` in Power BI Desktop. If it asks, switch on Power BI Project files under Options > Preview features.
3. Click Refresh.

## Pages

1. **Overview**: cards for delivered orders, late rate, median days early and the average review for late and on-time orders. A line chart shows the late rate by purchase month (Jan 2017 to Aug 2018, because 2016 has only 267 orders). Two column charts show the average review and the number of orders in each delivery group.
2. **Where late orders come from**: late rate by customer state (highest first), by seller-to-customer distance band, and for orders the seller handed to the carrier late vs on time. A seller state slicer filters the page.
3. **Sellers and categories**: a table of sellers with at least 30 orders (orders, late rate, average review), sorted by late rate, and the late rate for the 15 categories with the most orders.
4. **How long is the promise**: average days promised vs average actual delivery days by customer state, the number of orders by days early (in one-week bands), and cards comparing the average review for orders that arrive 0-6 days early with those that arrive 7+ days early.

Screenshots are in `../images/` (`dashboard_overview.png`, `dashboard_where_late.png`, `dashboard_sellers_categories.png`, `dashboard_promise.png`).

## Columns added in Power Query

- `late_flag`: 1 if the order was late, 0 if not.
- `distance_band`: 0-100, 100-500, 500-1000, 1000-2000 and 2000+ km, sorted by `distance_band_order`. Orders with no distance (478) have no band and are left out of that chart.
- `early_band`: days early in one-week bands (8+ days late, 1-7 days late, 0-6 early, 7-13 early and so on), sorted by `early_band_order`.
- `group_label`: the delivery group without its number, sorted by `group_order`.
- `seller_ship`: whether the seller shipped late or on time (one order has no value and is left out).
- `month`, `in_trend` (1 from Jan 2017 onwards) and `top15_category` (1 for the 15 categories with the most orders).

There is also one DAX column, `seller_orders`, the number of orders for each seller. The seller table uses it to keep sellers with 30+ orders.

## Measures

| Measure | What it is |
|---|---|
| Orders | Number of delivered orders |
| Late orders | Orders delivered after the promised date |
| Late rate | Late orders / orders |
| Median days early | Median of promised date minus delivery date |
| Avg days promised | Average days from purchase to promised date |
| Avg delivery days | Average days from purchase to delivery |
| Avg review | Average review score (orders with a review only) |
| Avg review (late) | Average review for late orders |
| Avg review (on time) | Average review for orders that were not late |
| Low review share (1-2 stars) | Share of reviewed orders with 1 or 2 stars |
| Seller shipped late share | Share of orders the seller handed to the carrier after the ship-by limit |
| Avg promise padding (days) | Average days early (how much earlier than promised orders arrive) |
| Avg review (0-6 days early) | Average review for orders 0-6 days early |
| Avg review (7+ days early) | Average review for orders 7 or more days early |
| Review gain from 7+ days early | The difference between the two measures above |

## Colours

Navy is the main colour and terracotta marks late or bad results, with sand, sage and grey as extra colours. The page background is a warm off-white with white cards. The theme is in `DeliveryGap.Report/StaticResources/RegisteredResources/DeliveryGapTheme.json`.
