# jupyterhub

Multi-user JupyterHub for ML / data-science teams. Wraps the upstream [zero-to-jupyterhub-k8s](https://github.com/jupyterhub/zero-to-jupyterhub-k8s) chart. Backing service: managed Postgres (hub state — users, groups, server records).

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"JupyterHub","metadata":{"name":"hub"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"jupyterhub","name":"jupyterhub"}}}' | kubectl -n <ns> apply -f -
```

## Spec reference

| Field | Notes |
| --- | --- |
| `database.{size,replicas,user,name}` | Pattern C Postgres |
| `host` | Hostname for SSO-gated external exposure. Published only when the cluster has OIDC enabled; leave empty for cluster-internal only |
| `replicaCount` | Multi-replica needs sticky sessions; the upstream chart doesn't configure them by default — stay at 1 unless you patch the inner HelmRelease |

Full reference: [packages/apps/jupyterhub/README.md](../../packages/apps/jupyterhub/README.md).

## Access

When `host` is set and the cluster has OIDC enabled, the hub is published at `https://<host>` behind an oauth2-proxy that authenticates against the platform Keycloak and admits only your tenant's groups — no extra configuration needed.

Without OIDC the hub is not published; reach it via port-forward:

```bash
kubectl -n <ns> port-forward svc/proxy-public 8080:80
```

Open `http://localhost:8080`.

## Authentication

External access is handled by the OIDC gatekeeper, so the hub is never reachable from outside the cluster without authenticating through Keycloak. When OIDC is enabled the chart also replaces the upstream `dummy` authenticator with a trusted-header authenticator that takes the hub username from the SSO identity oauth2-proxy forwards (`X-Forwarded-Preferred-Username`/`-Email`), so each tenant member gets their own hub user and home directory — no second login, no impersonation. Without OIDC (port-forward access only) the upstream `dummy` authenticator applies.

## Start a notebook

After login → **Start My Server**. JupyterHub spawns a single-user pod (kubespawner), gives you a notebook UI. Each user gets a `claim-<user>` PVC for their files.

## Connect notebooks to in-cluster LLMs

In a notebook cell:

```python
import os
os.environ['OPENAI_API_KEY'] = 'sk-master-CHANGEME'
os.environ['OPENAI_BASE_URL'] = 'http://litellm-gateway.<ns>.svc.cluster.local:4000/v1'

from openai import OpenAI
client = OpenAI()
r = client.chat.completions.create(
    model='qwen-7b',
    messages=[{'role':'user','content':'explain pandas groupby'}],
)
print(r.choices[0].message.content)
```

To bake these env vars into every spawned notebook (so users don't have to set them), patch the inner HelmRelease's `singleuser.extraEnv`:

```yaml
singleuser:
  extraEnv:
    OPENAI_API_KEY: "sk-master-CHANGEME"   # ideally use a secret reference
    OPENAI_BASE_URL: "http://litellm-gateway.<ns>:4000/v1"
```

## GPU notebooks

The default `singleuser` profile is CPU-only. To add a GPU option, configure `singleuser.profileList`:

```yaml
singleuser:
  profileList:
    - display_name: "CPU"
      default: true
    - display_name: "GPU (1× NVIDIA)"
      kubespawner_override:
        extra_resource_limits:
          nvidia.com/gpu: "1"
        image: jupyter/tensorflow-notebook:python-3.11
```

Users pick a profile on **Start My Server**.

## Persistent user data

Per-user PVCs survive pod restarts. They are *not* deleted when a user is deleted from the hub DB — that's by design (data retention). To clean up: `kubectl get pvc -l hub.jupyter.org/username=<user>`.
