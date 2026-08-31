# coder

Remote development environments, placed next to the data they query.

## Licence

Coder is **AGPL-3.0**, with an additionally-licensed `enterprise/` directory that stays inactive without a key. Everything else in this catalog is Apache-2.0. This chart is Apache-2.0 and stores none of Coder: your cluster pulls the upstream image at install time, on Coder's terms. If your organisation's policy excludes AGPL software, this is the one application here that it excludes.

## Placement

Coder hands a developer a container they hold a shell in. That is remote code execution as the product, not as a side effect, so it runs on the tenant's ComputePlane with no option to co-locate it. Coder also creates the workspace pods itself, which means its ServiceAccount can schedule pods — a right that has no business existing on the management cluster.

The database stays on management, out of reach of the workspaces it describes.

## Parameters

### Common parameters

| Name           | Description                                                                                                                                                                                            | Type     | Value |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------- | ----- |
| `host`         | Hostname the Coder UI is reached by. Required: Coder builds the URLs it hands to browsers and workspace agents from this, so it cannot be derived from a Service address.                              | `string` | `""`  |
| `wildcardHost` | Base domain for per-workspace application subdomains, without the leading wildcard. Leave empty to serve workspace apps on paths instead, which breaks any app that assumes it owns the document root. | `string` | `""`  |
| `storageClass` | StorageClass for the database on the management cluster. Leave empty to use the cluster default.                                                                                                       | `string` | `""`  |


### Database

| Name                | Description                                                                      | Type       | Value  |
| ------------------- | -------------------------------------------------------------------------------- | ---------- | ------ |
| `database`          | Coder database.                                                                  | `object`   | `{}`   |
| `database.size`     | Persistent Volume size.                                                          | `quantity` | `10Gi` |
| `database.replicas` | Number of database instances.                                                    | `int`      | `2`    |
| `database.password` | Explicit password. When empty, one is generated and preserved across reconciles. | `string`   | `""`   |


### Server

| Name               | Description                                                                                                                                                                           | Type       | Value       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ----------- |
| `resourcesPreset`  | Sizing preset for the Coder server. The server brokers connections and provisions workspaces rather than running their workloads, so it stays small however large the workspaces are. | `string`   | `t1.medium` |
| `resources`        | Explicit resources, overriding the preset.                                                                                                                                            | `object`   | `{}`        |
| `resources.cpu`    | CPU available to the pod.                                                                                                                                                             | `quantity` | `""`        |
| `resources.memory` | Memory available to the pod.                                                                                                                                                          | `quantity` | `""`        |
| `replicaCount`     | Number of Coder server replicas.                                                                                                                                                      | `int`      | `2`         |

