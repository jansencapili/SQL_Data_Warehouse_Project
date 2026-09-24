-- QUALITY CHECK

-- 1. Check for NULL or Duplicates in Primary Key
-- Expectation: No Results
SELECT  
    cst_id,
    COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Fix for duplicates
SELECT * -- Removing Duplicates
FROM (
			SELECT
				*,
				ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
			FROM bronze.crm_cust_info
			WHERE cst_id IS NOT NULL
		) t
		WHERE flag_last = 1; -- Select the most recent record per customer




-- 2. Check for unwanted spaces
-- Expectation: No Results
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Fix Check for unwanted spaces
SELECT
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname  
FROM bronze.crm_cust_info;


-- 3. Check for NULLs or Negative Numbers
-- Expectation: No Results
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- 4. Data Standardization & Consistency
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info;

-- fix Data Standardization & Consistency
SELECT
	cst_id,
	TRIM(cst_firstname) AS cst_firstname,
	CASE -- Data Normalization(Correcting Standard Naming Convention)
		WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		ELSE 'n/a'
	END AS cst_marital_status -- Normalize marital status values to readable format
FROM bronze.crm_cust_info;

-- 5. Check for Invalid Date Orders
-- Expectation: No Results
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;


-- fix Check for Invalid Date Orders
SELECT
	prd_id,
    prd_key,
	CAST(prd_start_dt AS DATE) AS prd_start_dt,
	CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS DATE
	) AS prd_end_dt -- Calculate end date as one day before the next start date
FROM bronze.crm_prd_info;


-- 6. Check if you can use foreign key to primary key
-- Expectation: No Results
SELECT *
FROM Bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM Silver.crm_prd_info)



-- 7. Check if there's negative or 0 in INT Values
SELECT sls_order_dt
FROM Bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 OR sls_order_dt > 20270101 OR sls_order_dt < 19991212;

-- fix Check if there's negative or 0 in INT Values
SELECT 
    NULLIF(sls_order_dt,0) AS sls_order_dt,
    CASE
        WHEN sls_order_dt <= 0 OR LEN(sls_order_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) -- Data Transformation (Data Type Casting)
    END AS sls_order_dt,
    CASE
        WHEN sls_ship_dt <= 0 OR LEN(sls_ship_dt) != 8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
    END AS sls_ship_dt
FROM Bronze.crm_sales_details

-- BUSINESS RULES
-- 1. Sales must be equal to Quantity multiple by price (Sales = Quantity * Price)
-- 2.Negative, Zero, Nulls are Not Allowed in all sales, price, and quantity. (Must be ABS or positive)

-- Check Data Consistency: Between Sales, Quantity, and Price
-- >> Sales = Quantity * Price
-- >> Values must not be NULL, zero, or negative

SELECT
    sls_sales,
    sls_quantity,
    sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price 
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0;

-- Rules
-- If Sales is negative, zero, or null, derive it using Quantity and Price
-- If Price is zero or null, calculate it using Sales and Quantity
-- If Price is negative, convert it to a positive value

-- fix -- Check Data Consistency: Between Sales, Quantity, and Price
-- 1. Data Issues will be fixed direct in source system
-- 2. Data Issues has to be fixed in data warehouse

-- fix number 2. 

SELECT DISTINCT -- distinct only for checking
    sls_sales as old_sales,
    sls_quantity,
    sls_price as old_price,
    CASE -- Data Transformation (Hanlding Invalid and Missing Data and Derived New Column)
        WHEN sls_sales IS NULL OR sls_sales <= 0 or sls_sales != sls_quantity * ABS(sls_price) 
        THEN sls_quantity * ABS(sls_price)
        ELSE sls_sales
    END sls_sales,
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price
    END sls_price
FROM Bronze.crm_sales_details


-- 8. Check if you can connect foreign key to other primary key
SELECT
    cid,
    bdate,
    gen    
FROM Bronze.erp_cust_az12
WHERE cid LIKE '%AW00011011';

SELECT TOP 5 *
FROM Silver.crm_cust_info;

-- If you notice a extra character in primary key, remove it
-- fix Check if you can connect foreign key to other primary key

SELECT
    CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END cid
FROM Bronze.erp_cust_az12

-- Now check again if it is exist in other table
-- Expectation: No Results
SELECT
cid,
    CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END cid,
bdate,
gen
FROM Bronze.erp_cust_az12
WHERE CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
        ELSE cid
    END NOT IN (SELECT cst_key FROM Silver.crm_cust_info)


-- 9. Identify Out-of-Range Dates
SELECT DISTINCT 
bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE();

-- fix Identify Out-of-Range Dates
SELECT
    CASE    
        WHEN bdate < '1924-01-01' OR bdate > GETDATE() THEN NULL
        ELSE bdate
    END bdate
FROM Bronze.erp_cust_az12

-- Fix Data Standardization & Consistency of gender
SELECT
    gen,
	CASE
		WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
		WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		ELSE 'n/a'
	END AS gen -- Normalize gender values and handle unknown cases
    FROM Bronze.erp_cust_az12;

-- Data Standardization & Consistency of country
SELECT DISTINCT
    cntry  
FROM Bronze.erp_loc_a101;

SELECT DISTINCT
    cntry
FROM Bronze.erp_loc_a101;

-- fix Data Standardization & Consistency of country
SELECT DISTINCT
    CASE    
        WHEN TRIM(cntry) = 'DE' THEN 'Germany'
        WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
        WHEN TRIM(cntry) IS NULL or TRIM(cntry) = '' THEN 'N/A'
        ELSE TRIM(cntry)
    END cntry
FROM Bronze.erp_loc_a101;

-- check fix Data Standardization & Consistency of country
SELECT DISTINCT
    cntry as old_cntry,
    CASE    
        WHEN TRIM(cntry) = 'DE' THEN 'Germany'
        WHEN TRIM(cntry) IN ('USA', 'US') THEN 'United States'
        WHEN TRIM(cntry) IS NULL or TRIM(cntry) = '' THEN 'N/A'
        ELSE TRIM(cntry)
    END cntry
FROM Bronze.erp_loc_a101;


SELECT *
FROM Silver.erp_cust_az12;

SELECT *
FROM Bronze.crm_cust_info;


SELECT *
FROM Bronze.erp_loc_a101;





-- find the second highest
SELECT MAX(sls_sales)
FROM Bronze.crm_sales_details
WHERE sls_sales < (
    SELECT MAX(sls_sales)
    FROM Bronze.crm_sales_details
);

-- find the 3rd highest
SELECT MAX(sls_sales)
FROM Bronze.crm_sales_details
WHERE sls_sales < (
    SELECT MAX(sls_sales)
    FROM Bronze.crm_sales_details
    WHERE sls_sales < (
        SELECT MAX(sls_sales)
        FROM Bronze.crm_sales_details
    )
);
