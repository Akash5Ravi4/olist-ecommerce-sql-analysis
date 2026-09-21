# Olist E-Commerce SQL Analysis

A PostgreSQL portfolio project analyzing the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100,000 real orders placed between 2016 and 2018, spread across 9 relational tables (customers, orders, order items, payments, reviews, products, sellers, geolocation, and category translations).

This project covers the full pipeline: schema design, data loading and cleaning, and business-question SQL analysis ranging from basic aggregation to window functions, CTEs, and query performance tuning.

## Schema

See [`ER_DIAGRAM.md`](./ER_DIAGRAM.md) for the full entity-relationship diagram, or [`er_diagram.png`](./er_diagram.png) for a colored image version.

The schema uses composite primary keys where the data's real grain requires it (`order_items`, `order_payments`), and deliberately leaves `geolocation` as an unconstrained lookup table due to inconsistent zip-to-coordinate mappings in the raw data.

## Data quality issues solved

Loading this dataset surfaced several real-world data quality problems, each resolved directly in SQL rather than by relaxing constraints:

- **Missing category translations** — two product categories (`pc_gamer`, `portateis_cozinha_e_preparadores_de_alimentos`) existed in the products data but were missing from the category translation file, causing foreign key violations on import. Fixed with manual `INSERT`s into the translation table.
- **Duplicate review IDs** — a small number of reviews in the raw CSV shared the same `review_id` with differing content. Fixed by loading into a staging table, then using `DISTINCT ON (review_id)` to keep only the most recently-answered version of each duplicate before inserting into the constrained production table.
- **Geolocation import inconsistency** — an initial import silently reported success with zero rows loaded; resolved by re-running the import and verifying with an explicit row count rather than trusting the tool's status message.

## Analysis queries

All queries live in [`sql/02_analysis_queries.sql`](./sql/02_analysis_queries.sql), built up from basic aggregation to advanced techniques:

**Aggregation & joins**
1. Monthly revenue trend
2. Top product categories by revenue
3. Delivery time vs. review score
4. Payment method breakdown
5. Revenue and orders by state
6. Seller performance (revenue, volume, late-shipment rate)
7. Category-level review scores (controlling for delivery delay)

**Window functions & advanced SQL**
8. Month-on-month revenue growth (`LAG()`)
9. Customer ranking by lifetime spend (`RANK()`)
10. Cohort retention analysis (chained CTEs, tracking repeat-purchase behavior by first-purchase month)
11. Query performance tuning — identifying a non-sargable predicate with `EXPLAIN ANALYZE` and rewriting it to use an index

## Key insights

- **Delivery speed is strongly tied to satisfaction.** Orders that received 5-star reviews were delivered an average of **12.4 days earlier** than their estimated delivery date, compared to just **3.4 days early** for 1-star reviews — a gap of roughly 9 days between the best and worst-rated experiences.
- **Credit card dominates payments.** Credit card was used in 76,795 payments (the large majority), generating **$12.54M** in total value — over 4x the next most common method (boleto, a Brazilian bank slip, at $2.87M) — with an average of **3.5 installments** per payment, reflecting Brazil's common installment-based purchasing habits.
- **Revenue is heavily concentrated in São Paulo.** SP alone accounts for 41,125 orders and **$5.88M** in revenue — more than double Rio de Janeiro, the next-highest state ($2.12M) — while smaller/remote states show notably higher average order values, suggesting fewer but larger purchases outside the main urban hubs.

## Tech stack

- PostgreSQL 18
- pgAdmin 4

## Files

```
├── README.md
├── ER_DIAGRAM.md
├── er_diagram.png
└── sql/
    ├── 01_create_schema.sql
    └── 02_analysis_queries.sql
```
