# coder

Remote development environments, placed next to the data they query. A developer opens a workspace and gets a container with their tools in it, running in the cluster rather than on their laptop.

## Licence

Coder is **AGPL-3.0**, unlike everything else in this catalog, which is Apache-2.0. This chart is Apache-2.0 and stores none of Coder — your cluster pulls the upstream image at install time, on Coder's terms. If your organisation excludes AGPL software, this is the one application here that it excludes.

## Deploy

```bash
echo '{"apiVersion":"apps.cozystack.io/v1alpha1","kind":"Coder","metadata":{"name":"dev"},"spec":{"host":"coder.example.com","wildcardHost":"coder.example.com"}}' | kubectl -n <ns> apply -f -
```

**Requires the `computeplane` module.** A workspace is a container the developer holds a root shell in, which is remote code execution as the product rather than as a side effect. Coder also creates those workspace pods itself, so its ServiceAccount can schedule pods — a right that has no business existing on the management cluster.

## host and wildcardHost

`host` is required. Coder builds the URLs it hands to browsers and to workspace agents from its access URL, so it has to know the name users actually reach it by; it cannot be derived from a Service address.

`wildcardHost` is optional but usually wanted. Applications running inside a workspace — a notebook, a dev server — are served on their own subdomain when it is set. Without it they fall back to path-based routing, which breaks any app that assumes it owns the document root.

Both need DNS pointing at the ComputePlane's ingress, and the wildcard needs a certificate that covers `*.<domain>`.

## First login

```bash
kubectl -n <ns> get secret computeplane-cluster-admin-kubeconfig -o jsonpath='{.data.super-admin\.conf}' | base64 -d > cp.conf
kubectl --kubeconfig cp.conf -n <ns> get pods -l app.kubernetes.io/name=coder
```

Open `https://<host>` and create the first user through the setup flow. Templates — the definitions of what a workspace contains — are then authored in Coder itself.

## Database

Coder's database holds workspace definitions, templates, users and the audit log, and it is provisioned on the **management** cluster, deliberately out of reach of the workspaces it describes. A developer with a shell in their own workspace should not be one network hop from every other user's session.
