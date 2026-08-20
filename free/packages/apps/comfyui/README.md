# comfyui

Self-hosted node-based UI for Stable Diffusion image generation on Cozystack.

Powered by [ComfyUI](https://github.com/comfyanonymous/ComfyUI) with the [ai-dock/comfyui](https://github.com/ai-dock/comfyui) container image (CUDA, Python, ComfyUI, supervisor pre-baked).

## Parameters

### Common parameters

| Name           | Description                                                                 | Type     | Value |
| -------------- | --------------------------------------------------------------------------- | -------- | ----- |
| `host`         | Hostname for external access via Ingress. Leave empty to skip Ingress.      | `string` | `""`  |
| `storageClass` | StorageClass for the persistent volume. Leave empty to use cluster default. | `string` | `""`  |


### Storage

| Name           | Description                                                                                                              | Type       | Value  |
| -------------- | ------------------------------------------------------------------------------------------------------------------------ | ---------- | ------ |
| `storage`      | Storage configuration.                                                                                                   | `object`   | `{}`   |
| `storage.size` | PVC size. Stable Diffusion checkpoints range from 2GB (SD 1.5) to 12GB+ (SDXL/Flux); 50Gi fits ~4-6 models plus outputs. | `quantity` | `50Gi` |


### GPU

| Name         | Description                                                                            | Type   | Value  |
| ------------ | -------------------------------------------------------------------------------------- | ------ | ------ |
| `gpuEnabled` | Enable GPU acceleration. Set to false for CPU-only mode (very slow, for testing only). | `bool` | `true` |
| `gpuCount`   | Number of GPUs allocated to the pod.                                                   | `int`  | `1`    |


### Resources

| Name               | Description               | Type     | Value  |
| ------------------ | ------------------------- | -------- | ------ |
| `resources`        | Resource overrides.       | `object` | `{}`   |
| `resources.cpu`    | CPU request and limit.    | `string` | `4`    |
| `resources.memory` | Memory request and limit. | `string` | `16Gi` |


### Replication

| Name           | Description                                                                                                  | Type  | Value |
| -------------- | ------------------------------------------------------------------------------------------------------------ | ----- | ----- |
| `replicaCount` | Number of ComfyUI pods. Usually 1 — ComfyUI is stateful and multiple replicas do not share workflow state. | `int` | `1`   |

