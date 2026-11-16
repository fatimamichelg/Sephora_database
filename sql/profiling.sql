-- =====================================================================
-- PARTE A: PRODUCTOS (staging_products)  - FATIMA MICHEL
-- =====================================================================
-- A1. Numero de filas del archivo

SELECT COUNT(*) AS total_products
FROM staging_products;

-- A2. Clave candidata: ¿product_id es unico?
--     Si total = distintos -> es unico y puede ser PRIMARY KEY
SELECT COUNT(*)                   AS total_filas,
       COUNT(DISTINCT product_id) AS product_id_distintos
FROM staging_products;

-- A3. Nulos (o vacios) por columna
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

-- A4. Rangos de numeros: precio, rating, loves
SELECT MIN(price_usd::NUMERIC)   AS precio_min,
       MAX(price_usd::NUMERIC)   AS precio_max,
       MIN(rating::NUMERIC)      AS rating_min,
       MAX(rating::NUMERIC)      AS rating_max,
       MIN(loves_count::INT)     AS loves_min,
       MAX(loves_count::INT)     AS loves_max
FROM staging_products;

-- A5. Buscar outliers
SELECT COUNT(*) AS oferta_mayor_que_precio
FROM staging_products
WHERE sale_price_usd::NUMERIC > price_usd::NUMERIC;

-- A6. Valores de los flags (deberian ser solo 0 y 1)
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


-- A7. Marcas: ¿cada brand_id tiene un solo nombre? (para la tabla brand)
SELECT brand_id, COUNT(DISTINCT brand_name) AS nombres_distintos
FROM staging_products
GROUP BY brand_id
HAVING COUNT(DISTINCT brand_name) > 1;

-- A8. Numero de marcas distintas
SELECT COUNT(DISTINCT brand_id) AS marcas
FROM staging_products;

-- A9. Combinaciones de categorias (filas futuras de la tabla category)
SELECT primary_category, secondary_category, tertiary_category, COUNT(*) AS productos
FROM staging_products
GROUP BY primary_category, secondary_category, tertiary_category
ORDER BY primary_category, secondary_category, tertiary_category;

-- A10. Formato de highlights (para separarlo en la tabla highlight)
SELECT highlights
FROM staging_products
WHERE highlights IS NOT NULL
LIMIT 10;
-- A11. Highlights distintos (filas de la futura tabla highlight)
SELECT btrim(h, ' ''"') AS highlight,
       COUNT(*)         AS productos
FROM staging_products,
     regexp_split_to_table(btrim(highlights, '[]'), '[''"]\s*,\s*[''"]') AS h
WHERE highlights IS NOT NULL
GROUP BY 1
ORDER BY productos DESC;

-- =====================================================================
-- PARTE B: RESEÑAS (staging_reviews)  -  Itsaso
-- =====================================================================

-- B1. Numero de filas (los 5 archivos juntos)
SELECT COUNT(*) AS total_reviews
FROM staging_reviews;

-- B2. Nulos (o vacios) por columna
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

-- B3. Valores de rating (deberian ser 1 a 5)
SELECT rating, COUNT(*)
FROM staging_reviews
GROUP BY rating
ORDER BY rating;


-- B4. Fechas: formato y rango
SELECT MIN(submission_time::DATE) AS primera_review,
       MAX(submission_time::DATE) AS ultima_review
FROM staging_reviews;

-- B4b. Fechas con formato raro (no AAAA-MM-DD)
SELECT COUNT(*) AS fechas_formato_raro
FROM staging_reviews
WHERE submission_time !~ '^\d{4}-\d{2}-\d{2}$';

-- B5. ¿author_id es siempre un numero? (decide si usar BIGINT o VARCHAR)
SELECT COUNT(*) AS author_id_no_numerico
FROM staging_reviews
WHERE author_id !~ '^\d+$';

-- B6. Filas duplicadas exactas
SELECT COUNT(*) - COUNT(DISTINCT (author_id, product_id, submission_time, review_text, rating))
       AS reviews_duplicadas
FROM staging_reviews;


SELECT author_id, COUNT(*) AS reviews
FROM staging_reviews
WHERE author_id !~ '^\d+$'
GROUP BY author_id
ORDER BY reviews DESC;

-- B7. ¿Un autor reseña el mismo producto mas de una vez?
--     (justifica usar review_id SERIAL en vez de PK compuesta)
SELECT COUNT(*) AS pares_autor_producto_repetidos
FROM (
    SELECT author_id, product_id
    FROM staging_reviews
    GROUP BY author_id, product_id
    HAVING COUNT(*) > 1
) t;

SELECT COUNT(*) AS pares_con_reviews_distintas
FROM (
    SELECT author_id, product_id
    FROM staging_reviews
    GROUP BY author_id, product_id
    HAVING COUNT(DISTINCT (submission_time, review_text, rating)) > 1
) t;


-- B8. Reseñas cuyo product_id NO existe en productos (fallaria la FK)
SELECT COUNT(*) AS reviews_huerfanas
FROM staging_reviews r
WHERE NOT EXISTS (
    SELECT 1 FROM staging_products p WHERE p.product_id = r.product_id
);

-- B9. ¿pos + neg = total en los votos? (decide si poner el CHECK)
SELECT COUNT(*) AS votos_inconsistentes
FROM staging_reviews
WHERE total_pos_feedback_count::INT + total_neg_feedback_count::INT
      <> total_feedback_count::INT;

-- B10. Rango de helpfulness (deberia estar entre 0 y 1)
SELECT MIN(helpfulness::NUMERIC) AS helpfulness_min,
       MAX(helpfulness::NUMERIC) AS helpfulness_max
FROM staging_reviews;


-- B11. ¿Los atributos de piel de un autor cambian entre reseñas?
--      (decide si van en la tabla author o en review)
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


-- B12. Numero de autores distintos
SELECT COUNT(DISTINCT author_id) AS autores
FROM staging_reviews;


-- B13. Valores de skin_type (para el CHECK de la tabla author)
SELECT skin_type, COUNT(*)
FROM staging_reviews
GROUP BY skin_type
ORDER BY COUNT(*) DESC;


-- B14. Columnas redundantes: ¿el precio de la review coincide con el de producto?
SELECT COUNT(*) AS precio_no_coincide
FROM staging_reviews r
JOIN staging_products p ON p.product_id = r.product_id
WHERE r.price_usd::NUMERIC <> p.price_usd::NUMERIC;

-- B15. Reseñas por categoria principal (¿solo hay reseñas de Skincare?)
SELECT p.primary_category, COUNT(*) AS reviews
FROM staging_reviews r
JOIN staging_products p ON p.product_id = r.product_id
GROUP BY p.primary_category
ORDER BY reviews DESC;