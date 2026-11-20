-- =====================================================================
-- verify_constraints.sql  -  Project B: Sephora database
-- Run AFTER etl/load.py to show that every constraint created by
-- sql/schema.sql still exists once the data is loaded.
-- Run each query separately in pgAdmin (Sephora database).
-- =====================================================================


-- ---------------------------------------------------------------------
-- V1. Full list of constraints of the 7 final tables
--     Expected: 58 rows
-- ---------------------------------------------------------------------
SELECT conrelid::regclass         AS tabla,
       conname                    AS restriccion,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                    WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'u' THEN 'UNIQUE'
                    WHEN 'c' THEN 'CHECK'
                    WHEN 'n' THEN 'NOT NULL' END AS tipo,
       pg_get_constraintdef(oid)  AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid::regclass::text NOT LIKE 'staging%'
ORDER BY tabla, tipo;


-- ---------------------------------------------------------------------
-- V2. Summary: number of constraints of each type
--     Expected: NOT NULL 24, CHECK 18, PRIMARY KEY 7, FOREIGN KEY 6,
--               UNIQUE 3  (58 in total)
-- ---------------------------------------------------------------------
SELECT CASE contype WHEN 'p' THEN 'PRIMARY KEY'
                    WHEN 'f' THEN 'FOREIGN KEY'
                    WHEN 'u' THEN 'UNIQUE'
                    WHEN 'c' THEN 'CHECK'
                    WHEN 'n' THEN 'NOT NULL' END AS tipo,
       COUNT(*) AS restricciones
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid::regclass::text NOT LIKE 'staging%'
GROUP BY tipo
ORDER BY restricciones DESC;