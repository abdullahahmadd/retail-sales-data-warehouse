-- =========================================================
-- DIMENSION TABLE: DimDate
-- Stores calendar attributes to enable time-based analysis
-- (yearly, quarterly, monthly, daily, weekday reporting)
-- =========================================================
CREATE TABLE dimdate (
    dateid INT,
    date DATE,
    year INT,
    quarter INT,
    quartername TEXT,
    month INT,
    monthname TEXT,
    day INT,
    weekday INT,
    weekdayname TEXT
);

-- Verify sample data loaded into DimDate
SELECT * FROM dimdate LIMIT 5;


-- =========================================================
-- DIMENSION TABLE: DimProduct
-- Stores product-level descriptive information
-- Used for product-based sales analysis
-- =========================================================
CREATE TABLE dimproduct (
    productid INT PRIMARY KEY,
    producttype VARCHAR(255) NOT NULL
);

-- Verify sample data loaded into DimProduct
SELECT * FROM dimproduct LIMIT 5;


-- =========================================================
-- DIMENSION TABLE: DimCustomerSegment
-- Stores customer segmentation data (city-level in this model)
-- Enables geographic sales analysis
-- =========================================================
CREATE TABLE dimcustomersegment (
    segmentid INT PRIMARY KEY,
    city VARCHAR(255) NOT NULL
);

-- Verify sample data loaded into DimCustomerSegment
SELECT * FROM dimcustomersegment LIMIT 5;


-- =========================================================
-- FACT TABLE: FactSales
-- Central fact table storing measurable sales metrics
-- References all dimension tables via foreign keys
-- =========================================================
CREATE TABLE factsales (
    salesid VARCHAR(255) PRIMARY KEY,
    dateid INT NOT NULL,
    productid INT NOT NULL,
    segmentid INT NOT NULL,
    price_perunit DECIMAL(10,2) NOT NULL,
    quantitysold INT NOT NULL,
    FOREIGN KEY (dateid) REFERENCES dimdate(dateid),
    FOREIGN KEY (productid) REFERENCES dimproduct(productid),
    FOREIGN KEY (segmentid) REFERENCES dimcustomersegment(segmentid)
);

-- Verify sample data loaded into FactSales
SELECT * FROM factsales LIMIT 5;


-- =========================================================
-- GROUPING SETS QUERY
-- Calculates total sales at multiple aggregation levels:
-- 1) By productid + producttype
-- 2) By productid only
-- 3) By producttype only
-- 4) Grand total across all products
-- =========================================================
SELECT
    p.productid,
    p.producttype,
    SUM(f.price_perunit * f.quantitysold) AS totalsales
FROM factsales f
JOIN dimproduct p
    ON f.productid = p.productid
GROUP BY GROUPING SETS (
    (p.productid, p.producttype),
    (p.productid),
    (p.producttype),
    ()
)
ORDER BY p.productid, p.producttype;


-- =========================================================
-- ROLLUP QUERY
-- Generates hierarchical sales totals:
-- Year → City → Product Type
-- Includes subtotals and grand totals with readable labels
-- =========================================================
SELECT
    d.year,
    COALESCE(cs.city, 'ALL CITIES') AS city,
    CASE
        WHEN GROUPING(p.producttype) = 1 THEN 'ALL PRODUCTS'
        ELSE p.producttype
    END AS producttype,
    SUM(f.price_perunit * f.quantitysold) AS totalsales
FROM factsales f
JOIN dimdate d
    ON f.dateid = d.dateid
JOIN dimproduct p
    ON f.productid = p.productid
JOIN dimcustomersegment cs
    ON f.segmentid = cs.segmentid
GROUP BY ROLLUP (d.year, cs.city, p.producttype)
ORDER BY d.year DESC, city, producttype;


-- =========================================================
-- CUBE QUERY
-- Calculates average sales across all combinations of:
-- Year, City, and Product Type
-- Produces detailed rows, subtotals, and grand totals
-- =========================================================
SELECT
    COALESCE(d.year::TEXT, 'ALL YEARS') AS year,
    COALESCE(cs.city, 'ALL CITIES') AS city,
    CASE
        WHEN GROUPING(p.producttype) = 1 THEN 'ALL PRODUCTS'
        ELSE p.producttype
    END AS producttype,
    AVG(f.price_perunit * f.quantitysold) AS averagesales
FROM factsales f
JOIN dimdate d
    ON f.dateid = d.dateid
JOIN dimproduct p
    ON f.productid = p.productid
JOIN dimcustomersegment cs
    ON f.segmentid = cs.segmentid
GROUP BY CUBE (d.year, cs.city, p.producttype)
ORDER BY year, city, producttype;


-- =========================================================
-- MATERIALIZED VIEW: max_sales
-- Stores maximum sales value per city and product
-- Improves performance for repeated analytical queries
-- =========================================================
CREATE MATERIALIZED VIEW max_sales AS
SELECT
    cs.city,
    p.productid,
    p.producttype,
    MAX(f.price_perunit * f.quantitysold) AS maxsales
FROM factsales f
JOIN dimproduct p
    ON f.productid = p.productid
JOIN dimcustomersegment cs
    ON f.segmentid = cs.segmentid
GROUP BY
    cs.city,
    p.productid,
    p.producttype
WITH DATA;


-- =========================================================
-- REFRESH MATERIALIZED VIEW
-- Updates the materialized view with the latest fact data
-- =========================================================
REFRESH MATERIALIZED VIEW max_sales;
