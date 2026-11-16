# Cleaning log (generado por etl/load.py)

| Regla / paso | Filas afectadas |
|---|---|
| product_info.csv: filas leidas | 8,494 |
| highlights: lista separada en filas (1NF) | 6,287 |
| flags 0/1 -> BOOLEAN (celdas) | 42,470 |
| brand: filas insertadas | 304 |
| category: filas insertadas | 174 |
| product: filas insertadas | 8,494 |
| highlight: filas insertadas | 112 |
| product_highlight: filas insertadas | 30,204 |
| reviews_*.csv: filas leidas | 1,094,411 |
| is_recommended 1.0/0.0 -> BOOLEAN (celdas) | 926,077 |
| reseñas duplicadas exactas (eliminadas) | 516 |
| author: filas insertadas | 503,216 |
| review: filas insertadas | 1,093,895 |
| columna sin nombre (indice) descartada: filas | 1,094,411 |
| product_name/brand_name/price_usd redundantes descartadas: filas | 1,094,411 |
