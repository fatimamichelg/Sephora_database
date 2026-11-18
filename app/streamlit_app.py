"""
streamlit_app.py - Project B: Sephora database (visualization layer)

Run (from the Sephora_database folder):
    python3 -m pip install streamlit psycopg2-binary
    PGPASSWORD=your_password python3 -m streamlit run app/streamlit_app.py
"""

import os
from datetime import date

import pandas as pd
import psycopg2
import streamlit as st

import queries as Q

st.set_page_config(page_title="Skincare explorer", page_icon="✨", layout="wide")

PINK = "#E8799E"
BLACK = "#111111"

st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,500;0,600;1,500&family=Montserrat:wght@300;400;500;600&display=swap');

html, body, [class*="css"], .stMarkdown, p, label, .stCaption { font-family: 'Montserrat', sans-serif; }
.block-container { padding-top: 0; max-width: 1150px; }

.hero { background: #111111; color: #FFFFFF; padding: 46px 40px 38px; margin: 0 -1rem 26px; text-align: center; }
.hero .kicker { font-family: 'Montserrat'; letter-spacing: .45em; font-size: 11px; color: #F4B6CB; text-transform: uppercase; margin: 0 0 12px; }
.hero h1 { font-family: 'Playfair Display', serif; font-weight: 500; font-size: 46px; color: #FFFFFF; margin: 0; letter-spacing: .02em; }
.hero p { font-family: 'Montserrat'; font-weight: 300; font-size: 14px; color: #D9D9D9; margin: 12px 0 0; letter-spacing: .04em; }
.hero .line { width: 60px; height: 2px; background: #E8799E; margin: 18px auto 0; }

.section-title { font-family: 'Playfair Display', serif; font-weight: 500; font-size: 28px; color: #111111;
                 margin: 38px 0 4px; padding-bottom: 8px; border-bottom: 1px solid #111111; }
.section-sub { font-family: 'Montserrat'; font-size: 13px; color: #6B6B6B; margin: 0 0 14px; letter-spacing: .02em; }

.stTabs [data-baseweb="tab-list"] { gap: 36px; justify-content: center; border-bottom: 1px solid #E5E5E5; }
.stTabs [data-baseweb="tab"] { font-family: 'Montserrat'; text-transform: uppercase; letter-spacing: .25em; font-size: 12px; color: #111111; }
.stTabs [aria-selected="true"] { color: #111111; font-weight: 600; }
.stTabs [data-baseweb="tab-highlight"] { background-color: #E8799E; }

.stExpander { border: 1px solid #EDEDED; border-radius: 0; }
[data-testid="stDataFrame"] { border: 1px solid #EDEDED; }
</style>
""", unsafe_allow_html=True)


def section(title, subtitle=None):
    st.markdown(f'<div class="section-title">{title}</div>', unsafe_allow_html=True)
    if subtitle:
        st.markdown(f'<div class="section-sub">{subtitle}</div>', unsafe_allow_html=True)



# ---------------------------------------------------------------------
# Database access
# ---------------------------------------------------------------------
@st.cache_resource
def get_connection():
    conn = psycopg2.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=os.environ.get("PGPORT", "5432"),
        dbname=os.environ.get("PGDATABASE", "Sephora"),
        user=os.environ.get("PGUSER", "postgres"),
        password=os.environ.get("PGPASSWORD", ""),
    )
    # The app only reads: a read-only session cannot modify the database
    conn.set_session(readonly=True, autocommit=True)
    return conn


def run_query(sql, params=None):
    """Send one query with its parameters and return the rows as a table.
    pd.DataFrame only wraps the rows for the chart; it does not compute anything."""
    try:
        with get_connection().cursor() as cur:
            cur.execute(sql, params)          # values are sent as parameters, never pasted into the SQL
            columns = [d.name for d in cur.description]
            return pd.DataFrame(cur.fetchall(), columns=columns)
    except psycopg2.Error as e:
        st.error(f"The database returned an error: {e.pgerror or e}")
        return pd.DataFrame()


def show_sql(sql, params):
    name = next((k for k, v in vars(Q).items() if v is sql), "")
    with st.expander(f"See the SQL · {name}"):
        st.code(sql.strip(), language="sql")
        st.caption(f"Parameters sent to PostgreSQL: {params}")


def empty_message(df):
    if df.empty:
        st.info("No rows for these filters. Try a lower minimum or another category.")
        return True
    return False


# ---------------------------------------------------------------------
# Header and connection check
# ---------------------------------------------------------------------
st.markdown("""
<div class="hero"><br>
  <div class="kicker">Beauty data · Project B</div>
  <h1>Skincare Explorer</h1>
  <p>8,494 products · 1.09 M customer reviews</p>
  <p>By Fatima Michel &amp; Itsaso Berigistain</p>
  <div class="line"></div><br>
</div>
""", unsafe_allow_html=True)

try:
    get_connection()
except psycopg2.Error as e:
    st.error("Could not connect to PostgreSQL. Check that the server is running and "
             "that PGPASSWORD is set when you start the app.")
    st.stop()

categories = run_query(Q.SKINCARE_CATEGORIES)["secondary_category"].tolist()
date_range = run_query(Q.REVIEW_DATE_RANGE)
if not categories or date_range.empty or date_range.iloc[0, 0] is None:
    st.error("The tables are empty. Run sql/schema.sql and etl/load.py first.")
    st.stop()
first_day, last_day = date_range.iloc[0, 0], date_range.iloc[0, 1]

tab_products, tab_reviews = st.tabs(["Products & brands", "Reviews & customers"])


# =====================================================================
# TAB 1 - PRODUCTS (Fatima Michel)
# =====================================================================
with tab_products:

    # ---- Q1 ----------------------------------------------------------
    section("Brands with the largest catalogue", "How many products each brand sells, with its average price and rating.")
    min_products = st.slider("Minimum number of products per brand", 10, 150, 50, step=10, key="q1")
    params = {"min_products": min_products}
    df = run_query(Q.Q1, params)
    if not empty_message(df):
        st.bar_chart(df, color=PINK, x="brand_name", y="total_products", x_label="Brand", y_label="Products")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q1, params)

    # ---- Q2 ----------------------------------------------------------
    section("Affordable favourites",
            "Products loved more than the average product while costing less than the average price.")
    max_price = st.number_input("Maximum price (USD)", min_value=1.0, max_value=2000.0,
                                value=50.0, step=5.0, key="q2")
    params = {"max_price": max_price}
    df = run_query(Q.Q2, params)
    if not empty_message(df):
        st.scatter_chart(df, color=PINK, x="price_usd", y="loves_count", x_label="Price (USD)", y_label="Loves")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q2, params)

    # ---- Q3 ----------------------------------------------------------
    section("Most loved products", "The favourites of each skincare category, ranked by loves.")
    c1, c2 = st.columns(2)
    category = c1.selectbox("Skincare category", categories, key="q3_cat")
    top_n = c2.slider("How many products", 1, 10, 3, key="q3_n")
    params = {"category": category, "top_n": top_n}
    df = run_query(Q.Q3, params)
    if not empty_message(df):
        st.bar_chart(df, color=PINK, x="product_name", y="loves_count", x_label="Product", y_label="Loves")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q3, params)

    # ---- Q4 ----------------------------------------------------------
    section("Highlights that make a difference", "Vegan, clean, cruelty-free… which claims go with better rated products than average?")
    min_hl = st.slider("Minimum number of rated products per highlight", 20, 500, 100, step=20, key="q4")
    params = {"min_products": min_hl}
    df = run_query(Q.Q4, params)
    if not empty_message(df):
        st.bar_chart(df, color=PINK, x="highlight", y="diff_vs_all_products",
                     x_label="Highlight", y_label="Rating difference vs. all products")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q4, params)

    # ---- Q5 ----------------------------------------------------------
    section("Products without reviews", "Only skincare products have reviews in this dataset.")
    df = run_query(Q.Q5)
    if not empty_message(df):
        st.bar_chart(df, color=PINK, x="primary_category", y="products_without_reviews",
                     x_label="Category", y_label="Products without reviews")
    show_sql(Q.Q5, None)


# =====================================================================
# TAB 2 - REVIEWS (Itsaso)
# =====================================================================
with tab_reviews:

    # ---- Q6 ----------------------------------------------------------
    section("Ratings by skin type", "Do customers with different skin types rate the same category differently?")
    c1, c2 = st.columns(2)
    default = categories.index("Moisturizers") if "Moisturizers" in categories else 0
    category6 = c1.selectbox("Skincare category", categories, index=default, key="q6_cat")
    min_reviews6 = c2.number_input("Minimum reviews per skin type", min_value=1,
                                   max_value=100000, value=1000, step=100, key="q6_min")
    params = {"category": category6, "min_reviews": int(min_reviews6)}
    df = run_query(Q.Q6, params)
    if not empty_message(df):
        c1, c2 = st.columns(2)
        c1.bar_chart(df, color=PINK, x="skin_type", y="avg_rating", x_label="Skin type", y_label="Average rating")
        c2.bar_chart(df, color=BLACK, x="skin_type", y="pct_recommended", x_label="Skin type", y_label="% recommended")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q6, params)

    # ---- Q7 ----------------------------------------------------------
    section("Reviews over time", "Reviews per month and the change from the previous month.")
    c1, c2 = st.columns(2)
    default_start = min(max(date(2019, 1, 1), first_day), last_day)
    start = c1.date_input("From", value=default_start, min_value=first_day, max_value=last_day, key="q7_s")
    end = c2.date_input("To", value=last_day, min_value=first_day, max_value=last_day, key="q7_e")
    if start > end:
        st.warning("The start date must be before the end date.")
    else:
        params = {"start": start, "end": end}
        df = run_query(Q.Q7, params)
        if not empty_message(df):
            st.line_chart(df, color=BLACK, x="month", y="total_reviews", x_label="Month", y_label="Reviews")
            st.dataframe(df, hide_index=True)
        show_sql(Q.Q7, params)

    # ---- Q8 ----------------------------------------------------------
    section("Best rated brands", "The brands customers rate highest in each skincare category.")
    c1, c2, c3 = st.columns(3)
    category8 = c1.selectbox("Skincare category", categories, index=default, key="q8_cat")
    top8 = c2.slider("How many brands", 1, 10, 3, key="q8_n")
    min_reviews8 = c3.number_input("Minimum reviews per brand", min_value=1,
                                   max_value=100000, value=500, step=100, key="q8_min")
    params = {"category": category8, "top_n": top8, "min_reviews": int(min_reviews8)}
    df = run_query(Q.Q8, params)
    if not empty_message(df):
        st.bar_chart(df, color=PINK, x="brand_name", y="avg_rating", x_label="Brand", y_label="Average rating")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q8, params)

    # ---- Q9 ----------------------------------------------------------
    section("Does price buy happiness?", "Average rating and % of customers who recommend, by price band.")
    choice = st.selectbox("Skincare category", ["All categories"] + categories, key="q9_cat")
    params = {"category": None if choice == "All categories" else choice}
    df = run_query(Q.Q9, params)
    if not empty_message(df):
        c1, c2 = st.columns(2)
        c1.bar_chart(df, color=PINK, x="price_band", y="avg_rating", x_label="Price band", y_label="Average rating")
        c2.bar_chart(df, color=BLACK, x="price_band", y="pct_recommended", x_label="Price band", y_label="% recommended")
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q9, params)

    # ---- Q10 ---------------------------------------------------------
    section("Rating check", "Products whose stored rating differs from the average of their reviews in our data.")
    threshold = st.number_input("Show products whose ratings differ by more than",
                                min_value=0.0, max_value=4.0, value=0.1, step=0.05, key="q10")
    params = {"threshold": threshold}
    df = run_query(Q.Q10, params)
    if not empty_message(df):
        st.dataframe(df, hide_index=True)
    show_sql(Q.Q10, params)