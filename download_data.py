"""
download_data.py - Project B: Sephora database

Downloads the dataset from Kaggle and copies the CSV files to the project's data/ folder.
The data/ folder is in .gitignore: the data is NOT uploaded to Git.

Usage:
    pip install kagglehub
    python download_data.py
"""

import shutil
from pathlib import Path

import kagglehub

DATASET = "nadyinky/sephora-products-and-skincare-reviews"

# data/ folder next to this script
DATA_DIR = Path(__file__).resolve().parent / "data"


def main():
    # 1. Download (kagglehub keeps it in its cache)
    cache_path = Path(kagglehub.dataset_download(DATASET))
    print("Downloaded to the cache:", cache_path)

    # 2. Copy the CSV files to data/
    DATA_DIR.mkdir(exist_ok=True)
    csv_files = sorted(cache_path.rglob("*.csv"))

    if not csv_files:
        raise SystemExit("No CSV file found in the download.")

    for csv in csv_files:
        shutil.copy2(csv, DATA_DIR / csv.name)
        size_mb = csv.stat().st_size / 1_000_000
        print(f"  copied {csv.name:<25} {size_mb:8.1f} MB")

    print(f"\n{len(csv_files)} files in: {DATA_DIR}")


if __name__ == "__main__":
    main()
