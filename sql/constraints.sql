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