# sparkcluster

Batch compute for the lakehouse. Runs on the ComputePlane, always.

## Parameters

### Common parameters

| Name           | Description                                                                                                                                             | Type     | Value |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `lakehouseRef` | Name of the `Lakehouse` in this namespace whose tables jobs read and write. Required: a compute engine with no warehouse to point at has nothing to do. | `string` | `""`  |


### Operator

| Name                          | Description                                | Type       | Value       |
| ----------------------------- | ------------------------------------------ | ---------- | ----------- |
| `controller`                  | Spark Operator deployment.                 | `object`   | `{}`        |
| `controller.replicas`         | Number of operator replicas.               | `int`      | `1`         |
| `controller.resourcesPreset`  | Sizing preset for the operator.            | `string`   | `t1.medium` |
| `controller.resources`        | Explicit resources, overriding the preset. | `object`   | `{}`        |
| `controller.resources.cpu`    | CPU available to the pod.                  | `quantity` | `""`        |
| `controller.resources.memory` | Memory available to the pod.               | `quantity` | `""`        |

