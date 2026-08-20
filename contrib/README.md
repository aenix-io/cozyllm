# contrib

Catalogs whose code is Apache-2.0 but whose applications are licensed by their vendors.

The name is Debian's: *contrib* is free software that depends on something outside the free archive. The code in this directory is free. What it installs is not, and is never stored here — your cluster pulls it from the vendor at install time, on the vendor's terms.

**Read this before installing.** Several of these products forbid offering them to third parties as a hosted or managed service without a separate agreement — which is what running them on Cozystack as an operator amounts to. Each application states the licence of what it pulls and the entitlement you need.

This catalog is CozyLLM's vendor-licensed AI stack. The apps integrate into the Cozystack dashboard exactly like the [free catalog](../free/): deploy with a click, configure through a generated form, scale and tear down independently.

## What's inside

| App | What it is | Upstream license |
| --- | --- | --- |
| **[n8n](docs/apps/n8n.md)** | General workflow automation with native AI nodes | [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md) |
| **[open-webui](docs/apps/open-webui.md)** | Chat interface over any OpenAI-compatible API | [Open WebUI License](https://github.com/open-webui/open-webui/blob/main/LICENSE) |

## Read before you install: vendor entitlements

The free CozyLLM catalog only carries apps whose upstream payloads are open source. These two are not, so they live here — installing this catalog is an explicit opt-in to their vendors' terms:

- **n8n** is distributed under the Sustainable Use License — "fair-code", not open source. Internal business use is broadly permitted, but **offering n8n as a managed service to third parties requires a commercial entitlement from n8n** (an Embed or Enterprise agreement). Running a Cozystack platform where tenants other than your own organization deploy n8n **is** offering it as a managed service to third parties, so you need such an agreement before you install.
- **Open WebUI** is distributed under the Open WebUI License, a BSD-3-derived license with a branding-preservation clause: deployments serving more than 50 users must keep the Open WebUI branding intact unless you hold an enterprise license from the vendor. This chart does not alter or remove any branding.

You — the operator installing this catalog — are responsible for ensuring your deployment complies with these terms. Nothing in this repository grants you any rights to the upstream products.

## Upstream licenses

The application payloads are fetched from the vendors' own sources at deploy time and retain their upstream licenses (see [NOTICE](NOTICE)):

| Application | Upstream license |
| --- | --- |
| n8n | Sustainable Use License (fair-code, not OSI-approved open source). Source files under `.ee` paths are additionally covered by the n8n Enterprise License; enterprise features are inactive without a commercial license key from n8n. Offering n8n as a managed service to third parties requires an Embed/Enterprise entitlement from n8n. |
| Open WebUI | Open WebUI License (BSD-3-derived, with a branding-preservation clause for deployments over 50 users absent an enterprise license). |
| Qdrant (optional Open WebUI dependency) | Apache-2.0 |

Consult each upstream project for the authoritative and current license text before offering these applications to third parties.

## BYOL: bring your own license

The n8n chart exposes a `vendorLicense` knob for operators who hold an n8n entitlement. Create a Secret in the app namespace whose key `N8N_LICENSE_ACTIVATION_KEY` contains your activation key, then set `spec.vendorLicense.secretRef` to the Secret's name — the chart injects the key into the n8n instance. See [docs/apps/n8n.md](docs/apps/n8n.md) for details.

## Quick install

Apply the bootstrap manifest to a Cozystack 1.4+ cluster (typically alongside the free catalog):

```bash
kubectl apply -f https://raw.githubusercontent.com/aenix-io/cozyllm/main/contrib/init.yaml
```

This registers a FluxCD `GitRepository` (`cozyllm-contrib` in `cozy-public`) and a platform `HelmRelease` (`cozyllm-contrib` in `cozy-system`). Flux pulls every minute; within ~2 minutes the `n8n` and `open-webui` `ApplicationDefinition` resources appear in the dashboard.

End-to-end scenarios wiring these apps to the [free catalog's](../free/) model serving and gateway are in [docs/examples.md](docs/examples.md).

## License

The code in this catalog — Helm charts, templates, platform manifests, documentation — is licensed under the [Apache License 2.0](../LICENSE). Nothing non-Apache is stored or redistributed here: the application payloads (container images, upstream Helm charts) are fetched from the vendors' own sources at deploy time and retain their upstream licenses. See [NOTICE](NOTICE).
