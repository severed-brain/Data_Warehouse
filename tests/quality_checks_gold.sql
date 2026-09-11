/*
===============================================================================
Quality Assurance Checks: Gold Layer (Star Schema Validation)
===============================================================================
Script Purpose:
    This script tests the integrity of the Gold layer dimensional models (Star Schema).
    It ensures that all dimension surrogate keys are unique, referential integrity
    holds between facts and dimensions (no orphan records), and metric constraints 
    are satisfied.

Checks Performed:
    1. Dimension Surrogate Key Uniqueness (dim_customers, dim_products)
    2. Dimension Natural Key Uniqueness
    3. Referential Integrity (Foreign Keys in fact_sales pointing to dimensions)
    4. Orphan Fact Analysis (Fact records without corresponding dimension members)
    5. Metric Validity (Positive values for sales, quantity, unit price)
    6. Completeness of Required Attributes

Usage:
    Run this script after creating the views with `ddl_gold.sql`.
    Any non-empty result sets indicate dimensional modeling defects.
===============================================================================
*/

USE DataWarehouse;
GO

PRINT '===============================================================================';
PRINT 'Starting Data Quality Checks: Gold Layer (Star Schema)';
PRINT '===============================================================================';

-- =============================================================================
-- Check 1: Surrogate Key Uniqueness & Non-null in gold.dim_customers
-- Expectation: 0 rows returned
-- =============================================================================
PRINT '>> Testing: Surrogate Key Uniqueness in gold.dim_customers...';

SELECT 
    customer_key, 
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING customer_key IS NULL OR COUNT(*) > 1;

-- =============================================================================
-- Check 2: Natural Key Uniqueness in gold.dim_customers
-- Expectation: 0 rows returned
-- =============================================================================
PRINT '>> Testing: Natural Key (customer_id) Uniqueness in gold.dim_customers...';

SELECT 
    customer_id, 
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- =============================================================================
-- Check 3: Surrogate Key Uniqueness & Non-null in gold.dim_products
-- Expectation: 0 rows returned
-- =============================================================================
PRINT '>> Testing: Surrogate Key Uniqueness in gold.dim_products...';

SELECT 
    product_key, 
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING product_key IS NULL OR COUNT(*) > 1;

-- =============================================================================
-- Check 4: Referential Integrity: fact_sales -> dim_customers
-- Expectation: 0 rows returned (Every sale must map to a valid customer surrogate key)
-- =============================================================================
PRINT '>> Testing: Referential Integrity (fact_sales to dim_customers)...';

SELECT 
    fs.order_number,
    fs.customer_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_customers dc
    ON fs.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL;

-- =============================================================================
-- Check 5: Referential Integrity: fact_sales -> dim_products
-- Expectation: 0 rows returned (Every sale must map to a valid product surrogate key)
-- =============================================================================
PRINT '>> Testing: Referential Integrity (fact_sales to dim_products)...';

SELECT 
    fs.order_number,
    fs.product_key
FROM gold.fact_sales fs
LEFT JOIN gold.dim_products dp
    ON fs.product_key = dp.product_key
WHERE dp.product_key IS NULL;

-- =============================================================================
-- Check 6: Fact Metric Validity (Sales, Quantity, Price)
-- Expectation: 0 rows returned (All values must be strictly positive)
-- =============================================================================
PRINT '>> Testing: Fact Metrics positivity and non-nullability...';

SELECT 
    order_number,
    sales_amount,
    quantity,
    price
FROM gold.fact_sales
WHERE sales_amount IS NULL OR sales_amount <= 0
   OR quantity IS NULL OR quantity <= 0
   OR price IS NULL OR price <= 0;

-- =============================================================================
-- Check 7: Dimensional Consistency & Missing Category Mapping
-- Expectation: 0 rows returned (Products should have category populated)
-- =============================================================================
PRINT '>> Testing: Category enrichment completeness in gold.dim_products...';

SELECT 
    product_key,
    product_name,
    category
FROM gold.dim_products
WHERE category IS NULL OR category = '';

PRINT '===============================================================================';
PRINT 'Completed Data Quality Checks: Gold Layer';
PRINT '===============================================================================';
GO
