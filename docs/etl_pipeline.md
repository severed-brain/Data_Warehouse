# End-to-End ETL Pipeline Execution Guide

This guide provides end-to-end execution instructions for deploying and running the ETL pipeline across the **Bronze**, **Silver**, and **Gold** layers in Microsoft SQL Server.

---

## Pipeline Execution Overview

The data warehouse workflow consists of 5 modular execution steps:

```text
[1. init_database.sql] ──> [2. ddl_bronze.sql] ──> [3. proc_load_bronze]
                                                          │
[5. ddl_gold.sql]      <── [4. proc_load_silver] <────────┘
        │
        ▼
[Analytics & Quality Tests]
```

---

## Step-by-Step Execution

### Step 1: Environment & Database Provisioning
Run `scripts/init_database.sql` to initialize the target database and create the isolated schemas:
```sql
-- Connect to Master and run:
:r scripts/init_database.sql
```
This script creates:
- Database: `DataWarehouse`
- Schemas: `bronze`, `silver`, `gold`

---

### Step 2: Provision Bronze DDL & Ingest Source Data
1. Deploy the Bronze staging table schemas:
```sql
USE DataWarehouse;
GO
:r scripts/bronze/ddl_bronze.sql
```
2. Compile and execute the Bronze loading stored procedure:
```sql
USE DataWarehouse;
GO
:r scripts/bronze/proc_load_bronze.sql

-- Run the ETL ingestion (specify custom path if datasets are outside default directory):
EXEC bronze.load_bronze @data_path = 'C:\Data Warehouse\SQL-Data-Warehouse\datasets';
```

**Expected Output:**
```text
================================================
Loading Bronze Layer
Source Directory: C:\Data Warehouse\SQL-Data-Warehouse\datasets
================================================
------------------------------------------------
Loading CRM Tables
------------------------------------------------
>> Truncating Table: bronze.crm_cust_info
>> Inserting Data Into: bronze.crm_cust_info
>> Load Duration: 0 seconds
...
================================================
Loading Bronze Layer is Completed
   - Total Load Duration: 0 seconds
================================================
```

---

### Step 3: Provision Silver DDL & Execute Cleansing Pipeline
1. Deploy the Silver tables:
```sql
USE DataWarehouse;
GO
:r scripts/silver/ddl_silver.sql
```
2. Compile and execute the Silver transformation procedure:
```sql
USE DataWarehouse;
GO
:r scripts/silver/proc_load_silver.sql

-- Execute transformation & data cleansing:
EXEC silver.load_silver;
```

**Actions Performed During Load:**
- CRM Customer deduplication via `ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)`
- Whitespace stripping and category normalization
- Anomaly correction for negative sales and missing unit prices
- Legacy ERP prefix stripping and country normalization
- SCD date derivation for product catalog changes

---

### Step 4: Provision Gold Layer Star Schema
Deploy the analytical views in the Gold schema:
```sql
USE DataWarehouse;
GO
:r scripts/gold/ddl_gold.sql
```
This creates:
- `gold.dim_customers`: Enriched customer dimension with surrogate key `customer_key`
- `gold.dim_products`: Filtered active products with surrogate key `product_key`
- `gold.fact_sales`: Transactional fact table referencing dimension surrogate keys

---

### Step 5: Data Quality Verification & Analytical Serving

1. **Run Silver Data Quality Suite**:
```sql
:r tests/quality_checks_silver.sql
```
Verify that all 10 checks return **0 rows**, confirming schema hygiene, no lingering whitespace, and validated sales math.

2. **Run Gold Dimensional Integrity Suite**:
```sql
:r tests/quality_checks_gold.sql
```
Verify that surrogate key uniqueness and referential integrity (zero orphan fact records) hold true.

3. **Run Business Intelligence Queries**:
```sql
:r scripts/gold/analytics_queries.sql
```
Produces executive KPIs, product ranking, customer LTV, and monthly growth trends.
