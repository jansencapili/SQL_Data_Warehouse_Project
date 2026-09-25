/*
===============================================================================
Quality Checks (GOLD)
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency, 
    and accuracy of the Gold Layer. These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- ====================================================================
-- Checking 'gold.dim_customers'
-- ====================================================================


-- try

SELECT *
FROM Silver.crm_cust_info;

SELECT *
FROM Silver.erp_cust_az12;

SELECT *
FROM Silver.erp_loc_a101;


-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results 
SELECT 
    customer_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;


-- connecting customer tables (customer, birthdate, gender, country)
SELECT
    ci.cst_id,
    ci.cst_key,
    ci.cst_firstname,
    ci.cst_lastname,
    ci.cst_marital_status,
    ci.cst_gndr,
    ci.cst_create_date,
    ca.bdate,
    ca.gen,
    la.cntry
FROM Silver.crm_cust_info ci
LEFT JOIN Silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN Silver.erp_loc_a101 la ON ci.cst_key = la.cid;


-- check if there's dups in primary key
SELECT
    cst_id, 
    COUNT(*)AS duplicate_count
FROM (SELECT
    ci.cst_id,
    ci.cst_key,
    ci.cst_firstname,
    ci.cst_lastname,
    ci.cst_marital_status,
    ci.cst_gndr,
    ci.cst_create_date,
    ca.bdate,
    ca.gen,
    la.cntry
FROM Silver.crm_cust_info ci
LEFT JOIN Silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN Silver.erp_loc_a101 la ON ci.cst_key = la.cid)t   
GROUP BY cst_id
HAVING COUNT(*) > 1;


-- check the values (data integration issue) 
-- 2 sources of gender (crm.cst_info and erp_cust_az12)
-- Ask the business if which is the correct source table

SELECT DISTINCT
    ci.cst_gndr,
    ca.gen,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr -- CRM is the Master for gender info
        ELSE COALESCE(ca.gen, 'n/a')
    END AS new_gen
FROM Silver.crm_cust_info ci
LEFT JOIN Silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
LEFT JOIN Silver.erp_loc_a101 la ON ci.cst_key = la.cid
ORDER BY 1, 2;

-- ====================================================================
-- Checking 'gold.product_key'
-- ====================================================================
-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results 
SELECT 
    product_key,
    COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- ====================================================================
-- Checking 'gold.fact_sales'
-- ====================================================================
-- Check the data model connectivity between fact and dimensions
SELECT * 
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE p.product_key IS NULL OR c.customer_key IS NULL  
