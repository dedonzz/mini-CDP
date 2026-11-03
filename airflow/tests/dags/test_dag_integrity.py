from airflow.models import DagBag


def test_no_import_errors():
    bag = DagBag(dag_folder="dags", include_examples=False)
    assert not bag.import_errors


def test_cdp_daily_structure():
    dag = DagBag(dag_folder="dags", include_examples=False).get_dag("cdp_daily")
    assert dag.max_active_runs == 1
    dbt = dag.get_task("dbt_build")
    loads = {t for t in dag.task_ids if t.startswith("ingest.load_")}
    assert len(loads) == 5
    assert set(dbt.upstream_task_ids) == loads
    for task in dag.tasks:
        assert task.retries >= 1
