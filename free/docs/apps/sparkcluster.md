# sparkcluster

Batch compute. Where Trino answers a query, Spark runs a job you wrote — reshaping a table, backfilling a year of history, compacting the warehouse.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"SparkCluster","metadata":{"name":"batch"},"spec":{"lakehouseRef":"analytics"}}' | kubectl -n <ns> apply -f -
```

**This requires the `computeplane` module on your tenant.** Spark runs whatever jar or Python file is submitted to it — that is its purpose, not a side effect — so it is placed on the tenant's own Kubernetes cluster with no option to co-locate it. Without the module the apply fails with a message naming what to enable, rather than quietly placing untrusted code on the management cluster.

```bash
kubectl -n <root-ns> patch tenant <name> --type merge -p '{"spec":{"computeplane":true}}'
```

## What gets deployed

The Spark Operator, on the ComputePlane, watching only your namespace there. You then submit `SparkApplication` objects to that cluster and the operator turns each into a driver pod plus executors that live only as long as the job.

Note that jobs are submitted to the **ComputePlane**, not to the management cluster:

```bash
kubectl -n <ns> get secret computeplane-cluster-admin-kubeconfig -o jsonpath='{.data.super-admin\.conf}' | base64 -d > cp.conf
kubectl --kubeconfig cp.conf -n <ns> apply -f my-job.yaml
```

## Job defaults

A ConfigMap named `<release>-defaults` carries the settings a job should inherit: the Iceberg session extensions, the catalog endpoint, and `spark.local.dir`.

That last one matters more than it looks. Shuffle spills to local disk between stages and its volume is comparable to the input, so pointing it at a network volume is usually the difference between a job that finishes and one that crawls.

Credentials are deliberately absent from that ConfigMap — a properties file does no variable substitution, so putting them there would mean baking secrets into a ConfigMap. A job supplies them to its driver and executors from the bucket Secret instead.

## Compaction

Small-file buildup is the most common reason a healthy lakehouse gets slow, and only an engine can fix it because it means physically rewriting Parquet:

```sql
CALL lakehouse.system.rewrite_data_files(table => 'sales.orders');
```

Run it from a scheduled Spark job. This lives here rather than with the `Lakehouse` because the catalog never touches data files.
