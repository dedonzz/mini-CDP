"""mini-CDP 每日 pipeline：thelook → GCS → cdp_raw → dbt（staging / marts + 測試）。

- ds = data interval 起日（處理「前一天」的資料）；每個步驟都以 ds 參數化，覆寫該日分區，可任意重跑 / backfill。
- 各表 extract → load 平行執行，全部完成後才跑 dbt build。
"""

import logging

import pendulum
from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import dag, task_group
from airflow.timetables.interval import CronDataIntervalTimetable

APP = "/usr/local/airflow/mini_cdp"
DBT = "/usr/local/airflow/dbt_venv/bin/dbt"
TABLES = ["users", "products", "orders", "order_items", "events"]

log = logging.getLogger(__name__)


def alert_on_failure(context) -> None:
    # 本機先寫 log；正式環境換成 Slack / Email / PagerDuty。
    ti = context["task_instance"]
    log.error("ALERT %s.%s failed for ds=%s: %s", ti.dag_id, ti.task_id, context["ds"], context.get("exception"))


@dag(
    schedule=CronDataIntervalTimetable("0 0 * * *", timezone="UTC"),
    start_date=pendulum.datetime(2026, 10, 30, tz="UTC"),
    catchup=False,
    max_active_runs=1,
    default_args={
        "retries": 2,
        "retry_delay": pendulum.duration(minutes=2),
        "retry_exponential_backoff": True,
        "execution_timeout": pendulum.duration(minutes=30),
        "on_failure_callback": alert_on_failure,
    },
    tags=["mini-cdp"],
)
def cdp_daily():
    @task_group
    def ingest():
        for table in TABLES:
            extract = BashOperator(
                task_id=f"extract_{table}",
                bash_command=f"python {APP}/ingestion/extract.py --ds {{{{ ds }}}} --tables {table}",
            )
            load = BashOperator(
                task_id=f"load_{table}",
                bash_command=f"python {APP}/ingestion/load.py --ds {{{{ ds }}}} --tables {table}",
            )
            extract >> load

    dbt_build = BashOperator(
        task_id="dbt_build",
        cwd=f"{APP}/dbt",
        bash_command=(f"{DBT} deps && {DBT} source freshness && {DBT} build --vars '{{ds: {{{{ ds }}}}}}'"),
        execution_timeout=pendulum.duration(minutes=60),
    )

    ingest() >> dbt_build


cdp_daily()
