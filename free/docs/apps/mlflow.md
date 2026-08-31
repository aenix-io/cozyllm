# mlflow

Experiment tracking and the model registry. MLflow records what a training run was given and what it produced — parameters, metrics, the model file — and versions those models so a team can say which one is in production.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"MLflow","metadata":{"name":"tracking"},"spec":{"lakehouseRef":"analytics","host":"mlflow.example.com"}}' | kubectl -n <ns> apply -f -
```

## Use it from a notebook or a job

```python
import mlflow

mlflow.set_tracking_uri("http://mlflow-tracking.<ns>.svc:5000")
mlflow.set_experiment("churn")

with mlflow.start_run():
    mlflow.log_param("max_depth", 6)
    mlflow.log_metric("auc", 0.91)
    mlflow.sklearn.log_model(model, "model", registered_model_name="churn")
```

## What lands where

Metadata — runs, parameters, metrics, the registry — goes to a private Postgres this app provisions. Artifacts, which are large and binary, go to the `Lakehouse` bucket under an `mlflow/` prefix. That split is why `lakehouseRef` is required: without it a trained model has nowhere to land.

Losing the Postgres loses the experiment history. The artifacts survive in the bucket, but as files nobody can attribute to a run — so treat it as a database that matters, not a cache.

## Placement

MLflow runs on the management cluster. The tracking server records and serves; it executes nothing you supplied.

One exception is worth knowing about rather than enabling: `mlflow models serve` loads a model by deserialising a pickle, which is code execution. If model serving is wanted it belongs in a separate, ComputePlane-placed object — not as a flag here.

## Why this chart renders its own Deployment

MLflow publishes no Helm chart, and the ones on Artifact Hub are third-party repositories with no maintenance commitment. The server is a single process, so there was little for a chart to abstract.
