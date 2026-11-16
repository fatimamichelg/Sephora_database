-- =====================================================================
-- load_staging.sql  -  Project B: Sephora database
-- Crea las tablas staging (todo TEXT, sin restricciones) y carga en ellas
-- los CSV en bruto para hacer el profiling con SQL.
--
-- ANTES de ejecutar, en la Terminal (dentro de Sephora_database):
--     cp data/*.csv /tmp/
-- (PostgreSQL no tiene permiso para leer el Escritorio; /tmp si)
--
-- Ejecutar en pgAdmin conectado a la base de datos "Sephora".
-- =====================================================================

-- 1. Crear las tablas staging (se borran si ya existian)
DROP TABLE IF EXISTS staging_products;
DROP TABLE IF EXISTS staging_reviews;

CREATE TABLE staging_products (
    product_id TEXT, product_name TEXT, brand_id TEXT, brand_name TEXT,
    loves_count TEXT, rating TEXT, reviews TEXT, size TEXT,
    variation_type TEXT, variation_value TEXT, variation_desc TEXT,
    ingredients TEXT, price_usd TEXT, value_price_usd TEXT, sale_price_usd TEXT,
    limited_edition TEXT, new TEXT, online_only TEXT, out_of_stock TEXT,
    sephora_exclusive TEXT, highlights TEXT,
    primary_category TEXT, secondary_category TEXT, tertiary_category TEXT,
    child_count TEXT, child_max_price TEXT, child_min_price TEXT
);

CREATE TABLE staging_reviews (
    row_index TEXT,            -- primera columna sin nombre del CSV (indice de pandas)
    author_id TEXT, rating TEXT, is_recommended TEXT, helpfulness TEXT,
    total_feedback_count TEXT, total_neg_feedback_count TEXT,
    total_pos_feedback_count TEXT, submission_time TEXT,
    review_text TEXT, review_title TEXT,
    skin_tone TEXT, eye_color TEXT, skin_type TEXT, hair_color TEXT,
    product_id TEXT, product_name TEXT, brand_name TEXT, price_usd TEXT
);

-- 2. Cargar los CSV
COPY staging_products FROM '/tmp/product_info.csv'     WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

COPY staging_reviews  FROM '/tmp/reviews_0-250.csv'    WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY staging_reviews  FROM '/tmp/reviews_250-500.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY staging_reviews  FROM '/tmp/reviews_500-750.csv'  WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY staging_reviews  FROM '/tmp/reviews_750-1250.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY staging_reviews  FROM '/tmp/reviews_1250-end.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');

-- 3. Comprobar (esperado: 8494 productos, 1094411 reviews)
SELECT (SELECT COUNT(*) FROM staging_products) AS productos,
       (SELECT COUNT(*) FROM staging_reviews)  AS reviews;