
-- =====================================================================
-- queries.sql  -  Project B: Sephora database
--
-- Coverage of the required constructs:
--   JOIN of 2+ tables ......... Q1, Q2, Q3, Q4, Q5, Q6, Q8, Q9, Q10
--   GROUP BY with HAVING ...... Q1, Q4, Q6, Q8
--   Subquery .................. Q2, Q4, Q10
--   Window function ........... Q3 (RANK), Q7 (LAG), Q8 (RANK)
--   CTE with WITH ............. Q3, Q4, Q7, Q8
--   DML inside a transaction .. Q10 (UPDATE with BEGIN / ROLLBACK)
--   LEFT JOIN + IS NULL ....... Q5
--
-- Advanced queries:  Fatima Michel -> Q3, Q4     Itsaso -> Q7, Q8, Q10
-- =====================================================================
 
 
-- =====================================================================
-- PART A - PRODUCTS AND BRANDS  (author: Fatima Michel)
-- =====================================================================
 
-- ---------------------------------------------------------------------
-- Q1. Which brands have the largest catalogue at Sephora, and how
--     expensive and well rated are their products?
--     (only brands with at least 50 products)
-- Constructs: JOIN, GROUP BY, HAVING
-- ---------------------------------------------------------------------
SELECT b.brand_name,
       COUNT(*)                    AS total_products,
       ROUND(AVG(p.price_usd), 2)  AS avg_price,
       ROUND(AVG(p.rating), 2)     AS avg_rating
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_id, b.brand_name
HAVING COUNT(*) >= 50
ORDER BY total_products DESC;

-- ---------------------------------------------------------------------
-- Q2. Which products are loved more than the average product while
--     costing less than the average price?  ("affordable favourites")
-- Constructs: JOIN, scalar subqueries in WHERE
-- ---------------------------------------------------------------------
SELECT p.product_name,
       b.brand_name,
       p.price_usd,
       p.loves_count
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
WHERE p.price_usd   < (SELECT AVG(price_usd)   FROM product)
  AND p.loves_count > (SELECT AVG(loves_count) FROM product)
ORDER BY p.loves_count DESC
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q3. [ADVANCED] What are the 3 most loved products in each skincare
--     category?
-- Constructs: CTE, window function RANK with PARTITION BY, 3-table JOIN
-- Pattern from class: "top N per group" = rank inside a partition,
-- then filter the rank in the outer query.
-- ---------------------------------------------------------------------
WITH ranked AS (
    SELECT c.secondary_category,
           p.product_name,
           b.brand_name,
           p.loves_count,
           RANK() OVER (
               PARTITION BY c.secondary_category
               ORDER BY p.loves_count DESC
           ) AS position
    FROM product p
    JOIN category c ON c.category_id = p.category_id
    JOIN brand b    ON b.brand_id    = p.brand_id
    WHERE c.primary_category = 'Skincare'
)
SELECT secondary_category, position, product_name, brand_name, loves_count
FROM ranked
WHERE position <= 3
ORDER BY secondary_category, position;
-- ---------------------------------------------------------------------
-- Q4. [ADVANCED] Which product highlights (Vegan, Clean at Sephora...)
--     are linked to better rated products than the average product?
--     (only highlights present in at least 100 rated products)
-- Constructs: CTE, JOIN through the N:N table, GROUP BY + HAVING,
--             scalar subquery
-- ---------------------------------------------------------------------
WITH highlight_stats AS (
    SELECT h.name                AS highlight,
           COUNT(*)              AS total_products,
           AVG(p.rating)         AS avg_rating,
           AVG(p.price_usd)      AS avg_price
    FROM highlight h
    JOIN product_highlight ph ON ph.highlight_id = h.highlight_id
    JOIN product p            ON p.product_id    = ph.product_id
    WHERE p.rating IS NOT NULL
    GROUP BY h.highlight_id, h.name
    HAVING COUNT(*) >= 100
)
SELECT highlight,
       total_products,
       ROUND(avg_rating, 3)                                        AS avg_rating,
       ROUND(avg_price, 2)                                         AS avg_price,
       ROUND(avg_rating - (SELECT AVG(rating) FROM product), 3)    AS diff_vs_all_products
FROM highlight_stats
ORDER BY diff_vs_all_products DESC;

-- ---------------------------------------------------------------------
-- Q5. How many products of each category have no review at all?
-- Constructs: LEFT JOIN + IS NULL (rows without a match), GROUP BY
-- ---------------------------------------------------------------------
SELECT c.primary_category,
       COUNT(p.product_id) AS products_without_reviews
FROM product p
JOIN category c     ON c.category_id = p.category_id
LEFT JOIN review r  ON r.product_id  = p.product_id
WHERE r.review_id IS NULL
GROUP BY c.primary_category
ORDER BY products_without_reviews DESC;


-- =====================================================================
-- PART B - REVIEWS AND CUSTOMERS  (author: Itsaso)
-- =====================================================================

-- ---------------------------------------------------------------------
-- Q6. For moisturizers, do customers with different skin types rate
--     and recommend them differently?
--     (only skin types with at least 1,000 reviews)
-- Constructs: 3-table JOIN, GROUP BY, HAVING
-- ---------------------------------------------------------------------
SELECT r.skin_type,
       COUNT(*)                                       AS total_reviews,
       ROUND(AVG(r.rating), 2)                        AS avg_rating,
       ROUND(100 * AVG(r.is_recommended::INT), 1)     AS pct_recommended
FROM review r
JOIN product p  ON p.product_id  = r.product_id
JOIN category c ON c.category_id = p.category_id
WHERE c.secondary_category = 'Moisturizers'
  AND r.skin_type IS NOT NULL
GROUP BY r.skin_type
HAVING COUNT(*) >= 1000
ORDER BY avg_rating DESC;

-- ---------------------------------------------------------------------
-- Q7. [ADVANCED] How did the number of reviews change from one month
--     to the next since 2019?
-- Constructs: two chained CTEs, window function LAG
-- Pattern from class: LAG cannot be filtered or reused in the same
-- SELECT, so it is computed in a CTE first.
-- ---------------------------------------------------------------------
WITH monthly AS (
    SELECT DATE_TRUNC('month', submission_time)::DATE AS month,
           COUNT(*)                                   AS total_reviews,
           ROUND(AVG(rating), 2)                      AS avg_rating
    FROM review
    WHERE submission_time >= DATE '2019-01-01'
    GROUP BY 1
),
with_previous AS (
    SELECT month, total_reviews, avg_rating,
           LAG(total_reviews) OVER (ORDER BY month) AS previous_reviews
    FROM monthly
)
SELECT month,
       total_reviews,
       previous_reviews,
       total_reviews - previous_reviews                                   AS change,
       ROUND(100.0 * (total_reviews - previous_reviews) / previous_reviews, 1) AS pct_change,
       avg_rating
FROM with_previous
ORDER BY month;

-- ---------------------------------------------------------------------
-- Q8. [ADVANCED] Which are the 3 best rated brands in each skincare
--     category, according to customer reviews?
--     (only brands with at least 500 reviews in that category)
-- Constructs: CTE, 4-table JOIN, GROUP BY + HAVING, RANK with PARTITION BY
-- ---------------------------------------------------------------------
WITH brand_category AS (
    SELECT c.secondary_category,
           b.brand_name,
           COUNT(*)                AS total_reviews,
           ROUND(AVG(r.rating), 2) AS avg_rating,
           RANK() OVER (
               PARTITION BY c.secondary_category
               ORDER BY AVG(r.rating) DESC
           ) AS position
    FROM review r
    JOIN product p  ON p.product_id  = r.product_id
    JOIN brand b    ON b.brand_id    = p.brand_id
    JOIN category c ON c.category_id = p.category_id
    GROUP BY c.secondary_category, b.brand_id, b.brand_name
    HAVING COUNT(*) >= 500
)
SELECT secondary_category, position, brand_name, total_reviews, avg_rating
FROM brand_category
WHERE position <= 3
ORDER BY secondary_category, position;

-- ---------------------------------------------------------------------
-- Q9. Do more expensive products get better reviews?
-- Constructs: JOIN, CASE to build price bands, GROUP BY
-- ---------------------------------------------------------------------
SELECT CASE
           WHEN p.price_usd < 25  THEN '1. under $25'
           WHEN p.price_usd < 50  THEN '2. $25 - 49'
           WHEN p.price_usd < 100 THEN '3. $50 - 99'
           ELSE                        '4. $100 or more'
       END                                            AS price_band,
       COUNT(DISTINCT p.product_id)                   AS total_products,
       COUNT(*)                                       AS total_reviews,
       ROUND(AVG(r.rating), 2)                        AS avg_rating,
       ROUND(100 * AVG(r.is_recommended::INT), 1)     AS pct_recommended
FROM review r
JOIN product p ON p.product_id = r.product_id
GROUP BY price_band
ORDER BY price_band;

-- ---------------------------------------------------------------------
-- Q10. [ADVANCED] Does the rating stored for each product match the
--      average of its reviews in our database? Recalculate it inside a
--      transaction, check the effect, and undo it.
-- Constructs: UPDATE inside a transaction (BEGIN ... ROLLBACK),
--             subquery in FROM, JOIN
-- ---------------------------------------------------------------------
BEGIN;

-- Before: products whose stored rating differs by more than 0.1
SELECT COUNT(*) AS products_with_different_rating
FROM product p
JOIN (SELECT product_id, AVG(rating) AS reviews_avg
      FROM review
      GROUP BY product_id) s ON s.product_id = p.product_id
WHERE ABS(p.rating - s.reviews_avg) > 0.1;
-- Recalculate the rating from the reviews
UPDATE product p
SET rating = s.reviews_avg
FROM (SELECT product_id, ROUND(AVG(rating), 4) AS reviews_avg
      FROM review
      GROUP BY product_id) s
WHERE s.product_id = p.product_id;
-- After: inside the transaction the difference is gone
SELECT COUNT(*) AS products_with_different_rating
FROM product p
JOIN (SELECT product_id, AVG(rating) AS reviews_avg
      FROM review
      GROUP BY product_id) s ON s.product_id = p.product_id
WHERE ABS(p.rating - s.reviews_avg) > 0.1;


-- Undo: the original Sephora ratings are kept
ROLLBACK;
