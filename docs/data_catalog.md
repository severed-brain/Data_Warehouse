# Enterprise Data Catalog & Dictionary

This data catalog provides a comprehensive inventory of all data objects, entities, and attributes modeled within the **DataWarehouse** database across the **Bronze**, **Silver**, and **Gold** schemas.

---

## Source Systems Overview

| Source System | File Name | Format | Primary Domain | Business Keys |
| :--- | :--- | :--- | :--- | :--- |
| **CRM** | `cust_info.csv` | CSV | Customer master data | `cst_id`, `cst_key` |
| **CRM** | `prd_info.csv` | CSV | Product catalog & lifecycle | `prd_id`, `prd_key` |
| **CRM** | `sales_details.csv` | CSV | Transactional sales orders | `sls_ord_num`, `sls_prd_key`, `sls_cust_id` |
| **ERP** | `cust_az12.csv` | CSV | Demographics & birthdates | `cid` |
| **ERP** | `loc_a101.csv` | CSV | Geographic customer locations | `cid` |
| **ERP** | `px_cat_g1v2.csv` | CSV | Product category hierarchies | `id` |

---

## 1. Bronze Schema (Raw Staging)

Raw data landing tables populated via `BULK INSERT` from source CSV files.

### `bronze.crm_cust_info`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `cst_id` | `INT` | Yes | Customer ID from source CRM. |
| `cst_key` | `NVARCHAR(50)` | Yes | Alpha-numeric customer business key (e.g., 'C1001'). |
| `cst_firstname` | `NVARCHAR(50)` | Yes | Customer first name (raw, un-trimmed). |
| `cst_lastname` | `NVARCHAR(50)` | Yes | Customer last name (raw, un-trimmed). |
| `cst_marital_status` | `NVARCHAR(50)` | Yes | Raw marital code ('M', 'S', etc.). |
| `cst_gndr` | `NVARCHAR(50)` | Yes | Raw gender code ('M', 'F', etc.). |
| `cst_create_date` | `DATE` | Yes | Account creation timestamp in CRM. |

### `bronze.crm_prd_info`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `prd_id` | `INT` | Yes | Product internal identifier. |
| `prd_key` | `NVARCHAR(50)` | Yes | Composite product key containing category and code (e.g., 'AC-HE-HLM-01'). |
| `prd_nm` | `NVARCHAR(50)` | Yes | Product catalog display name. |
| `prd_cost` | `INT` | Yes | Unit cost in USD. |
| `prd_line` | `NVARCHAR(50)` | Yes | Product line code ('M', 'R', 'S', 'T'). |
| `prd_start_dt` | `DATETIME` | Yes | Effective start date of product record. |
| `prd_end_dt` | `DATETIME` | Yes | Effective end date of product record. |

### `bronze.crm_sales_details`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `sls_ord_num` | `NVARCHAR(50)` | Yes | Sales order number. |
| `sls_prd_key` | `NVARCHAR(50)` | Yes | Product key associated with order line. |
| `sls_cust_id` | `INT` | Yes | Customer ID placing order. |
| `sls_order_dt` | `INT` | Yes | Order date in integer format (`YYYYMMDD`). |
| `sls_ship_dt` | `INT` | Yes | Shipping date in integer format (`YYYYMMDD`). |
| `sls_due_dt` | `INT` | Yes | Due date in integer format (`YYYYMMDD`). |
| `sls_sales` | `INT` | Yes | Gross sales amount in USD. |
| `sls_quantity` | `INT` | Yes | Units ordered. |
| `sls_price` | `INT` | Yes | Unit price charged. |

### `bronze.erp_cust_az12`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `cid` | `NVARCHAR(50)` | Yes | Customer ID with optional legacy prefix ('NASC1001'). |
| `bdate` | `DATE` | Yes | Customer birthdate. |
| `gen` | `NVARCHAR(50)` | Yes | Raw demographic gender ('MALE', 'FEMALE', 'M', 'F'). |

### `bronze.erp_loc_a101`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `cid` | `NVARCHAR(50)` | Yes | Customer key formatted with hyphens (e.g., 'C-1001'). |
| `cntry` | `NVARCHAR(50)` | Yes | Country code or name ('US', 'USA', 'DE', etc.). |

### `bronze.erp_px_cat_g1v2`
| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `id` | `NVARCHAR(50)` | Yes | Normalized category identifier (e.g., 'AC_HE'). |
| `cat` | `NVARCHAR(50)` | Yes | Product high-level category (e.g., 'Accessories', 'Bikes'). |
| `subcat` | `NVARCHAR(50)` | Yes | Product subcategory (e.g., 'Helmets', 'Mountain Bikes'). |
| `maintenance` | `NVARCHAR(50)` | Yes | Maintenance eligibility flag ('Yes', 'No'). |

---

## 2. Silver Schema (Cleansed & Enriched)

Standardized, deduplicated tables with metadata lineage tracking.

### `silver.crm_cust_info`
- **Cleansing Rules**:
  - Deduplicated by `cst_id` retaining most recent `cst_create_date` via `ROW_NUMBER()`.
  - Whitespace trimmed from names (`TRIM()`).
  - Marital status mapped to `'Single'`, `'Married'`, or `'n/a'`.
  - Gender standardized to `'Female'`, `'Male'`, or `'n/a'`.

| Column | Data Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `cst_id` | `INT` | Business Key | Deduplicated customer ID. |
| `cst_key` | `NVARCHAR(50)` | - | Unique business key. |
| `cst_firstname` | `NVARCHAR(50)` | - | Cleaned first name. |
| `cst_lastname` | `NVARCHAR(50)` | - | Cleaned last name. |
| `cst_marital_status` | `NVARCHAR(50)` | - | Standardized marital status. |
| `cst_gndr` | `NVARCHAR(50)` | - | Standardized gender. |
| `cst_create_date` | `DATE` | - | Customer creation date. |
| `dwh_create_date` | `DATETIME2` | `DEFAULT GETDATE()` | Warehouse ingestion timestamp. |

### `silver.crm_prd_info`
- **Cleansing Rules**:
  - `cat_id` extracted from prefix: `REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_')`.
  - `prd_key` extracted from code: `SUBSTRING(prd_key, 7, LEN(prd_key))`.
  - `prd_line` mapped to `'Mountain'`, `'Road'`, `'Other Sales'`, `'Touring'`, or `'n/a'`.
  - `prd_end_dt` dynamically calculated via `LEAD(prd_start_dt) - 1`.

| Column | Data Type | Description |
| :--- | :--- | :--- |
| `prd_id` | `INT` | Product internal identifier. |
| `cat_id` | `NVARCHAR(50)` | Category foreign key matching ERP category master. |
| `prd_key` | `NVARCHAR(50)` | Conformed product business key. |
| `prd_nm` | `NVARCHAR(50)` | Product name. |
| `prd_cost` | `INT` | Unit cost (coalesced to 0 if null). |
| `prd_line` | `NVARCHAR(50)` | Product line classification. |
| `prd_start_dt` | `DATE` | Record start date. |
| `prd_end_dt` | `DATE` | Record end date (NULL for active product). |
| `dwh_create_date` | `DATETIME2` | Warehouse ingestion timestamp. |

### `silver.crm_sales_details`
- **Cleansing Rules**:
  - Date integers converted into valid SQL `DATE` objects (`YYYYMMDD` format).
  - Missing/negative sales amounts recalculated as `quantity * ABS(price)`.
  - Unit price derived if zero or null (`sales / quantity`).

| Column | Data Type | Description |
| :--- | :--- | :--- |
| `sls_ord_num` | `NVARCHAR(50)` | Sales order number. |
| `sls_prd_key` | `NVARCHAR(50)` | Foreign key matching conformed product key. |
| `sls_cust_id` | `INT` | Foreign key matching customer ID. |
| `sls_order_dt` | `DATE` | Standardized order date. |
| `sls_ship_dt` | `DATE` | Standardized shipping date. |
| `sls_due_dt` | `DATE` | Standardized due date. |
| `sls_sales` | `INT` | Validated gross sales revenue. |
| `sls_quantity` | `INT` | Quantity of items sold. |
| `sls_price` | `INT` | Validated unit selling price. |
| `dwh_create_date` | `DATETIME2` | Warehouse ingestion timestamp. |

---

## 3. Gold Schema (Star Schema Views)

Curated dimension and fact views optimized for analytical reporting and BI integration.

### `gold.dim_customers`
- **Integration**: Consolidates `silver.crm_cust_info`, `silver.erp_cust_az12` (birthdates, gender fallback), and `silver.erp_loc_a101` (geographic country).

| Column | Data Type | Key Role | Description |
| :--- | :--- | :--- | :--- |
| `customer_key` | `BIGINT` | **Surrogate Key (PK)** | Sequential unique identifier generated via `ROW_NUMBER()`. |
| `customer_id` | `INT` | Natural Key | Primary CRM customer ID. |
| `customer_number` | `NVARCHAR(50)` | Business Key | Alpha-numeric account reference (`cst_key`). |
| `first_name` | `NVARCHAR(50)` | - | Cleaned customer first name. |
| `last_name` | `NVARCHAR(50)` | - | Cleaned customer last name. |
| `country` | `NVARCHAR(50)` | - | Enriched geographic residence from ERP. |
| `marital_status` | `NVARCHAR(50)` | - | Standardized marital status ('Single', 'Married'). |
| `gender` | `NVARCHAR(50)` | - | Standardized gender ('Female', 'Male'). |
| `birthdate` | `DATE` | - | Validated date of birth. |
| `create_date` | `DATE` | - | Customer onboarding date. |

### `gold.dim_products`
- **Integration**: Enriches `silver.crm_prd_info` with category attributes from `silver.erp_px_cat_g1v2`. Filters to current active products (`WHERE prd_end_dt IS NULL`).

| Column | Data Type | Key Role | Description |
| :--- | :--- | :--- | :--- |
| `product_key` | `BIGINT` | **Surrogate Key (PK)** | Sequential unique identifier generated via `ROW_NUMBER()`. |
| `product_id` | `INT` | Natural Key | Operational product ID. |
| `product_number` | `NVARCHAR(50)` | Business Key | Business code (`prd_key`). |
| `product_name` | `NVARCHAR(50)` | - | Product descriptive name. |
| `category_id` | `NVARCHAR(50)` | - | High-level category key. |
| `category` | `NVARCHAR(50)` | - | Broad category ('Accessories', 'Bikes', etc.). |
| `subcategory` | `NVARCHAR(50)` | - | Granular subcategory ('Helmets', 'Road Bikes', etc.). |
| `maintenance` | `NVARCHAR(50)` | - | Service requirement indicator ('Yes', 'No'). |
| `cost` | `INT` | - | Standard unit cost. |
| `product_line` | `NVARCHAR(50)` | - | Product line ('Mountain', 'Road', 'Touring', 'Other Sales'). |
| `start_date` | `DATE` | - | Active version launch date. |

### `gold.fact_sales`
- **Integration**: Connects transactional sales rows from `silver.crm_sales_details` to dimensional surrogate keys (`customer_key`, `product_key`).

| Column | Data Type | Key Role | Description |
| :--- | :--- | :--- | :--- |
| `order_number` | `NVARCHAR(50)` | Degenerate Dimension | Transaction order identifier. |
| `product_key` | `BIGINT` | **Foreign Key** | References `gold.dim_products(product_key)`. |
| `customer_key` | `BIGINT` | **Foreign Key** | References `gold.dim_customers(customer_key)`. |
| `order_date` | `DATE` | Dimension Role | Date order was placed. |
| `shipping_date` | `DATE` | Dimension Role | Date order was shipped. |
| `due_date` | `DATE` | Dimension Role | Payment/delivery due date. |
| `sales_amount` | `INT` | **Additive Measure** | Total transaction revenue in USD. |
| `quantity` | `INT` | **Additive Measure** | Units sold. |
| `price` | `INT` | **Semi-Additive Measure** | Realized unit price in USD. |
