-- =====================================================================
-- schema.sql  -  Project B: Sephora database
-- Creates the final schema (7 tables) with all its constraints.
-- Each decision is justified by a profiling result (A# / B#).
-- The ETL (load.py) only inserts rows: it does NOT create or change tables.
--
-- Run in pgAdmin, connected to the "Sephora" database.
-- =====================================================================

-- Drop in reverse FK order so the script can be re-run
DROP TABLE IF EXISTS review;
DROP TABLE IF EXISTS author;
DROP TABLE IF EXISTS product_highlight;
DROP TABLE IF EXISTS highlight;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS brand;


-- ---------------------------------------------------------------------
-- BRAND  (3NF: product_id -> brand_id -> brand_name)
-- A7: each brand_id has only one name. A8: 304 brands.
-- ---------------------------------------------------------------------
CREATE TABLE brand (
    brand_id    INT           PRIMARY KEY,
    brand_name  VARCHAR(100)  NOT NULL UNIQUE          -- candidate key (BCNF)
);


-- ---------------------------------------------------------------------
-- CATEGORY  (option B: one row per combination of the 3 levels)
-- A9: 174 combinations; secondary/tertiary can be NULL.
-- Justified exception: the upper levels repeat between rows.
-- ---------------------------------------------------------------------
CREATE TABLE category (
    category_id         SERIAL       PRIMARY KEY,
    primary_category    VARCHAR(50)  NOT NULL,
    secondary_category  VARCHAR(50),
    tertiary_category   VARCHAR(50),
    -- NULLS NOT DISTINCT: two rows with the same levels and NULLs count as repeated
    CONSTRAINT uq_category UNIQUE NULLS NOT DISTINCT
        (primary_category, secondary_category, tertiary_category)
);


-- ---------------------------------------------------------------------
-- PRODUCT
-- A2: product_id is unique (8,494). A3: no NULLs in id, name, brand, price.
-- A4: price 3-1,900, rating 1-5. A5: no sale price > price. A6: flags 0/1.
-- ---------------------------------------------------------------------
CREATE TABLE product (
    product_id         VARCHAR(15)    PRIMARY KEY,   -- real max 11
    product_name       VARCHAR(255)   NOT NULL,   -- real max 107
    brand_id           INT            NOT NULL REFERENCES brand(brand_id),
    category_id        INT            NOT NULL REFERENCES category(category_id),

    loves_count        INT            CHECK (loves_count >= 0),
    rating             NUMERIC(5,4)   CHECK (rating BETWEEN 1 AND 5),      -- NULL = no reviews
    reviews_count      INT            CHECK (reviews_count >= 0),

    size               VARCHAR(100),   -- real max 65
    variation_type     VARCHAR(50),    -- real max 34
    variation_value    VARCHAR(150),   -- real max 82
    variation_desc     TEXT,
    ingredients        TEXT,          -- justified exception: irregular list, not split

    price_usd          NUMERIC(8,2)   NOT NULL CHECK (price_usd > 0),
    value_price_usd    NUMERIC(8,2)   CHECK (value_price_usd >= 0),        -- 95 % NULL; 2 products with 0.00 in the CSV
    sale_price_usd     NUMERIC(8,2)   CHECK (sale_price_usd > 0),          -- 97 % NULL

    limited_edition    BOOLEAN        NOT NULL,
    is_new             BOOLEAN        NOT NULL,   -- "new" in the CSV (reserved word)
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
-- HIGHLIGHT + PRODUCT_HIGHLIGHT  (1NF: the highlights column was a list)
-- A11: 112 distinct highlights. N:N relationship -> junction table.
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
-- B5: 64 reviews with a non-numeric author_id ('orderGen...', 'dummyUser')
--     -> VARCHAR instead of BIGINT.
-- B11: 22,503 of 503,216 authors change attributes -> the skin
--      attributes do NOT go here, they go in review.
-- ---------------------------------------------------------------------
CREATE TABLE author (
    author_id  VARCHAR(20)  PRIMARY KEY
);


-- ---------------------------------------------------------------------
-- REVIEW  (large table: ~1.09 M rows)
-- B7: an author reviews the same product several times (4,586 pairs with
--     different reviews) -> surrogate key review_id, not a composite PK.
-- B8: 0 orphans -> FK to product without dropping rows.
-- B3: rating 1-5. B4: valid dates 2008-2023. B9: pos+neg=total always.
-- B10: helpfulness 0-1. B13: skin_type has only 4 values.
-- B14: product_name, brand_name and price_usd in the reviews CSV are
--      redundant (2NF) -> not stored here.
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

    review_title              VARCHAR(100),   -- real max 50
    review_text               TEXT,

    -- profile given by the author at the time of the review (B11)
    skin_type                 VARCHAR(20)   CHECK (skin_type IN ('combination', 'dry', 'normal', 'oily')),
    skin_tone                 VARCHAR(20),
    eye_color                 VARCHAR(20),
    hair_color                VARCHAR(20),

    CONSTRAINT chk_feedback_sum CHECK (
        total_pos_feedback_count + total_neg_feedback_count = total_feedback_count
    )
);
