# SQL

All the SQL for the project, written for PostgreSQL. Run the files in order from the project folder.

| File | What it does |
|---|---|
| `01_create_tables.sql` | Creates the 9 tables with primary and foreign keys. |
| `02_load_data.sql` | Loads the Kaggle CSV files from `data/raw` with `\copy`, adds two missing category names and prints row counts. |
| `03_views.sql` | Builds `order_delivery`, one clean row per delivered order (96,470 rows), plus a helper view with one point per zip prefix. |
| `04_analysis_queries.sql` | 20 queries that answer the business question. Each one has a comment with the result I got. |

## How to run

You need a database called `olist` and a user that can create tables in it. Then:

```
psql -h localhost -U analyst -d olist -f sql/01_create_tables.sql
psql -h localhost -U analyst -d olist -f sql/02_load_data.sql
psql -h localhost -U analyst -d olist -f sql/03_views.sql
psql -h localhost -U analyst -d olist -f sql/04_analysis_queries.sql
```

`02_load_data.sql` uses relative paths, so run it from the project folder. The data has to be downloaded first (see `data/README.md`).

## The queries

| # | Question |
|---|---|
| Q1 | Order status counts, and why only delivered orders are used |
| Q2 | Orphan rows and gaps across the tables |
| Q3 | Nulls and odd dates in delivered orders |
| Q4 | Duplicates: reviews per order, people with several customer ids, geolocation rows |
| Q5 | Headline late rate, median and 90th percentile delivery days |
| Q6 | Late rate by month (2017-01 to 2018-08) with month-over-month change and a 3-month average |
| Q7 | Average review and 1-2 star share by delivery group |
| Q8 | Average review at selected numbers of days early or late |
| Q9 | Late rate by customer state, ranked (base tables) |
| Q10 | Late rate by seller state, with share of orders and share of late orders |
| Q11 | Same-state versus cross-state orders |
| Q12 | Late rate by distance band (five equal bands with NTILE) |
| Q13 | Late rate when the seller hands over late versus on time |
| Q14 | Worst sellers by late rate, 50+ orders (base tables) |
| Q15 | How concentrated late orders are among sellers |
| Q16 | Categories by late rate |
| Q17 | Repeat buying after a late first order |
| Q18 | Median promised versus actual delivery days by customer state |
| Q19 | Share of orders that arrive 7+, 14+ and 21+ days early |
| Q20 | What-if: the late rate if every promise were 0, 3, 5, 7 or 10 days shorter |
