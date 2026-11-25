"""
load.py - Project B: Sephora database  (ETL)

Reads the raw CSV files in data/, cleans their FORMATS and inserts them into
the 7 tables already created by sql/schema.sql. It does not create or change
tables, and it does not analyse data: all the analysis is done later in SQL.

- The whole load runs in ONE transaction: if anything fails -> ROLLBACK, nothing is left.
- Missing values stay NULL (they are never invented).
- Each cleaning rule counts the rows it affects; the counts are saved in
  etl/cleaning_log.md for the report.

Usage (from the Sephora_database folder):
    pip3 install psycopg2-binary
    python3 etl/load.py                  # normal load
    python3 etl/load.py --demo-rollback  # shows the rollback (loads nothing)
"""

import argparse
import ast
import csv
import getpass
import os
import sys
from collections import Counter
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path

import psycopg2
from psycopg2.extras import execute_values

ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = ROOT / "data"
LOG_FILE = Path(__file__).resolve().parent / "cleaning_log.md"

DB = {"host": "localhost", "port": 5432, "dbname": "Sephora", "user": "postgres"}

REVIEW_FILES = [
    "reviews_0-250.csv",
    "reviews_250-500.csv",
    "reviews_500-750.csv",
    "reviews_750-1250.csv",
    "reviews_1250-end.csv",
]

BATCH = 10_000
csv.field_size_limit(sys.maxsize)          # some reviews are very long

# Counter of cleaning rules: rule -> rows affected
log = Counter()


# ---------------------------------------------------------------------
# Format conversion functions (CSV text -> PostgreSQL type)
# An empty cell returns None (= NULL). They never invent values.
# ---------------------------------------------------------------------
def clean(value):
    """Empty text or only spaces -> None."""
    if value is None:
        return None
    value = value.strip()
    return value if value != "" else None


def to_int(value, rule=None):
    """'11' o '11.0' (pandas writes integers as floats) -> 11."""
    value = clean(value)
    if value is None:
        return None
    if value.endswith(".0"):
        if rule:
            log[rule] += 1
        value = value[:-2]
    return int(value)


def to_decimal(value):
    value = clean(value)
    if value is None:
        return None
    try:
        return Decimal(value)
    except InvalidOperation:
        raise ValueError(f"Invalid number: {value!r}")


def to_bool(value, rule=None):
    """'1' / '1.0' -> True, '0' / '0.0' -> False, empty -> None."""
    value = clean(value)
    if value is None:
        return None
    if rule:
        log[rule] += 1
    if value in ("1", "1.0"):
        return True
    if value in ("0", "0.0"):
        return False
    raise ValueError(f"Invalid boolean value: {value!r}")


def to_date(value):
    value = clean(value)
    if value is None:
        return None
    return date.fromisoformat(value[:10])


def parse_highlights(value):
    """"['Vegan', "allure 2018 Readers' Choice"]" -> Python list.
    ast.literal_eval understands single and double quotes (finding A11)."""
    value = clean(value)
    if value is None:
        return []
    items = ast.literal_eval(value)
    return [item.strip() for item in items if item and item.strip()]


def read_csv(name):
    with open(DATA_DIR / name, newline="", encoding="utf-8") as f:
        yield from csv.DictReader(f)


# ---------------------------------------------------------------------
# PRODUCTS: brand, category, product, highlight, product_highlight
# ---------------------------------------------------------------------
def load_products(cur):
    brands = {}                 # brand_id -> brand_name
    categories = set()          # (primary, secondary, tertiary)
    products = []
    product_highlights = []     # (product_id, highlight_name)

    for row in read_csv("product_info.csv"):
        log["product_info.csv: rows read"] += 1

        brand_id = to_int(row["brand_id"])
        brands[brand_id] = clean(row["brand_name"])

        cat = (clean(row["primary_category"]),
               clean(row["secondary_category"]),
               clean(row["tertiary_category"]))
        categories.add(cat)

        names = parse_highlights(row["highlights"])
        if names:
            log["highlights: list split into rows (1NF)"] += 1
        for name in names:
            product_highlights.append((clean(row["product_id"]), name))

        products.append({
            "product_id": clean(row["product_id"]),
            "product_name": clean(row["product_name"]),
            "brand_id": brand_id,
            "category": cat,
            "loves_count": to_int(row["loves_count"], "integers written as floats ('11.0' -> 11)"),
            "rating": to_decimal(row["rating"]),
            "reviews_count": to_int(row["reviews"], "integers written as floats ('11.0' -> 11)"),
            "size": clean(row["size"]),
            "variation_type": clean(row["variation_type"]),
            "variation_value": clean(row["variation_value"]),
            "variation_desc": clean(row["variation_desc"]),
            "ingredients": clean(row["ingredients"]),
            "price_usd": to_decimal(row["price_usd"]),
            "value_price_usd": to_decimal(row["value_price_usd"]),
            "sale_price_usd": to_decimal(row["sale_price_usd"]),
            "limited_edition": to_bool(row["limited_edition"], "flags 0/1 -> BOOLEAN (cells)"),
            "is_new": to_bool(row["new"], "flags 0/1 -> BOOLEAN (cells)"),
            "online_only": to_bool(row["online_only"], "flags 0/1 -> BOOLEAN (cells)"),
            "out_of_stock": to_bool(row["out_of_stock"], "flags 0/1 -> BOOLEAN (cells)"),
            "sephora_exclusive": to_bool(row["sephora_exclusive"], "flags 0/1 -> BOOLEAN (cells)"),
            "child_count": to_int(row["child_count"], "integers written as floats ('11.0' -> 11)"),
            "child_min_price": to_decimal(row["child_min_price"]),
            "child_max_price": to_decimal(row["child_max_price"]),
        })

    # brand
    execute_values(cur,
        "INSERT INTO brand (brand_id, brand_name) VALUES %s",
        sorted(brands.items()))
    log["brand: rows inserted"] = len(brands)

    # category: SERIAL creates the id; then we read it back to build the map
    execute_values(cur,
        "INSERT INTO category (primary_category, secondary_category, tertiary_category) VALUES %s",
        sorted(categories, key=lambda c: tuple(x or "" for x in c)))
    cur.execute("SELECT category_id, primary_category, secondary_category, tertiary_category FROM category")
    category_id = {(p, s, t): cid for cid, p, s, t in cur.fetchall()}
    log["category: rows inserted"] = len(categories)

    # product
    cols = ["product_id", "product_name", "brand_id", "category_id", "loves_count", "rating",
            "reviews_count", "size", "variation_type", "variation_value", "variation_desc",
            "ingredients", "price_usd", "value_price_usd", "sale_price_usd", "limited_edition",
            "is_new", "online_only", "out_of_stock", "sephora_exclusive", "child_count",
            "child_min_price", "child_max_price"]
    rows = []
    for p in products:
        p["category_id"] = category_id[p["category"]]
        rows.append(tuple(p[c] for c in cols))
    execute_values(cur, f"INSERT INTO product ({', '.join(cols)}) VALUES %s", rows)
    log["product: rows inserted"] = len(rows)

    # highlight + product_highlight
    names = sorted({name for _, name in product_highlights})
    execute_values(cur, "INSERT INTO highlight (name) VALUES %s", [(n,) for n in names])
    cur.execute("SELECT highlight_id, name FROM highlight")
    highlight_id = {name: hid for hid, name in cur.fetchall()}
    log["highlight: rows inserted"] = len(names)

    pairs = sorted({(pid, highlight_id[name]) for pid, name in product_highlights})
    if len(pairs) < len(product_highlights):
        log["highlights repeated in the same product (removed)"] = len(product_highlights) - len(pairs)
    execute_values(cur, "INSERT INTO product_highlight (product_id, highlight_id) VALUES %s", pairs)
    log["product_highlight: rows inserted"] = len(pairs)


# ---------------------------------------------------------------------
# REVIEWS: author, review  (in batches, so 1 M rows are not kept in memory)
# ---------------------------------------------------------------------
REVIEW_COLS = ["author_id", "product_id", "rating", "is_recommended", "helpfulness",
               "total_feedback_count", "total_pos_feedback_count", "total_neg_feedback_count",
               "submission_time", "review_title", "review_text",
               "skin_type", "skin_tone", "eye_color", "hair_color"]


def load_reviews(cur):
    seen_reviews = set()        # to detect exact duplicates (finding B6)
    seen_authors = set()
    batch_reviews, batch_authors = [], []

    def flush():
        if batch_authors:
            execute_values(cur, "INSERT INTO author (author_id) VALUES %s", batch_authors)
        if batch_reviews:
            execute_values(cur,
                f"INSERT INTO review ({', '.join(REVIEW_COLS)}) VALUES %s",
                batch_reviews, page_size=BATCH)
        batch_authors.clear()
        batch_reviews.clear()

    for name in REVIEW_FILES:
        print(f"  {name} ...", flush=True)
        for row in read_csv(name):
            log["reviews_*.csv: rows read"] += 1

            # Rule: exact duplicates (same author, product, date, text and rating)
            key = hash((row["author_id"], row["product_id"], row["submission_time"],
                        row["review_text"], row["rating"]))
            if key in seen_reviews:
                log["exact duplicate reviews (removed)"] += 1
                continue
            seen_reviews.add(key)

            author_id = clean(row["author_id"])
            if author_id not in seen_authors:
                seen_authors.add(author_id)
                batch_authors.append((author_id,))

            # Rules that do not need a row-by-row count:
            # - unnamed column (pandas index) dropped
            # - product_name, brand_name, price_usd dropped (redundant, 2NF)
            batch_reviews.append((
                author_id,
                clean(row["product_id"]),
                to_int(row["rating"]),
                to_bool(row["is_recommended"], "is_recommended 1.0/0.0 -> BOOLEAN (celdas)"),
                to_decimal(row["helpfulness"]),
                to_int(row["total_feedback_count"]),
                to_int(row["total_pos_feedback_count"]),
                to_int(row["total_neg_feedback_count"]),
                to_date(row["submission_time"]),
                clean(row["review_title"]),
                clean(row["review_text"]),
                clean(row["skin_type"]),
                clean(row["skin_tone"]),
                clean(row["eye_color"]),
                clean(row["hair_color"]),
            ))

            if len(batch_reviews) >= BATCH:
                flush()
    flush()

    log["author: rows inserted"] = len(seen_authors)
    log["review: rows inserted"] = len(seen_reviews)
    log["unnamed column (index) dropped: rows"] = log["reviews_*.csv: rows read"]
    log["redundant product_name/brand_name/price_usd dropped: rows"] = log["reviews_*.csv: rows read"]


# ---------------------------------------------------------------------
def write_log():
    lines = ["# Cleaning log (written by etl/load.py)", "",
             "| Rule / step | Rows affected |", "|---|---|"]
    for rule, n in log.items():
        lines.append(f"| {rule} | {n:,} |")
    LOG_FILE.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--demo-rollback", action="store_true",
                        help="inserts an invalid row at the end to show the ROLLBACK")
    args = parser.parse_args()

    password = os.environ.get("PGPASSWORD") or getpass.getpass("PostgreSQL password (postgres): ")
    conn = psycopg2.connect(password=password, **DB)
    conn.autocommit = False                     # everything in ONE transaction

    try:
        with conn.cursor() as cur:
            # Empty the tables (inside the same transaction) so the script can be re-run
            cur.execute("TRUNCATE review, author, product_highlight, highlight, "
                        "product, category, brand RESTART IDENTITY;")

            print("Loading products ...")
            load_products(cur)
            print("Loading reviews ...")
            load_reviews(cur)

            if args.demo_rollback:
                print("\nDEMO: inserting a review with rating = 9 (breaks the CHECK 1-5) ...")
                cur.execute("INSERT INTO review (author_id, product_id, rating, submission_time) "
                            "SELECT author_id, product_id, 9, submission_time FROM review LIMIT 1;")

        conn.commit()
        print("\nCOMMIT: load complete.")
        write_log()
        for rule, n in log.items():
            print(f"  {rule:<60} {n:>10,}")
        print(f"\nCleaning log saved in {LOG_FILE.relative_to(ROOT)}")

    except Exception as e:
        conn.rollback()
        print(f"\nERROR: {e}")
        print("ROLLBACK: NO rows were loaded (the database stays as it was).")
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
