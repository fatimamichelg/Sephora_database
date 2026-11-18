
# Options for the drop-down filters (also read from the database)
SKINCARE_CATEGORIES = """
SELECT DISTINCT secondary_category
FROM category
WHERE primary_category = 'Skincare' AND secondary_category IS NOT NULL
ORDER BY secondary_category;
"""

REVIEW_DATE_RANGE = """
SELECT MIN(submission_time), MAX(submission_time) FROM review;
"""

# Q1 - Fatima Michel - JOIN, GROUP BY, HAVING
Q1 = """
SELECT b.brand_name,
       COUNT(*)                          AS total_products,
       ROUND(AVG(p.price_usd), 2)::FLOAT AS avg_price,
       ROUND(AVG(p.rating), 2)::FLOAT    AS avg_rating
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
GROUP BY b.brand_id, b.brand_name
HAVING COUNT(*) >= %(min_products)s
ORDER BY total_products DESC;
"""

# Q2 - Fatima Michel - JOIN, scalar subqueries
Q2 = """
SELECT p.product_name,
       b.brand_name,
       p.price_usd::FLOAT AS price_usd,
       p.loves_count
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
WHERE p.price_usd   < (SELECT AVG(price_usd)   FROM product)
  AND p.price_usd   <= %(max_price)s
  AND p.loves_count > (SELECT AVG(loves_count) FROM product)
ORDER BY p.loves_count DESC
LIMIT 20;
"""

# Q3 - Fatima Michel - ADVANCED: CTE + RANK with PARTITION BY
Q3 = """
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
WHERE position <= %(top_n)s
  AND secondary_category = %(category)s
ORDER BY position;
"""

# Q4 - Fatima Michel - ADVANCED: CTE + N:N JOIN + HAVING + subquery
Q4 = """
WITH highlight_stats AS (
    SELECT h.name           AS highlight,
           COUNT(*)         AS total_products,
           AVG(p.rating)    AS avg_rating,
           AVG(p.price_usd) AS avg_price
    FROM highlight h
    JOIN product_highlight ph ON ph.highlight_id = h.highlight_id
    JOIN product p            ON p.product_id    = ph.product_id
    WHERE p.rating IS NOT NULL
    GROUP BY h.highlight_id, h.name
    HAVING COUNT(*) >= %(min_products)s
)
SELECT highlight,
       total_products,
       ROUND(avg_rating, 3)::FLOAT                                     AS avg_rating,
       ROUND(avg_price, 2)::FLOAT                                      AS avg_price,
       ROUND(avg_rating - (SELECT AVG(rating) FROM product), 3)::FLOAT AS diff_vs_all_products
FROM highlight_stats
ORDER BY diff_vs_all_products DESC;
"""

# Q5 - Fatima Michel - LEFT JOIN + IS NULL
Q5 = """
SELECT c.primary_category,
       COUNT(p.product_id) AS products_without_reviews
FROM product p
JOIN category c    ON c.category_id = p.category_id
LEFT JOIN review r ON r.product_id  = p.product_id
WHERE r.review_id IS NULL
GROUP BY c.primary_category
ORDER BY products_without_reviews DESC;
"""

# Q6 - Itsaso - 3-table JOIN, GROUP BY, HAVING
Q6 = """
SELECT r.skin_type,
       COUNT(*)                                          AS total_reviews,
       ROUND(AVG(r.rating), 2)::FLOAT                    AS avg_rating,
       ROUND(100 * AVG(r.is_recommended::INT), 1)::FLOAT AS pct_recommended
FROM review r
JOIN product p  ON p.product_id  = r.product_id
JOIN category c ON c.category_id = p.category_id
WHERE c.secondary_category = %(category)s
  AND r.skin_type IS NOT NULL
GROUP BY r.skin_type
HAVING COUNT(*) >= %(min_reviews)s
ORDER BY avg_rating DESC;
"""

# Q7 - Itsaso - ADVANCED: two chained CTEs + LAG
Q7 = """
WITH monthly AS (
    SELECT DATE_TRUNC('month', submission_time)::DATE AS month,
           COUNT(*)                                   AS total_reviews,
           ROUND(AVG(rating), 2)::FLOAT               AS avg_rating
    FROM review
    WHERE submission_time BETWEEN %(start)s AND %(end)s
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
       total_reviews - previous_reviews                                               AS change,
       ROUND(100.0 * (total_reviews - previous_reviews) / previous_reviews, 1)::FLOAT AS pct_change,
       avg_rating
FROM with_previous
ORDER BY month;
"""

# Q8 - Itsaso - ADVANCED: CTE + 4-table JOIN + HAVING + RANK
Q8 = """
WITH brand_category AS (
    SELECT c.secondary_category,
           b.brand_name,
           COUNT(*)                       AS total_reviews,
           ROUND(AVG(r.rating), 2)::FLOAT AS avg_rating,
           RANK() OVER (
               PARTITION BY c.secondary_category
               ORDER BY AVG(r.rating) DESC
           ) AS position
    FROM review r
    JOIN product p  ON p.product_id  = r.product_id
    JOIN brand b    ON b.brand_id    = p.brand_id
    JOIN category c ON c.category_id = p.category_id
    GROUP BY c.secondary_category, b.brand_id, b.brand_name
    HAVING COUNT(*) >= %(min_reviews)s
)
SELECT position, brand_name, total_reviews, avg_rating
FROM brand_category
WHERE position <= %(top_n)s
  AND secondary_category = %(category)s
ORDER BY position;
"""

# Q9 - Itsaso - JOIN, CASE, GROUP BY
#   %(category)s = NULL means "all skincare categories"
Q9 = """
SELECT CASE
           WHEN p.price_usd < 25  THEN '1. under $25'
           WHEN p.price_usd < 50  THEN '2. $25 - 49'
           WHEN p.price_usd < 100 THEN '3. $50 - 99'
           ELSE                        '4. $100 or more'
       END                                               AS price_band,
       COUNT(DISTINCT p.product_id)                      AS total_products,
       COUNT(*)                                          AS total_reviews,
       ROUND(AVG(r.rating), 2)::FLOAT                    AS avg_rating,
       ROUND(100 * AVG(r.is_recommended::INT), 1)::FLOAT AS pct_recommended
FROM review r
JOIN product p  ON p.product_id  = r.product_id
JOIN category c ON c.category_id = p.category_id
WHERE (%(category)s IS NULL OR c.secondary_category = %(category)s)
GROUP BY price_band
ORDER BY price_band;
"""

# Q10 - Itsaso - read-only part of Q10: the products whose stored rating
# differs from the average of their reviews. (The UPDATE inside
# BEGIN ... ROLLBACK is shown in pgAdmin, not in the app: the app is read-only.)
Q10 = """
SELECT p.product_name,
       b.brand_name,
       p.rating::FLOAT                                  AS stored_rating,
       ROUND(s.reviews_avg, 4)::FLOAT                   AS reviews_avg,
       s.total_reviews,
       ROUND(ABS(p.rating - s.reviews_avg), 4)::FLOAT   AS difference
FROM product p
JOIN brand b ON b.brand_id = p.brand_id
JOIN (SELECT product_id, AVG(rating) AS reviews_avg, COUNT(*) AS total_reviews
      FROM review
      GROUP BY product_id) s ON s.product_id = p.product_id
WHERE ABS(p.rating - s.reviews_avg) > %(threshold)s
ORDER BY difference DESC;
"""