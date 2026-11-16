"""
download_data.py - Project B: Sephora database

Descarga el dataset de Kaggle y copia los CSV a la carpeta data/ del proyecto.
La carpeta data/ esta en .gitignore: los datos NO se suben a Git.

Uso:
    pip install kagglehub
    python download_data.py
"""

import shutil
from pathlib import Path

import kagglehub

DATASET = "nadyinky/sephora-products-and-skincare-reviews"

# Carpeta data/ al lado de este script
DATA_DIR = Path(__file__).resolve().parent / "data"


def main():
    # 1. Descargar (kagglehub lo guarda en su cache)
    cache_path = Path(kagglehub.dataset_download(DATASET))
    print("Descargado en la cache:", cache_path)

    # 2. Copiar los CSV a data/
    DATA_DIR.mkdir(exist_ok=True)
    csv_files = sorted(cache_path.rglob("*.csv"))

    if not csv_files:
        raise SystemExit("No se encontro ningun CSV en la descarga.")

    for csv in csv_files:
        shutil.copy2(csv, DATA_DIR / csv.name)
        size_mb = csv.stat().st_size / 1_000_000
        print(f"  copiado {csv.name:<25} {size_mb:8.1f} MB")

    print(f"\n{len(csv_files)} archivos en: {DATA_DIR}")


if __name__ == "__main__":
    main()
