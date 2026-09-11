/*
===============================================================================
Analytical & Business Intelligence Queries: Gold Layer
===============================================================================
Script Purpose:
    This script contains production-grade SQL analytical queries demonstrating 
    how the Star Schema in the Gold Layer powers downstream analytics, BI 
    reporting (Power BI, Tableau), and machine learning feature extraction.

Query Modules:
    1. Executive KPI Summary (Revenue, Orders, AOV, Volume)
    2. Category & Product Line Performance (Revenue, Profit Margin, Ranking)
    3. Customer Segmentation & Lifetime Value (LTV / RFM Foundation)
    4. Month-over-Month (MoM) Revenue Growth & Trend Analysis
    5. Regional & Demographic Market Share (Country & Gender Insights)
    6. Customer Cohort & Repeat Purchase Behavior
    7. Underperforming Products & Inventory Velocity
===============================================================================
*/

USE DataWarehouse;
GO

-- =============================================================================
-- 1. Executive KPI Summary
-- High-level metrics for executive dashboards
-- =============================================================================
SELECT
    COUNT(DISTINCT fs.order_number)           AS total_orders,
    COUNT(DISTINCT fs.customer_key)           AS total_active_customers,
    SUM(fs.quantity)                          AS total_units_sold,
    SUM(fs.sales_amount)                      AS total_revenue,
    AVG(fs.sales_amount)                      AS average_order_line_value,
    SUM(fs.sales_amount) / NULLIF(COUNT(DISTINCT fs.order_number), 0) AS average_order_value
FROM gold.fact_sales fs;

-- =============================================================================
-- 2. Category & Product Performance Analysis
-- Identifies top revenue drivers, unit volume, and product margin
-- =============================================================================
SELECT
    dp.category,
    dp.subcategory,
    dp.product_name,
    COUNT(fs.order_number)                    AS order_count,
    SUM(fs.quantity)                          AS units_sold,
    SUM(fs.sales_amount)                      AS total_revenue,
    SUM(dp.cost * fs.quantity)                AS total_cost,
    SUM(fs.sales_amount) - SUM(dp.cost * fs.quantity) AS estimated_gross_profit,
    ROUND(
        (SUM(fs.sales_amount) - SUM(dp.cost * fs.quantity)) * 100.0 / NULLIF(SUM(fs.sales_amount), 0),
        2
    )                                         AS gross_profit_margin_pct,
    DENSE_RANK() OVER (
        PARTITION BY dp.category 
        ORDER BY SUM(fs.sales_amount) DESC
    )                                         AS category_rank
FROM gold.fact_sales fs
INNER JOIN gold.dim_products dp
    ON fs.product_key = dp.product_key
GROUP BY 
    dp.category,
    dp.subcategory,
    dp.product_name
ORDER BY 
    dp.category, 
    total_revenue DESC;

-- =============================================================================
-- 3. Customer Lifetime Value (LTV) & Top Customer Ranking
-- Identifies high-value accounts for CRM targeting and loyalty programs
-- =============================================================================
SELECT TOP 10
    dc.customer_key,
    dc.first_name + ' ' + dc.last_name        AS customer_name,
    dc.country,
    dc.gender,
    dc.marital_status,
    COUNT(DISTINCT fs.order_number)           AS total_orders,
    SUM(fs.sales_amount)                      AS lifetime_spend,
    MIN(fs.order_date)                        AS first_purchase_date,
    MAX(fs.order_date)                        AS most_recent_purchase_date,
    DATEDIFF(day, MIN(fs.order_date), MAX(fs.order_date)) AS customer_lifespan_days
FROM gold.fact_sales fs
INNER JOIN gold.dim_customers dc
    ON fs.customer_key = dc.customer_key
GROUP BY 
    dc.customer_key,
    dc.first_name,
    dc.last_name,
    dc.country,
    dc.gender,
    dc.marital_status
ORDER BY 
    lifetime_spend DESC;

-- =============================================================================
-- 4. Month-over-Month (MoM) Revenue Growth & Trend Analysis
-- Calculates monthly velocity and percentage growth using LAG() window function
-- =============================================================================
WITH MonthlySales AS (
    SELECT
        YEAR(fs.order_date)                   AS sales_year,
        MONTH(fs.order_date)                  AS sales_month,
        SUM(fs.sales_amount)                  AS current_month_revenue,
        COUNT(DISTINCT fs.order_number)       AS total_orders
    FROM gold.fact_sales fs
    WHERE fs.order_date IS NOT NULL
    GROUP BY 
        YEAR(fs.order_date),
        MONTH(fs.order_date)
)
SELECT
    sales_year,
    sales_month,
    current_month_revenue,
    LAG(current_month_revenue, 1) OVER (
        ORDER BY sales_year, sales_month
    )                                         AS previous_month_revenue,
    current_month_revenue - LAG(current_month_revenue, 1) OVER (
        ORDER BY sales_year, sales_month
    )                                         AS mom_revenue_change,
    ROUND(
        (current_month_revenue - LAG(current_month_revenue, 1) OVER (ORDER BY sales_year, sales_month)) * 100.0 /
        NULLIF(LAG(current_month_revenue, 1) OVER (ORDER BY sales_year, sales_month), 0),
        2
    )                                         AS mom_growth_pct,
    total_orders
FROM MonthlySales
ORDER BY 
    sales_year, 
    sales_month;

-- =============================================================================
-- 5. Regional & Demographic Market Share
-- Analyzes sales distribution by geography and customer demographics
-- =============================================================================
SELECT
    ISNULL(dc.country, 'Unknown')             AS market_region,
    ISNULL(dc.gender, 'n/a')                  AS customer_gender,
    COUNT(DISTINCT dc.customer_key)           AS customer_count,
    COUNT(DISTINCT fs.order_number)           AS orders_placed,
    SUM(fs.sales_amount)                      AS total_sales,
    ROUND(
        SUM(fs.sales_amount) * 100.0 / SUM(SUM(fs.sales_amount)) OVER(),
        2
    )                                         AS global_sales_share_pct
FROM gold.fact_sales fs
INNER JOIN gold.dim_customers dc
    ON fs.customer_key = dc.customer_key
GROUP BY 
    dc.country,
    dc.gender
ORDER BY 
    total_sales DESC;

-- =============================================================================
-- 6. Customer Repeat Purchase Behavior
-- Determines customer retention and repeat purchase rate
-- =============================================================================
WITH CustomerOrderFrequency AS (
    SELECT
        dc.customer_key,
        COUNT(DISTINCT fs.order_number)       AS order_count
    FROM gold.dim_customers dc
    LEFT JOIN gold.fact_sales fs
        ON dc.customer_key = fs.customer_key
    GROUP BY dc.customer_key
)
SELECT
    CASE 
        WHEN order_count = 0 THEN '0 Orders (No Purchase)'
        WHEN order_count = 1 THEN '1 Order (One-Time Buyer)'
        WHEN order_count = 2 THEN '2 Orders (Repeat Buyer)'
        ELSE '3+ Orders (Loyal Customer)'
    END                                       AS customer_segment,
    COUNT(*)                                  AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage_of_base
FROM CustomerOrderFrequency
GROUP BY 
    CASE 
        WHEN order_count = 0 THEN '0 Orders (No Purchase)'
        WHEN order_count = 1 THEN '1 Order (One-Time Buyer)'
        WHEN order_count = 2 THEN '2 Orders (Repeat Buyer)'
        ELSE '3+ Orders (Loyal Customer)'
    END
ORDER BY 
    customer_count DESC;
