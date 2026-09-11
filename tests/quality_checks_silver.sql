/*
===============================================================================
Quality Assurance Checks: Silver Layer
===============================================================================
Script Purpose:
    This script performs automated data quality validation on the 'silver' schema 
    tables to ensure that data cleansing, standardization, and deduplication 
    rules executed during the ETL pipeline were successful.

Checks Performed:
    1. Nullability & Uniqueness of Primary Keys
    2. String Trimming & Formatting (Whitespace checks)
    3. Categorical Standardization (Gender, Marital Status, Country)
    4. Numeric Range & Metric Consistency (Sales = Quantity * Price)
    5. Date Consistency & Logical Boundaries (Birthdates in the past, valid order dates)
    6. System ID / Cross-source Key Cleansing (No residual 'NAS' or dashes)

Usage:
    Run this script after executing `EXEC silver.load_silver;`.
    Any non-empty result set indicates a data quality issue requiring investigation.
===============================================================================
*/

USE DataWarehouse;
GO

PRINT '===============================================================================';
PRINT 'Starting Data Quality Checks: Silver Layer';
PRINT '===============================================================================';

-- =============================================================================
-- Check 1: Primary Key Uniqueness & Nullability in silver.crm_cust_info
-- Expectation: 0 rows returned (No NULLs or duplicate customer IDs)
-- =============================================================================
PRINT '>> Testing: Uniqueness & Non-null cst_id in silver.crm_cust_info...';

SELECT 
    cst_id, 
    COUNT(*) AS record_count
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING cst_id IS NULL OR COUNT(*) > 1;

-- =============================================================================
-- Check 2: Unwanted Whitespace in Customer Names
-- Expectation: 0 rows returned (No leading/trailing spaces)
-- =============================================================================
PRINT '>> Testing: Whitespace hygiene in customer names...';

SELECT 
    cst_id,
    cst_firstname,
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
   OR cst_lastname != TRIM(cst_lastname);

-- =============================================================================
-- Check 3: Standardized Marital Status & Gender Values
-- Expectation: Only 'Single', 'Married', 'n/a' for Marital Status
--              Only 'Female', 'Male', 'n/a' for Gender
-- =============================================================================
PRINT '>> Testing: Categorical domain compliance (gender, marital status)...';

SELECT DISTINCT 
    cst_marital_status, 
    cst_gndr
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Single', 'Married', 'n/a')
   OR cst_gndr NOT IN ('Female', 'Male', 'n/a');

-- =============================================================================
-- Check 4: Product SCD / Start and End Date Integrity
-- Expectation: 0 rows returned (prd_end_dt must be greater than or equal to prd_start_dt)
-- =============================================================================
PRINT '>> Testing: Product start and end date logic in silver.crm_prd_info...';

SELECT 
    prd_id,
    prd_key,
    prd_start_dt,
    prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt IS NOT NULL AND prd_end_dt < prd_start_dt;

-- =============================================================================
-- Check 5: Negative or Zero Unit Costs in Products
-- Expectation: 0 rows returned (Costs should be non-negative)
-- =============================================================================
PRINT '>> Testing: Non-negative cost validation in silver.crm_prd_info...';

SELECT 
    prd_id,
    prd_key,
    prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0;

-- =============================================================================
-- Check 6: Sales Calculation Integrity in silver.crm_sales_details
-- Expectation: 0 rows returned (sls_sales = sls_quantity * ABS(sls_price))
-- =============================================================================
PRINT '>> Testing: Sales revenue calculation integrity...';

SELECT 
    sls_ord_num,
    sls_sales,
    sls_quantity,
    sls_price,
    (sls_quantity * ABS(sls_price)) AS expected_sales
FROM silver.crm_sales_details
WHERE sls_sales != (sls_quantity * ABS(sls_price))
   OR sls_sales <= 0
   OR sls_quantity <= 0;

-- =============================================================================
-- Check 7: Shipping & Due Date Logical Sequence
-- Expectation: 0 rows returned (ship_dt should be >= order_dt)
-- =============================================================================
PRINT '>> Testing: Order vs. Shipping date chronology...';

SELECT 
    sls_ord_num,
    sls_order_dt,
    sls_ship_dt
FROM silver.crm_sales_details
WHERE sls_ship_dt < sls_order_dt;

-- =============================================================================
-- Check 8: ERP Customer ID Prefix Cleansing
-- Expectation: 0 rows returned (No 'NAS' prefix should remain in cid)
-- =============================================================================
PRINT '>> Testing: ERP Customer ID format standardization...';

SELECT 
    cid
FROM silver.erp_cust_az12
WHERE cid LIKE 'NAS%';

-- =============================================================================
-- Check 9: ERP Customer Birthdate Bounds
-- Expectation: 0 rows returned (Birthdates must not be in the future or unreasonably old)
-- =============================================================================
PRINT '>> Testing: Customer birthdate plausibility...';

SELECT 
    cid,
    bdate
FROM silver.erp_cust_az12
WHERE bdate > GETDATE()
   OR bdate < '1900-01-01';

-- =============================================================================
-- Check 10: ERP Location CID Hyphen Cleansing & Country Standardization
-- Expectation: 0 rows returned (No hyphens in cid, no un-mapped raw codes like 'DE')
-- =============================================================================
PRINT '>> Testing: ERP location format and country normalization...';

SELECT 
    cid,
    cntry
FROM silver.erp_loc_a101
WHERE cid LIKE '%-%'
   OR cntry IN ('DE', 'US', 'USA');

PRINT '===============================================================================';
PRINT 'Completed Data Quality Checks: Silver Layer';
PRINT '===============================================================================';
GO
