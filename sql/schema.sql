-- =====================================================================
-- schema.sql  -  Project B: Sephora database
-- Crea el esquema final (7 tablas) con todas sus restricciones.
-- Cada decision esta justificada por un resultado del profiling (A# / B#).
-- El ETL (load.py) solo inserta filas: NO crea ni modifica tablas.
--
-- Ejecutar en pgAdmin conectado a la base de datos "Sephora".
-- =====================================================================

-- Borrar en orden inverso a las FK para poder re-ejecutar el script
DROP TABLE IF EXISTS review;
DROP TABLE IF EXISTS author;
DROP TABLE IF EXISTS product_highlight;
DROP TABLE IF EXISTS highlight;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS brand;


-- ---------------------------------------------------------------------
-- BRAND  (3NF: product_id -> brand_id -> brand_name)
-- A7: cada brand_id tiene un solo nombre. A8: 304 marcas.
-- ---------------------------------------------------------------------
CREATE TABLE brand (
    brand_id    INT           PRIMARY KEY,
    brand_name  VARCHAR(100)  NOT NULL UNIQUE          -- clave candidata (BCNF)
);


-- ---------------------------------------------------------------------
-- CATEGORY  (opcion B: una fila por combinacion de 3 niveles)
-- A9: 174 combinaciones; secondary/tertiary pueden ser NULL.
-- Excepcion justificada: los niveles superiores se repiten entre filas.
-- ---------------------------------------------------------------------
CREATE TABLE category (
    category_id         SERIAL       PRIMARY KEY,
    primary_category    VARCHAR(50)  NOT NULL,
    secondary_category  VARCHAR(50),
    tertiary_category   VARCHAR(50),
    -- NULLS NOT DISTINCT: dos filas con los mismos niveles y NULL cuentan como repetidas
    CONSTRAINT uq_category UNIQUE NULLS NOT DISTINCT
        (primary_category, secondary_category, tertiary_category)
);


-- ---------------------------------------------------------------------
-- PRODUCT
-- A2: product_id unico (8.494). A3: sin nulos en id, nombre, marca, precio.
-- A4: precio 3-1.900, rating 1-5. A5: ninguna oferta > precio. A6: flags 0/1.
-- ---------------------------------------------------------------------
CREATE TABLE product (
    product_id         VARCHAR(15)    PRIMARY KEY,   -- max real 11
    product_name       VARCHAR(255)   NOT NULL,   -- max real 107
    brand_id           INT            NOT NULL REFERENCES brand(brand_id),
    category_id        INT            NOT NULL REFERENCES category(category_id),

    loves_count        INT            CHECK (loves_count >= 0),
    rating             NUMERIC(5,4)   CHECK (rating BETWEEN 1 AND 5),      -- NULL = sin reseñas
    reviews_count      INT            CHECK (reviews_count >= 0),

    size               VARCHAR(100),   -- max real 65
    variation_type     VARCHAR(50),    -- max real 34
    variation_value    VARCHAR(150),   -- max real 82
    variation_desc     TEXT,
    ingredients        TEXT,          -- excepcion justificada: lista irregular, no se separa

    price_usd          NUMERIC(8,2)   NOT NULL CHECK (price_usd > 0),
    value_price_usd    NUMERIC(8,2)   CHECK (value_price_usd >= 0),        -- 95 % NULL; 2 productos con 0.00 en el CSV
    sale_price_usd     NUMERIC(8,2)   CHECK (sale_price_usd > 0),          -- 97 % NULL

    limited_edition    BOOLEAN        NOT NULL,
    is_new             BOOLEAN        NOT NULL,   -- "new" en el CSV (palabra reservada)
    online_only        BOOLEAN        NOT NULL,
    out_of_stock       BOOLEAN        NOT NULL,
    sephora_exclusive  BOOLEAN        NOT NULL,

    child_count        INT            CHECK (child_count >= 0),
    child_min_price    NUMERIC(8,2)   CHECK (child_min_price > 0),
    child_max_price    NUMERIC(8,2)   CHECK (child_max_price > 0),

    CONSTRAINT chk_sale_le_price   CHECK (sale_price_usd <= price_usd),
    CONSTRAINT chk_child_min_max   CHECK (child_min_price <= child_max_price)
);


-- ---------------------------------------------------------------------
-- HIGHLIGHT + PRODUCT_HIGHLIGHT  (1NF: la columna highlights era una lista)
-- A11: 112 highlights distintos. Relacion N:N -> tabla intermedia.
-- ---------------------------------------------------------------------
CREATE TABLE highlight (
    highlight_id  SERIAL        PRIMARY KEY,
    name          VARCHAR(255)  NOT NULL UNIQUE
);

CREATE TABLE product_highlight (
    product_id    VARCHAR(15)  REFERENCES product(product_id) ON DELETE CASCADE,
    highlight_id  INT          REFERENCES highlight(highlight_id) ON DELETE CASCADE,
    PRIMARY KEY (product_id, highlight_id)
);


-- ---------------------------------------------------------------------
-- AUTHOR
-- B5: 64 reseñas con author_id no numerico ('orderGen...', 'dummyUser')
--     -> VARCHAR en lugar de BIGINT.
-- B11: 22.503 de 503.216 autores cambian de atributos -> los atributos
--      de piel NO van aqui, van en review.
-- ---------------------------------------------------------------------
CREATE TABLE author (
    author_id  VARCHAR(20)  PRIMARY KEY
);


-- ---------------------------------------------------------------------
-- REVIEW  (tabla grande: ~1,09 M filas)
-- B7: un autor reseña el mismo producto varias veces (4.586 pares con
--     reseñas distintas) -> clave sustituta review_id, no PK compuesta.
-- B8: 0 huerfanas -> FK a product sin descartar filas.
-- B3: rating 1-5. B4: fechas validas 2008-2023. B9: pos+neg=total siempre.
-- B10: helpfulness 0-1. B13: skin_type solo 4 valores.
-- B14: product_name, brand_name y price_usd del CSV de reviews son
--      redundantes (2NF) -> no se guardan aqui.
-- ---------------------------------------------------------------------
CREATE TABLE review (
    review_id                 SERIAL        PRIMARY KEY,
    author_id                 VARCHAR(20)   NOT NULL REFERENCES author(author_id),
    product_id                VARCHAR(15)   NOT NULL REFERENCES product(product_id),

    rating                    SMALLINT      NOT NULL CHECK (rating BETWEEN 1 AND 5),
    is_recommended            BOOLEAN,
    helpfulness               NUMERIC(7,6)  CHECK (helpfulness BETWEEN 0 AND 1),
    total_feedback_count      INT           CHECK (total_feedback_count >= 0),
    total_pos_feedback_count  INT           CHECK (total_pos_feedback_count >= 0),
    total_neg_feedback_count  INT           CHECK (total_neg_feedback_count >= 0),
    submission_time           DATE          NOT NULL,

    review_title              VARCHAR(100),   -- max real 50
    review_text               TEXT,

    -- perfil declarado por el autor en el momento de la reseña (B11)
    skin_type                 VARCHAR(20)   CHECK (skin_type IN ('combination', 'dry', 'normal', 'oily')),
    skin_tone                 VARCHAR(20),
    eye_color                 VARCHAR(20),
    hair_color                VARCHAR(20),

    CONSTRAINT chk_feedback_sum CHECK (
        total_pos_feedback_count + total_neg_feedback_count = total_feedback_count
    )
);
