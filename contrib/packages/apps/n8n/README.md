# n8n

Workflow automation platform on Cozystack, backed by a managed Postgres provisioned via the cozystack `Postgres` sibling CR.

Powered by the upstream [8gears/n8n-helm-chart](https://github.com/8gears/n8n-helm-chart) (OCI distribution at `oci://8gears.container-registry.com/library/n8n`).

The bundled Valkey (Redis-compatible) subchart is disabled — this scaffold runs n8n in single-process mode without queue workers. If you need horizontal worker scaling, switch the chart to queue mode and provision a sibling Redis via Pattern C.

## Parameters

### Common parameters

| Name           | Description                                                                     | Type     | Value |
| -------------- | ------------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access via Ingress. Leave empty to skip Ingress.          | `string` | `""`  |
| `storageClass` | StorageClass for the managed Postgres PVCs. Leave empty to use cluster default. | `string` | `""`  |


### Database configuration

| Name                | Description                                                                                                  | Type       | Value |
| ------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- | ----- |
| `database`          | PostgreSQL configuration.                                                                                    | `object`   | `{}`  |
| `database.size`     | Persistent Volume size for database storage.                                                                 | `quantity` | `5Gi` |
| `database.replicas` | Number of database instances.                                                                                | `int`      | `2`   |
| `database.user`     | Database user n8n connects as.                                                                               | `string`   | `n8n` |
| `database.name`     | Database name n8n stores its workflows, credentials, and executions in.                                      | `string`   | `n8n` |
| `database.password` | Optional explicit password. When empty, the cozystack postgres chart generates and preserves one via lookup. | `string`   | `""`  |


### n8n

| Name            | Description                                                                                                                                                                                               | Type     | Value |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `encryptionKey` | Encryption key for n8n credentials at rest. If empty, n8n generates one on first start — but that value is lost on pod recreation, breaking every stored credential. Set this explicitly in production. | `string` | `""`  |


### Resources

| Name               | Description                                 | Type     | Value |
| ------------------ | ------------------------------------------- | -------- | ----- |
| `resources`        | Container resources.                        | `object` | `{}`  |
| `resources.cpu`    | CPU request and limit (e.g. 500m, 2).       | `string` | `""`  |
| `resources.memory` | Memory request and limit (e.g. 512Mi, 2Gi). | `string` | `""`  |


### Replication

| Name           | Description                                                                                  | Type  | Value |
| -------------- | -------------------------------------------------------------------------------------------- | ----- | ----- |
| `replicaCount` | Number of n8n main pods. Usually 1 — multi-replica requires queue mode with sibling Redis. | `int` | `1`   |


### Vendor license (BYOL)

| Name                      | Description                                                                                                                                                                                                                      | Type     | Value |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----- |
| `vendorLicense`           | Bring-your-own n8n license entitlement.                                                                                                                                                                                          | `object` | `{}`  |
| `vendorLicense.secretRef` | Name of a Secret in the app namespace whose key N8N_LICENSE_ACTIVATION_KEY holds the operator's n8n activation key (Embed/Enterprise). Offering n8n as a managed service to third parties requires such an entitlement from n8n. | `string` | `""`  |

