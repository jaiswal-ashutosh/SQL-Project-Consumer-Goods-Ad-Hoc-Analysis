-- 1. List of markets for "Atliq Exclusive" in the APAC region
SELECT DISTINCT market
FROM dim_customer
WHERE customer = 'Atliq Exclusive' AND region = 'APAC';

-- 2. Percentage of unique product increase in 2021 vs. 2020
WITH cte AS (
    SELECT
        (SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year = 2020) AS unique_products_2020,
        (SELECT COUNT(DISTINCT product_code) FROM fact_sales_monthly WHERE fiscal_year = 2021) AS unique_products_2021
)
SELECT 
    unique_products_2020,
    unique_products_2021,
    ((unique_products_2021 - unique_products_2020) / unique_products_2020 * 100) AS percentage_chg
FROM cte;

-- 3. Unique product counts for each segment, sorted in descending order
SELECT segment, COUNT(DISTINCT product_code) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;

-- 4. Segment with the most increase in unique products in 2021 vs. 2020
WITH cte_2020 AS (
    SELECT p.segment, COUNT(DISTINCT s.product_code) AS product_count_2020
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE fiscal_year = 2020
    GROUP BY p.segment
), cte_2021 AS (
    SELECT p.segment, COUNT(DISTINCT s.product_code) AS product_count_2021
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE fiscal_year = 2021
    GROUP BY p.segment
)
SELECT cte_2020.segment, cte_2020.product_count_2020, cte_2021.product_count_2021, 
       (cte_2021.product_count_2021 - cte_2020.product_count_2020) AS difference
FROM cte_2020
JOIN cte_2021 ON cte_2020.segment = cte_2021.segment;

-- 5. Products with highest and lowest manufacturing costs
(SELECT m.product_code, p.product, m.manufacturing_cost
 FROM fact_manufacturing_cost m
 JOIN dim_product p ON m.product_code = p.product_code
 ORDER BY m.manufacturing_cost DESC
 LIMIT 1)
UNION
(SELECT m.product_code, p.product, m.manufacturing_cost
 FROM fact_manufacturing_cost m
 JOIN dim_product p ON m.product_code = p.product_code
 ORDER BY m.manufacturing_cost ASC
 LIMIT 1);

-- 6. Top 5 customers with highest average pre-invoice discount percentage in 2021 in India
WITH cte AS (
    SELECT c.customer_code, 
           c.customer, 
           ROUND(AVG(pre.pre_invoice_discount_pct), 4) AS avg_pre_invoice_discount_pct
    FROM fact_pre_invoice_deductions pre
    JOIN dim_customer c ON pre.customer_code = c.customer_code
    WHERE c.market = 'India' AND pre.fiscal_year = 2021
    GROUP BY c.customer_code, c.customer
)
SELECT customer_code, 
       customer, 
       avg_pre_invoice_discount_pct
FROM cte
ORDER BY avg_pre_invoice_discount_pct DESC
LIMIT 5;

-- 7. Gross sales amount for "Atliq Exclusive" for each month
CREATE TEMPORARY TABLE temp_gross_sales AS
SELECT 
    MONTH(s.date) AS month,
    MONTHNAME(s.date) AS month_name,
    YEAR(s.date) AS year,
    (s.sold_quantity * g.gross_price) AS gross_sales
FROM fact_sales_monthly s
JOIN fact_gross_price g ON s.product_code = g.product_code
JOIN dim_customer c ON c.customer_code = s.customer_code
WHERE c.customer = 'Atliq Exclusive';

SELECT year, month, month_name, 
       ROUND(SUM(gross_sales) / 1000000, 2) AS gross_sales_monthly_mln
FROM temp_gross_sales
GROUP BY year, month, month_name
ORDER BY year, gross_sales_monthly_mln;

-- 8. Quarter of 2020 with the maximum total sold quantity
WITH cte AS (
    SELECT 
        CASE
            WHEN MONTH(date) IN (1, 2, 3) THEN 'Q1'
            WHEN MONTH(date) IN (4, 5, 6) THEN 'Q2'
            WHEN MONTH(date) IN (7, 8, 9) THEN 'Q3'
            WHEN MONTH(date) IN (10, 11, 12) THEN 'Q4'
        END AS quarter,
        sold_quantity
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020
)
SELECT quarter, SUM(sold_quantity) AS total_sold_quantity
FROM cte
GROUP BY quarter
ORDER BY total_sold_quantity DESC;

-- 9. Channel with highest gross sales in 2021 and its percentage contribution
WITH cte1 AS (
    SELECT c.channel, s.sold_quantity * g.gross_price AS gross_sales
    FROM fact_sales_monthly s
    JOIN fact_gross_price g ON s.product_code = g.product_code
    JOIN dim_customer c ON s.customer_code = c.customer_code
    WHERE s.fiscal_year = 2021
), cte2 AS (
    SELECT SUM(gross_sales) / 1000000 AS total_gross_sales_mln FROM cte1
), cte3 AS (
    SELECT channel, SUM(gross_sales) / 1000000 AS gross_sales_mln
    FROM cte1
    GROUP BY channel
)
SELECT channel, 
       ROUND(gross_sales_mln, 2) AS gross_sales_mln, 
       ROUND(gross_sales_mln / (SELECT total_gross_sales_mln FROM cte2) * 100, 2) AS percentage_contribution
FROM cte3;

-- 10. Top 3 products in each division by total sold quantity in 2021
WITH RankedProducts AS (
    SELECT
        p.division,
        s.product_code,
        p.product,
        SUM(s.sold_quantity) AS total_sold_quantity,
        DENSE_RANK() OVER (PARTITION BY p.division ORDER BY SUM(s.sold_quantity) DESC) AS rank_order
    FROM fact_sales_monthly s
    JOIN dim_product p ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, s.product_code, p.product
)
SELECT division, product_code, product, total_sold_quantity, rank_order
FROM RankedProducts
WHERE rank_order <= 3
ORDER BY division, rank_order;
