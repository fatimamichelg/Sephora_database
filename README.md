# Sephora database – Project B

Relational database built from the Kaggle dataset
[Sephora Products and Skincare Reviews](https://www.kaggle.com/datasets/nadyinky/sephora-products-and-skincare-reviews)
(nadyinky, CC BY 4.0): 8,494 products and 1,094,411 reviews, loaded into
PostgreSQL, queried with SQL and shown in a Streamlit app.

**Team:** Fatima Michel · Itsaso Berigistain
**Course:** Information Technology – Project B

---

## Repository structure

```
Sephora_database/
├── download_data.py          # downloads the raw CSV files from Kaggle into data/
├── data/                     # raw CSV files (NOT committed, see .gitignore)
├── sql/
│   ├── load_staging.sql      # 1. raw CSVs -> staging tables (all TEXT), for profiling
│   ├── profiling.sql         # 2. data profile (queries A1–A12, B1–B15)
│   ├── schema.sql            # 3. final schema: 7 tables and all constraints
│   ├── verify_constraints.sql# 5. checks that the constraints exist after the load
│   └── queries.sql           # 6. the 10 SQL queries of the report
├── etl/
│   ├── load.py               # 4. ETL: CSV -> final tables, in one transaction
│   └── cleaning_log.md       # rows affected by each cleaning rule (written by load.py)
├── app/
│   ├── streamlit_app.py      # 7. visualization app
│   └── queries.py            # the 10 queries used by the app, with parameters
├── .streamlit/config.toml    # colours of the app
├── EFFORT_LOG.md             # what each member did
└── README.md
```

---

## Requirements

- PostgreSQL (we used version 18) and pgAdmin
- Python 3.10 or newer
- A Kaggle account (to download the data)

Install the Python packages:

```bash
python3 -m pip install kagglehub psycopg2-binary streamlit pandas
```

---

## How to run it, step by step

All commands are run from the project folder:

```bash
cd Sephora_database
```

### Step 1 – Download the data

```bash
python3 download_data.py
```

This creates the folder `data/` with `product_info.csv` and the 5 `reviews_*.csv` files.
The first time, kagglehub may ask you to log in to Kaggle.

### Step 2 – Create the database

In pgAdmin, create an empty database called **Sephora**
(right click on *Databases* → *Create* → *Database…*).

### Step 3 – Load the raw data into staging tables (for profiling only)

PostgreSQL cannot read files on the Desktop, so first copy the CSVs to `/tmp`:

```bash
cp data/*.csv /tmp/
```

Then, in pgAdmin, open a Query Tool on **Sephora** and run `sql/load_staging.sql`.
Expected result: 8,494 products and 1,094,411 reviews.

### Step 4 – Profile the raw data

Run the queries of `sql/profiling.sql` **one by one** (select a query and press F5).
Part A profiles the products and part B the reviews. These are the results in
section 2 of the report.

### Step 5 – Create the final schema

Run `sql/schema.sql` in the Query Tool of **Sephora**.
It creates the 7 empty tables with all their constraints
(brand, category, product, highlight, product_highlight, author, review).

### Step 6 – Load the data with the ETL

```bash
python3 etl/load.py
```

It asks for the PostgreSQL password (user `postgres`) and loads everything in
**one transaction**. It takes a few minutes. At the end it prints `COMMIT` and the
rows affected by each cleaning rule, and writes them to `etl/cleaning_log.md`.
Expected result: 8,494 products and 1,093,895 reviews.

**Rollback demonstration:**

```bash
python3 etl/load.py --demo-rollback
```

It loads everything and then inserts a review with `rating = 9`. The CHECK
constraint rejects it, the whole transaction rolls back, and the database keeps
its previous data (`SELECT COUNT(*) FROM review;` still returns 1,093,895).

### Step 7 – Check the constraints after the load

Run `sql/verify_constraints.sql` in pgAdmin:
- **V1** lists all the constraints (58 rows).
- **V2** counts them by type: 24 NOT NULL, 18 CHECK, 7 PRIMARY KEY, 6 FOREIGN KEY, 3 UNIQUE.

### Step 8 – Run the 10 queries

Run the queries of `sql/queries.sql` one by one in pgAdmin.
**Query 10** is a transaction: run its statements one at a time, in the same tab
(`BEGIN` → first SELECT → UPDATE → second SELECT → `ROLLBACK`).

### Step 9 – Start the visualization app

```bash
PGPASSWORD=your_password python3 -m streamlit run app/streamlit_app.py
```

Replace `your_password` with the PostgreSQL password. The app opens at
<http://localhost:8501>. Stop it with **Ctrl + C**.

The app only reads the database (read-only session). Every chart comes from one
of the 10 queries, and every filter is sent to PostgreSQL as a parameter.

---

## Database connection

The scripts and the app use these settings:

| Setting  | Value       |
|----------|-------------|
| host     | `localhost` |
| port     | `5432`      |
| database | `Sephora`   |
| user     | `postgres`  |
| password | asked by `load.py`; given with `PGPASSWORD` to the app |

The password is never written in the code.
