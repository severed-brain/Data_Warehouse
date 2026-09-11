# Modern SQL Data Warehouse — Medallion Architecture

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2019%20%2F%202022-CC292B?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/en-us/sql-server)
[![T-SQL](https://img.shields.io/badge/Language-T--SQL-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)](https://docs.microsoft.com/en-us/sql/t-sql/)
[![Architecture](https://img.shields.io/badge/Architecture-Medallion%20(Bronze%2FSilver%2FGold)-00C7B7?style=for-the-badge)](https://learn.microsoft.com/en-us/azure/databricks/lakehouse/medallion)
[![Data Modeling](https://img.shields.io/badge/Modeling-Kimball%20Star%20Schema-F25022?style=for-the-badge)](https://en.wikipedia.org/wiki/Star_schema)
[![Analytics](https://img.shields.io/badge/Serving-Power%20BI%20%7C%20Tableau%20%7C%20ML-7FBA00?style=for-the-badge)](https://powerbi.microsoft.com/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

---

## Overview

**Engineered an end-to-end SQL data warehouse via Medallion Architecture to clean, model, and serve curated data for analytics.**

- **Medallion Architecture:** Devised a modern SQL Data Warehouse using Medallion Architecture (Bronze-Silver-Gold) in SQL Server, structured across **5 ETL stages**.
- **Robust Pipelines:** Implemented Extract-Transform-Load pipelines in SQL Server Express, processing ERP and CRM data (CSV) developing **10+ SQL Modules**.
- **Star Schema Modeling:** Modeled star schema in the Gold Layer to enable fast SQL queries and seamless integration with **Power BI**, **Tableau**, and **Machine Learning** applications.
- **Data Quality:** Automated data testing suites asserting surrogate key uniqueness, referential integrity, and domain constraints.

---

## Clone Repository

```bash
git clone https://github.com/severed-brain/Data_Warehouse.git
cd Data_Warehouse
```

---

## System Architecture

```mermaid
flowchart TD
    subgraph Sources["1. Source Systems"]
        CRM["CRM System (CSV Files)"]
        ERP["ERP System (CSV Files)"]
    end

    subgraph Bronze["2. Bronze Layer (Raw Staging)"]
        B1["bronze.crm_cust_info"]
        B2["bronze.crm_prd_info"]
        B3["bronze.crm_sales_details"]
        B4["bronze.erp_loc_a101"]
        B5["bronze.erp_cust_az12"]
        B6["bronze.erp_px_cat_g1v2"]
    end

    subgraph Silver["3. Silver Layer (Cleaned & Conformed)"]
        S1["silver.crm_cust_info"]
        S2["silver.crm_prd_info"]
        S3["silver.crm_sales_details"]
        S4["silver.erp_loc_a101"]
        S5["silver.erp_cust_az12"]
        S6["silver.erp_px_cat_g1v2"]
    end

    subgraph Gold["4. Gold Layer (Star Schema Analytics)"]
        D1[("gold.dim_customers")]
        D2[("gold.dim_products")]
        F1[("gold.fact_sales")]
    end

    subgraph Serving["5. Analytical Consumption"]
        PBI["Power BI Dashboards"]
        TAB["Tableau Visualizations"]
        ML["Machine Learning Models"]
        SQL["Ad-hoc SQL Queries"]
    end

    CRM -->|"BULK INSERT"| Bronze
    ERP -->|"BULK INSERT"| Bronze

    Bronze -->|"Cleansing & Deduplication"| Silver

    Silver -->|"Dimensional Modeling"| Gold

    Gold --> Serving
```

---

## Star Schema Data Model

The Gold Layer is structured as an analytical **Star Schema** with conformed dimensions and surrogate keys:

```mermaid
erDiagram
    dim_customers ||--o{ fact_sales : places
    dim_products ||--o{ fact_sales : includes

    dim_customers {
        bigint customer_key PK
        int customer_id
        string customer_number
        string first_name
        string last_name
        string country
        string marital_status
        string gender
        date birthdate
        date create_date
    }

    dim_products {
        bigint product_key PK
        int product_id
        string product_number
        string product_name
        string category_id
        string category
        string subcategory
        string maintenance
        int cost
        string product_line
        date start_date
    }

    fact_sales {
        string order_number
        bigint product_key FK
        bigint customer_key FK
        date order_date
        date shipping_date
        date due_date
        int sales_amount
        int quantity
        int price
    }
```

---

## 5 ETL Pipeline Stages

| Stage | Stage Name | Scripts | Purpose |
| :---: | :--- | :--- | :--- |
| **1** | **Database & Schemas** | [`init_database.sql`](scripts/init_database.sql) | Initializes the `DataWarehouse` database with isolated `bronze`, `silver`, and `gold` schemas. |
| **2** | **Bronze Ingestion** | [`ddl_bronze.sql`](scripts/bronze/ddl_bronze.sql)<br/>[`proc_load_bronze.sql`](scripts/bronze/proc_load_bronze.sql) | DDL definition and dynamic `BULK INSERT` loading of 6 raw CRM and ERP CSV datasets with execution logging. |
| **3** | **Silver Cleansing** | [`ddl_silver.sql`](scripts/silver/ddl_silver.sql)<br/>[`proc_load_silver.sql`](scripts/silver/proc_load_silver.sql) | Deduplication, SCD end-date computation, data type casting, and heterogeneous key standardization. |
| **4** | **Gold Star Schema** | [`ddl_gold.sql`](scripts/gold/ddl_gold.sql) | Star schema dimensional views with surrogate key generation and active record filtering. |
| **5** | **Quality & Analytics** | [`quality_checks_*.sql`](tests/)<br/>[`analytics_queries.sql`](scripts/gold/analytics_queries.sql) | Automated data testing assertions and business intelligence SQL queries for reporting. |

---

## Engineering Highlights

### 1. Customer Deduplication with Window Functions
Selects the most recent customer record using creation timestamps:
```sql
SELECT cst_id, cst_key, TRIM(cst_firstname) AS cst_firstname, TRIM(cst_lastname) AS cst_lastname,
       CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
            WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
            ELSE 'n/a' END AS cst_marital_status,
       cst_create_date
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1;
```

### 2. SCD Product Version Validity Dates
Computes product lifecycle end dates dynamically using `LEAD()`:
```sql
CAST(
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 
    AS DATE
) AS prd_end_dt
```

### 3. Defensive Arithmetic & Anomaly Correction
Recalculates missing, zero, or negative sales metrics:
```sql
CASE 
    WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) 
        THEN sls_quantity * ABS(sls_price)
    ELSE sls_sales
END AS sls_sales
```

### 4. Cross-System Key Standardization
Harmonizes heterogeneous ERP and CRM codes:
- Strips legacy `'NAS'` prefixes: `SUBSTRING(cid, 4, LEN(cid))`
- Normalizes hyphenated IDs: `REPLACE(cid, '-', '')`
- Maps country codes (`'DE'` &rarr; `'Germany'`, `'US'/'USA'` &rarr; `'United States'`)

---

## Project Structure

```text
├── datasets/                                 # Sample CSV datasets
│   ├── source_crm/                           # Customer, product, and sales data
│   │   ├── cust_info.csv
│   │   ├── prd_info.csv
│   │   └── sales_details.csv
│   └── source_erp/                           # Demographics, locations, and categories
│       ├── cust_az12.csv
│       ├── loc_a101.csv
│       └── px_cat_g1v2.csv
├── docs/                                     # Technical documentation
│   ├── architecture.md                       # Medallion Architecture design doc
│   ├── data_catalog.md                       # Enterprise data dictionary
│   └── etl_pipeline.md                       # Pipeline execution runbook
├── scripts/                                  # SQL modules & stored procedures
│   ├── init_database.sql                     # Database & schema creation
│   ├── bronze/                               # Bronze staging scripts
│   │   ├── ddl_bronze.sql
│   │   └── proc_load_bronze.sql
│   ├── silver/                               # Silver transformation scripts
│   │   ├── ddl_silver.sql
│   │   └── proc_load_silver.sql
│   └── gold/                                 # Gold star schema & analytics
│       ├── ddl_gold.sql
│       └── analytics_queries.sql
├── tests/                                    # Automated Data Quality suites
│   ├── quality_checks_silver.sql             # Silver layer validation checks
│   └── quality_checks_gold.sql               # Gold star schema integrity checks
├── LICENSE                                   # MIT License
└── README.md                                 # Documentation
```

---

## Quickstart Guide

### Execute Pipeline in SQL Server
Run scripts sequentially in SSMS, Azure Data Studio, or `sqlcmd`:

```sql
-- 1. Database & Schema Initialization
:r scripts/init_database.sql

-- 2. Bronze DDL & Ingestion
USE DataWarehouse;
GO
:r scripts/bronze/ddl_bronze.sql
:r scripts/bronze/proc_load_bronze.sql
EXEC bronze.load_bronze;

-- 3. Silver DDL & Transformation
:r scripts/silver/ddl_silver.sql
:r scripts/silver/proc_load_silver.sql
EXEC silver.load_silver;

-- 4. Gold Star Schema Views
:r scripts/gold/ddl_gold.sql

-- 5. Data Quality Validation
:r tests/quality_checks_silver.sql
:r tests/quality_checks_gold.sql
```

---

## Sample Analytical Queries

### Month-over-Month (MoM) Revenue Growth
```sql
WITH MonthlySales AS (
    SELECT
        YEAR(fs.order_date) AS sales_year,
        MONTH(fs.order_date) AS sales_month,
        SUM(fs.sales_amount) AS monthly_revenue
    FROM gold.fact_sales fs
    WHERE fs.order_date IS NOT NULL
    GROUP BY YEAR(fs.order_date), MONTH(fs.order_date)
)
SELECT
    sales_year,
    sales_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY sales_year, sales_month) AS prev_month_revenue,
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY sales_year, sales_month)) * 100.0 /
        NULLIF(LAG(monthly_revenue) OVER (ORDER BY sales_year, sales_month), 0),
        2
    ) AS mom_growth_pct
FROM MonthlySales
ORDER BY sales_year, sales_month;
```

### Product Category Profitability
```sql
SELECT
    dp.category,
    dp.subcategory,
    SUM(fs.sales_amount) AS total_revenue,
    SUM(dp.cost * fs.quantity) AS total_cost,
    SUM(fs.sales_amount) - SUM(dp.cost * fs.quantity) AS gross_profit,
    ROUND(
        (SUM(fs.sales_amount) - SUM(dp.cost * fs.quantity)) * 100.0 / NULLIF(SUM(fs.sales_amount), 0), 
        2
    ) AS profit_margin_pct,
    DENSE_RANK() OVER (ORDER BY SUM(fs.sales_amount) DESC) AS revenue_rank
FROM gold.fact_sales fs
JOIN gold.dim_products dp ON fs.product_key = dp.product_key
GROUP BY dp.category, dp.subcategory
ORDER BY total_revenue DESC;
```

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.