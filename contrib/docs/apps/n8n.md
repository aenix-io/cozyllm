# n8n

General-purpose workflow automation with first-class AI nodes. Wraps the upstream [8gears/n8n-helm-chart](https://github.com/8gears/n8n-helm-chart) (OCI). Backing service: managed Postgres. The chart's bundled Valkey is disabled — n8n runs in single-process mode without queue workers. Enable queue mode + add a sibling Redis if you need horizontal worker scaling.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"N8n","metadata":{"name":"automation"},"spec":{"database":{"size":"5Gi","replicas":1,"user":"n8n","name":"n8n"},"encryptionKey":"replace-with-random-32-char-string"}}' | kubectl -n <ns> apply -f -
```

**Always set `encryptionKey` explicitly.** If empty, n8n generates one on first start — losing it on pod restart invalidates every stored credential (Slack tokens, API keys, OAuth state).

Generate a key once:

```bash
openssl rand -hex 32
```

## Spec reference

| Field | Notes |
| --- | --- |
| `database.{size,replicas,user,name}` | Pattern C Postgres |
| `encryptionKey` | 32-char string. **Set this — do not leave empty in production.** |
| `host` | Hostname for external access. Published as a TLS Ingress (cert-manager); n8n's own account auth protects it. Leave empty for cluster-internal only |
| `replicaCount` | Stay at 1 unless you've enabled queue mode |
| `vendorLicense.secretRef` | BYOL: name of a Secret in the app namespace whose key `N8N_LICENSE_ACTIVATION_KEY` holds your n8n activation key (Embed/Enterprise). Offering n8n as a managed service to third parties requires such an entitlement from n8n |

Full reference: [packages/apps/n8n/README.md](../../packages/apps/n8n/README.md).

## Licensing (Sustainable Use License)

n8n is distributed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) — fair-code, not OSI-approved open source. Internal use is broadly permitted, but **offering n8n as a managed service to third parties requires a commercial entitlement from n8n** (Embed/Enterprise). If you hold one, create a Secret with your activation key and point `vendorLicense.secretRef` at it:

```bash
kubectl -n <ns> create secret generic n8n-license \
  --from-literal=N8N_LICENSE_ACTIVATION_KEY=<your-activation-key>
```

Then set `spec.vendorLicense.secretRef: n8n-license` on the CR.

## Access

```bash
kubectl -n <ns> port-forward svc/n8n-automation-app 5678:80
```

Open `http://localhost:5678` → create the owner account.

## Build an AI workflow

1. **New Workflow** → add a trigger (**Webhook**, **Schedule**, **Telegram**, **Slack** event, …)
2. Add the **OpenAI** node:
   - Credentials → New "OpenAI": base URL `http://litellm-gateway.<ns>.svc.cluster.local:4000/v1`, API key `sk-master-CHANGEME`
   - Resource: **Chat** → Operation: **Message a Model**
   - Model: select from dropdown (n8n queries LiteLLM for the model list)
3. Wire output → next nodes (Slack, Email, Notion, HTTP Request, Postgres, …)
4. **Activate** the workflow

## Common patterns

**Triage support tickets**: WHMCS webhook → OpenAI classify (`billing` / `technical` / `sales` / `abuse`) → Switch node → respective Slack channel.

**Daily blog ingestion**: Schedule daily → RSS feed reader → OpenAI summarize → Telegram channel post.

**Document sync**: GitHub webhook (push to docs repo) → HTTP Request to Open WebUI `/api/v1/documents/upload` → automatic re-indexing in Qdrant.

## Manage credentials at scale

n8n's encrypted credential store can hold any service's API key. Reference them by name in any node — credentials never appear in workflow JSON exports, only their IDs.

## Backups

The Postgres CR keeps n8n's data. If `backup.enabled=true` is configured on the sibling Postgres (cozystack postgres chart supports S3 backup), workflow data is included automatically.

## Queue mode (advanced)

For horizontal worker scaling, patch the inner HelmRelease's values:

```yaml
worker:
  count: 3
valkey:
  enabled: true        # or wire to a Pattern C Redis sibling CR
```

Note: Pattern C Redis is not declared in this app chart by default — add it manually to `templates/redis.yaml` following the postgres pattern.
