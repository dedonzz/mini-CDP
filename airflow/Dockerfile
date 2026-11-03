FROM astrocrpublic.azurecr.io/runtime:3.3-11

# dbt 裝在獨立 venv，避免和 Airflow 的套件版本互相衝突（版本與 repo 的 uv.lock 一致）
RUN python -m venv dbt_venv &&     dbt_venv/bin/pip install --no-cache-dir dbt-core==1.12.6 dbt-bigquery==1.12.1
