# Cleaning log (written by etl/load.py)

| Rule / step | Rows affected |
|---|---|
| product_info.csv: rows read | 8,494 |
| highlights: list split into rows (1NF) | 6,287 |
| flags 0/1 -> BOOLEAN (cells) | 42,470 |
| brand: rows inserted | 304 |
| category: rows inserted | 174 |
| product: rows inserted | 8,494 |
| highlight: rows inserted | 112 |
| product_highlight: rows inserted | 30,204 |
| reviews_*.csv: rows read | 1,094,411 |
| is_recommended 1.0/0.0 -> BOOLEAN (cells) | 926,077 |
| exact duplicate reviews (removed) | 516 |
| author: rows inserted | 503,216 |
| review: rows inserted | 1,093,895 |
| unnamed column (index) dropped: rows | 1,094,411 |
| redundant product_name/brand_name/price_usd dropped: rows | 1,094,411 |
