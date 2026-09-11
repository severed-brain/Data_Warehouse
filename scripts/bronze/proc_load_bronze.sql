/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads raw data into the 'bronze' schema from external 
    CSV files (ERP and CRM source data).
    
    Actions Performed:
    - Truncates the bronze tables before loading data.
    - Dynamically loads CSV data using the BULK INSERT command.
    - Captures and logs load durations for each table and overall batch.

Parameters:
    @data_path NVARCHAR(500) (Optional):
        The base directory path where the dataset folders ('source_crm' and 'source_erp') 
        are located. If NULL, defaults to 'C:\Data Warehouse\SQL-Data-Warehouse\datasets'.

Usage Examples:
    -- Execute with default path:
    EXEC bronze.load_bronze;

    -- Execute with custom path:
    EXEC bronze.load_bronze @data_path = 'C:\Data Warehouse\SQL-Data-Warehouse\datasets';
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze 
    @data_path NVARCHAR(500) = NULL
AS
BEGIN
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @base_path NVARCHAR(500);

    -- Use provided path or fallback to default project dataset location
    SET @base_path = ISNULL(@data_path, 'C:\Data Warehouse\SQL-Data-Warehouse\datasets');

    -- Remove trailing backslash if present
    IF RIGHT(@base_path, 1) = '\'
        SET @base_path = LEFT(@base_path, LEN(@base_path) - 1);

    BEGIN TRY
        SET @batch_start_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer';
        PRINT 'Source Directory: ' + @base_path;
        PRINT '================================================';

        -- ====================================================================
        -- 1. Loading CRM Tables
        -- ====================================================================
        PRINT '------------------------------------------------';
        PRINT 'Loading CRM Tables';
        PRINT '------------------------------------------------';

        -- bronze.crm_cust_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Inserting Data Into: bronze.crm_cust_info';
        SET @sql = '
            BULK INSERT bronze.crm_cust_info
            FROM ''' + @base_path + '\source_crm\cust_info.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.crm_prd_info
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Inserting Data Into: bronze.crm_prd_info';
        SET @sql = '
            BULK INSERT bronze.crm_prd_info
            FROM ''' + @base_path + '\source_crm\prd_info.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.crm_sales_details
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Inserting Data Into: bronze.crm_sales_details';
        SET @sql = '
            BULK INSERT bronze.crm_sales_details
            FROM ''' + @base_path + '\source_crm\sales_details.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- ====================================================================
        -- 2. Loading ERP Tables
        -- ====================================================================
        PRINT '------------------------------------------------';
        PRINT 'Loading ERP Tables';
        PRINT '------------------------------------------------';
        
        -- bronze.erp_loc_a101
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
        SET @sql = '
            BULK INSERT bronze.erp_loc_a101
            FROM ''' + @base_path + '\source_erp\loc_a101.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.erp_cust_az12
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
        SET @sql = '
            BULK INSERT bronze.erp_cust_az12
            FROM ''' + @base_path + '\source_erp\cust_az12.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        -- bronze.erp_px_cat_g1v2
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
        SET @sql = '
            BULK INSERT bronze.erp_px_cat_g1v2
            FROM ''' + @base_path + '\source_erp\px_cat_g1v2.csv''
            WITH (
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                TABLOCK
            );';
        EXEC sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';

        SET @batch_end_time = GETDATE();
        PRINT '================================================';
        PRINT 'Loading Bronze Layer is Completed';
        PRINT '   - Total Load Duration: ' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State:   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '================================================';
    END CATCH
END;
GO
