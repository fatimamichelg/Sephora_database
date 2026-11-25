# Effort Log – Project B: Sephora Database

**Team:** Fatima Michel · Itsaso Begiristain
**Course:** Information Technology
**Dataset:** Sephora Products and Skincare Reviews (Kaggle, nadyinky, CC BY 4.0)

## Who did what

| Area | Fatima Michel | Itsaso Begiristain |
|---|---|---|
| Dataset selection | ✔ | ✔ |
| Data profiling (`profiling.sql`) | ✔ | |
| Relational design and normalization (1NF / 2NF / 3NF) | ✔ | ✔ |
| Physical schema and constraints (`schema.sql`, `verify_constraints.sql`) | ✔ | |
| Staging load (`load_staging.sql`) | ✔ | |
| ETL in one transaction (`etl/load.py`), cleaning log and rollback demo | | ✔ |
| Queries Q1–Q5, Part A: Products & brands (advanced: **Q3, Q4**) | ✔ | |
| Queries Q6–Q10, Part B: Reviews & customers (advanced: **Q7, Q8, Q10**) | | ✔ |
| Streamlit app (`app/`) | ✔ | ✔ |
| Report | ✔ | ✔ |
| Presentation and live demo | ✔ | ✔ |

## Timeline

| Date | Member | Task |
|---|---|---|
| Nov 6 | Both | Chose the dataset and sent it to the professor |
| Nov 16 | Fatima | Repo structure, `download_data.py`, staging tables, COPY load |
| Nov 16 | Fatima | Profiling queries A1–A11 and B1–B15 |
| Nov 16 | Both | Relational model in 3NF (7 tables) and the ER diagram |
| Nov 16 | Fatima | `schema.sql` (58 constraints) |
| Nov 16 | Itsaso | ETL in one transaction (`load.py`), cleaning log, rollback demo |
| Nov 17–18 | Fatima | Queries Q1–Q5 |
| Nov 17–18 | Itsaso | Queries Q6–Q10 |
| Nov 18 | Both | Streamlit app: 2 tabs, charts fed only by SQL, parameterized filters |
| Nov 20 | Both | Report sections 1–6, screenshots, README |
| Nov 25 | Both | Section 7 (AI adoption), presentation slides |

## Use of AI

We used Claude as a tutor and assistant to plan the project, review SQL and Python code, and explain errors.
All queries were run and checked by us in pgAdmin, and every number in the report comes from our own SQL results.
Details are in section 7 of the report.
