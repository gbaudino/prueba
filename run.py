import argparse
import subprocess
from pathlib import Path

import duckdb

ROOT = Path(__file__).parent


def main() -> None:
    parser = argparse.ArgumentParser(description="corre el pipeline desde cero")
    parser.add_argument("--queries", action="store_true", help="imprime las respuestas")
    args = parser.parse_args()

    subprocess.run(["dbt", "build"], cwd=ROOT, check=True)

    if args.queries:
        con = duckdb.connect(str(ROOT / "data/warehouse.duckdb"), read_only=True)
        for archivo in sorted((ROOT / "queries").glob("*.sql")):
            print(f"\n=== {archivo.name}")
            for query in archivo.read_text().split(";"):
                if query.strip():
                    con.sql(query).show()


if __name__ == "__main__":
    main()
