# airflow

The scheduler. Airflow decides when the pipelines run and in what order — it does not process data itself, it starts the things that do.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Airflow","metadata":{"name":"pipelines"},"spec":{"dags":{"repo":"https://github.com/acme/dags.git","branch":"main"},"host":"airflow.example.com"}}' | kubectl -n <ns> apply -f -
```

**Requires the `computeplane` module.** A DAG is a Python file you write and the scheduler imports it, so running a DAG is running your code. See [sparkcluster.md](sparkcluster.md) for how to enable the module.

## Where DAGs come from

Point `dags.repo` at a git repository and a sidecar keeps the DAG folder in sync with it. With no repository configured you get a working scheduler with nothing to schedule, which is occasionally what you want and usually a mistake.

A private repository needs `dags.sshSecret`, naming a Secret **that already exists on the ComputePlane** — this chart does not copy it there, because that is where the sidecar runs.

## Executor

`KubernetesExecutor`, not Celery. Each task becomes one pod that exists for the duration of the task and is then removed. There is no broker, no standing pool of workers sitting idle between runs, and no pgbouncer — capacity follows the ComputePlane's own scaling rather than a number you picked in advance.

The practical consequence: `workers.resourcesPreset` sizes **one task**, not a cluster. Raising it gives every task more room; it does not add throughput.

## Task logs

A task's pod exits when the task ends, taking its filesystem with it, so without a shared volume the UI cannot show you the log of anything that has finished. `logs.persistence` is on by default for that reason and needs a **ReadWriteMany** storage class on the ComputePlane. If your ComputePlane has no RWX class, turn it off and configure remote logging to object storage instead — but know that you are choosing between the two, not opting out of both.

## Database

Airflow's metadata database — DAG state, run history, and every connection you configure — is provisioned as CNPG on the **management** cluster, not on the ComputePlane. It holds the credentials your DAGs use, so it must survive a compromised worker. The workload reaches it across clusters by DNS.

Note also that the bundled Postgres from the upstream Airflow chart is switched off: it pulls a Bitnami image, which this catalog does not use.

## Airflow is not MLflow

They appear together in every list and answer different questions. Airflow decides **when** something runs. MLflow records **what came out**. A normal setup has both, with an Airflow-scheduled training job logging its results to MLflow.
