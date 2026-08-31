# airflow

Schedules the pipelines that build and refresh lakehouse tables.

## Parameters

### Common parameters

| Name           | Description                                                                                                          | Type     | Value |
| -------------- | -------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for the Airflow UI on the ComputePlane's ingress. Leave empty to keep it reachable only inside the cluster. | `string` | `""`  |
| `storageClass` | StorageClass for the metadata database on the management cluster. Leave empty to use the cluster default.            | `string` | `""`  |


### DAGs

| Name              | Description                                                                                              | Type     | Value  |
| ----------------- | -------------------------------------------------------------------------------------------------------- | -------- | ------ |
| `dags`            | DAG source.                                                                                              | `object` | `{}`   |
| `dags.repo`       | Git repository to sync DAGs from. Leave empty to configure DAG delivery yourself.                        | `string` | `""`   |
| `dags.branch`     | Branch to track.                                                                                         | `string` | `main` |
| `dags.subPath`    | Path within the repository holding the DAG files. Empty means the repository root.                       | `string` | `""`   |
| `dags.syncPeriod` | How often to poll the repository for changes.                                                            | `string` | `60s`  |
| `dags.sshSecret`  | Name of a Secret holding an SSH key for a private repository. It must already exist on the ComputePlane. | `string` | `""`   |


### Logs

| Name                | Description                                                                      | Type       | Value  |
| ------------------- | -------------------------------------------------------------------------------- | ---------- | ------ |
| `logs`              | Task log retention.                                                              | `object`   | `{}`   |
| `logs.persistence`  | Keep task logs on a shared volume.                                               | `bool`     | `true` |
| `logs.size`         | Volume size for logs.                                                            | `quantity` | `20Gi` |
| `logs.storageClass` | StorageClass for the log volume on the ComputePlane. Must support ReadWriteMany. | `string`   | `""`   |


### Database

| Name                | Description                                                                      | Type       | Value  |
| ------------------- | -------------------------------------------------------------------------------- | ---------- | ------ |
| `database`          | Metadata database.                                                               | `object`   | `{}`   |
| `database.size`     | Persistent Volume size.                                                          | `quantity` | `10Gi` |
| `database.replicas` | Number of database instances.                                                    | `int`      | `2`    |
| `database.password` | Explicit password. When empty, one is generated and preserved across reconciles. | `string`   | `""`   |


### Components

| Name                         | Description                                | Type       | Value       |
| ---------------------------- | ------------------------------------------ | ---------- | ----------- |
| `scheduler`                  | Scheduler.                                 | `object`   | `{}`        |
| `scheduler.replicas`         | Number of scheduler replicas.              | `int`      | `1`         |
| `scheduler.resourcesPreset`  | Sizing preset.                             | `string`   | `c1.medium` |
| `scheduler.resources`        | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `scheduler.resources.cpu`    | CPU available to the pod.                  | `quantity` | `""`        |
| `scheduler.resources.memory` | Memory available to the pod.               | `quantity` | `""`        |
| `apiServer`                  | UI and REST API.                           | `object`   | `{}`        |
| `apiServer.replicas`         | Number of API server replicas.             | `int`      | `2`         |
| `apiServer.resourcesPreset`  | Sizing preset.                             | `string`   | `t1.medium` |
| `apiServer.resources`        | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `apiServer.resources.cpu`    | CPU available to the pod.                  | `quantity` | `""`        |
| `apiServer.resources.memory` | Memory available to the pod.               | `quantity` | `""`        |
| `triggerer`                  | Deferrable task handler.                   | `object`   | `{}`        |
| `triggerer.resourcesPreset`  | Sizing preset.                             | `string`   | `t1.medium` |
| `triggerer.resources`        | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `triggerer.resources.cpu`    | CPU available to the pod.                  | `quantity` | `""`        |
| `triggerer.resources.memory` | Memory available to the pod.               | `quantity` | `""`        |
| `workers`                    | Per-task pod sizing.                       | `object`   | `{}`        |
| `workers.resourcesPreset`    | Sizing preset.                             | `string`   | `u1.medium` |
| `workers.resources`          | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `workers.resources.cpu`      | CPU available to the pod.                  | `quantity` | `""`        |
| `workers.resources.memory`   | Memory available to the pod.               | `quantity` | `""`        |

