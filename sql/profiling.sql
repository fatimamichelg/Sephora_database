-- =====================================================================
-- profiling.sql  -  Project B: Sephora database
-- Data profile of the raw CSV files, run on the staging tables created
-- by sql/load_staging.sql. Run each query separately in pgAdmin.
-- Part A: products (A1-A11).  Part B: reviews (B1-B15, plus B4b, B5b).
-- (Column aliases are kept as they appear in the report screenshots.)
-- =====================================================================

-- =====================================================================
-- PART A: PRODUCTS (staging_products)  -  Fatima Michel
-- =====================================================================

-- A1. Number of rows in the file
SELECT COUNT(*) AS total_products
FROM staging_products;

-- A2. Candidate key: is product_id unique?
--     If total = distinct -> it is unique and can be the PRIMARY KEY
SELECT COUNT(*)                   AS total_filas,
       COUNT(DISTINCT product_id) AS product_id_distintos
FROM staging_products;

-- A3. NULL (or empty) values per column
SELECT
  COUNT(*) FILTER (WHERE NULLIF(product_id, '')         IS NULL) AS null_product_id,
  COUNT(*) FILTER (WHERE NULLIF(product_name, '')       IS NULL) AS null_product_name,
  COUNT(*) FILTER (WHERE NULLIF(brand_id, '')           IS NULL) AS null_brand_id,
  COUNT(*) FILTER (WHERE NULLIF(brand_name, '')         IS NULL) AS null_brand_name,
  COUNT(*) FILTER (WHERE NULLIF(rating, '')             IS NULL) AS null_rating,
  COUNT(*) FILTER (WHERE NULLIF(size, '')               IS NULL) AS null_size,
  COUNT(*) FILTER (WHERE NULLIF(ingredients, '')        IS NULL) AS null_ingredients,
  COUNT(*) FILTER (WHERE NULLIF(price_usd, '')          IS NULL) AS null_price,
  COUNT(*) FILTER (WHERE NULLIF(value_price_usd, '')    IS NULL) AS null_value_price,
  COUNT(*) FILTER (WHERE NULLIF(sale_price_usd, '')     IS NULL) AS null_sale_price,
  COUNT(*) FILTER (WHERE NULLIF(highlights, '')         IS NULL) AS null_highlights,
  COUNT(*) FILTER (WHERE NULLIF(primary_category, '')   IS NULL) AS null_primary_cat,
  COUNT(*) FILTER (WHERE NULLIF(secondary_category, '') IS NULL) AS null_secondary_cat,
  COUNT(*) FILTER (WHERE NULLIF(tertiary_category, '')  IS NULL) AS null_tertiary_cat
FROM staging_products;

-- A4. Numeric ranges: price, rating, loves
SELECT MIN(price_usd::NUMERIC)   AS precio_min,
       MAX(price_usd::NUMERIC)   AS precio_max,
       MIN(rating::NUMERIC)      AS rating_min,
       MAX(rating::NUMERIC)      AS rating_max,
       MIN(loves_count::INT)     AS loves_min,
       MAX(loves_count::INT)     AS loves_max
FROM staging_products;

-- A5. Outliers: sale price higher than the normal price
SELECT COUNT(*) AS oferta_mayor_que_precio
FROM staging_products
WHERE sale_price_usd::NUMERIC > price_usd::NUMERIC;

-- A6. Values of the flags (should only be 0 and 1)
SELECT 'limited_edition' AS flag, limited_edition AS valor, COUNT(*) FROM staging_products GROUP BY limited_edition
UNION ALL
SELECT 'new',               new,               COUNT(*) FROM staging_products GROUP BY new
UNION ALL
SELECT 'online_only',       online_only,       COUNT(*) FROM staging_products GROUP BY online_only
UNION ALL
SELECT 'out_of_stock',      out_of_stock,      COUNT(*) FROM staging_products GROUP BY out_of_stock
UNION ALL
SELECT 'sephora_exclusive', sephora_exclusive, COUNT(*) FROM staging_products GROUP BY sephora_exclusive
ORDER BY 1, 2;

-- A7. Brands: does each brand_id have only one name? (for the brand table)
SELECT brand_id, COUNT(DISTINCT brand_name) AS nombres_distintos
FROM staging_products
GROUP BY brand_id
HAVING COUNT(DISTINCT brand_name) > 1;

-- A8. Number of distinct brands
SELECT COUNT(DISTINCT brand_id) AS marcas
FROM staging_products;

-- A9. Category combinations (future rows of the category table)
SELECT primary_category, secondary_category, tertiary_category, COUNT(*) AS productos
FROM staging_products
GROUP BY primary_category, secondary_category, tertiary_category
ORDER BY primary_category, secondary_category, tertiary_category;

-- A10. Format of highlights (to split it into the highlight table)
SELECT highlights
FROM staging_products
WHERE highlights IS NOT NULL
LIMIT 10;

-- A11. Distinct highlights (future rows of the highlight table)
SELECT btrim(h, ' ''"') AS highlight,
       COUNT(*)         AS productos
FROM staging_products,
     regexp_split_to_table(btrim(highlights, '[]'), '[''"]\s*,\s*[''"]') AS h
WHERE highlights IS NOT NULL
GROUP BY 1
ORDER BY productos DESC;

-- =====================================================================
-- PART B: REVIEWS (staging_reviews)  -  Itsaso Begiristain
-- =====================================================================

-- B1. Number of rows (the 5 files together)
SELECT COUNT(*) AS total_reviews
FROM staging_reviews;

-- B2. NULL (or empty) values per column
SELECT
  COUNT(*) FILTER (WHERE NULLIF(author_id, '')       IS NULL) AS null_author_id,
  COUNT(*) FILTER (WHERE NULLIF(rating, '')          IS NULL) AS null_rating,
  COUNT(*) FILTER (WHERE NULLIF(is_recommended, '')  IS NULL) AS null_is_recommended,
  COUNT(*) FILTER (WHERE NULLIF(helpfulness, '')     IS NULL) AS null_helpfulness,
  COUNT(*) FILTER (WHERE NULLIF(submission_time, '') IS NULL) AS null_submission_time,
  COUNT(*) FILTER (WHERE NULLIF(review_text, '')     IS NULL) AS null_review_text,
  COUNT(*) FILTER (WHERE NULLIF(review_title, '')    IS NULL) AS null_review_title,
  COUNT(*) FILTER (WHERE NULLIF(skin_tone, '')       IS NULL) AS null_skin_tone,
  COUNT(*) FILTER (WHERE NULLIF(eye_color, '')       IS NULL) AS null_eye_color,
  COUNT(*) FILTER (WHERE NULLIF(skin_type, '')       IS NULL) AS null_skin_type,
  COUNT(*) FILTER (WHERE NULLIF(hair_color, '')      IS NULL) AS null_hair_color,
  COUNT(*) FILTER (WHERE NULLIF(product_id, '')      IS NULL) AS null_product_id
FROM staging_reviews;

-- B3. Rating values (should be 1 to 5)
SELECT rating, COUNT(*)
FROM staging_reviews
GROUP BY rating
ORDER BY rating;

-- B4. Dates: format and range
SELECT MIN(submission_time::DATE) AS primera_review,
       MAX(submission_time::DATE) AS ultima_review
FROM staging_reviews;

-- B4b. Dates with an unexpected format (not YYYY-MM-DD)
SELECT COUNT(*) AS fechas_formato_raro
FROM staging_reviews
WHERE submission_time !~ '^\d{4}-\d{2}-\d{2}$';

-- B5. Is author_id always a number? (decides BIGINT or VARCHAR)
SELECT COUNT(*) AS author_id_no_numerico
FROM staging_reviews
WHERE author_id !~ '^\d+$';

-- B5b. Detail of the non-numeric author_id values
SELECT author_id, COUNT(*) AS reviews
FROM staging_reviews
WHERE author_id !~ '^\d+$'
GROUP BY author_id
ORDER BY reviews DESC;

-- B6. Exact duplicate rows
SELECT COUNT(*) - COUNT(DISTINCT (author_id, product_id, submission_time, review_text, rating))
       AS reviews_duplicadas
FROM staging_reviews;

-- B7. Does an author review the same product more than once?
--     (justifies a SERIAL review_id instead of a composite PK)
SELECT COUNT(*) AS pares_autor_producto_repetidos
FROM (
    SELECT author_id, product_id
    FROM staging_reviews
    GROUP BY author_id, product_id
    HAVING COUNT(*) > 1
) t;

-- B7b. The same pairs, but only when the reviews are really different
SELECT COUNT(*) AS pares_con_reviews_distintas
FROM (
    SELECT author_id, product_id
    FROM staging_reviews
    GROUP BY author_id, product_id
    HAVING COUNT(DISTINCT (submission_time, review_text, rating)) > 1
) t;

-- B8. Reviews whose product_id does NOT exist in products (the FK would fail)
SELECT COUNT(*) AS reviews_huerfanas
FROM staging_reviews r
WHERE NOT EXISTS (
    SELECT 1 FROM staging_products p WHERE p.product_id = r.product_id
);

-- B9. Is pos + neg = total in the feedback votes? (decides the CHECK)
SELECT COUNT(*) AS votos_inconsistentes
FROM staging_reviews
WHERE total_pos_feedback_count::INT + total_neg_feedback_count::INT
      <> total_feedback_count::INT;

-- B10. Range of helpfulness (should be between 0 and 1)
SELECT MIN(helpfulness::NUMERIC) AS helpfulness_min,
       MAX(helpfulness::NUMERIC) AS helpfulness_max
FROM staging_reviews;

-- B11. Do the skin attributes of an author change between reviews?
--      (decides whether they go in the author table or in review)
SELECT COUNT(*) AS autores_con_atributos_distintos
FROM (
    SELECT author_id
    FROM staging_reviews
    GROUP BY author_id
    HAVING COUNT(DISTINCT skin_type) > 1
        OR COUNT(DISTINCT skin_tone) > 1
        OR COUNT(DISTINCT eye_color) > 1
        OR COUNT(DISTINCT hair_color) > 1
) t;

-- B12. Number of distinct authors
SELECT COUNT(DISTINCT author_id) AS autores
FROM staging_reviews;

-- B13. Values of skin_type (for the CHECK of the review table)
SELECT skin_type, COUNT(*)
FROM staging_reviews
GROUP BY skin_type
ORDER BY COUNT(*) DESC;

-- B14. Redundant columns: does the price in the review match the product price?
SELECT COUNT(*) AS precio_no_coincide
FROM staging_reviews r
JOIN staging_products p ON p.product_id = r.product_id
WHERE r.price_usd::NUMERIC <> p.price_usd::NUMERIC;

-- B15. Reviews per primary category (are there only Skincare reviews?)
SELECT p.primary_category, COUNT(*) AS reviews
FROM staging_reviews r
JOIN staging_products p ON p.product_id = r.product_id
GROUP BY p.primary_category
ORDER BY reviews DESC;
