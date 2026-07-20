# Upgrade Guide

How releases of this catalog are versioned, and how to pin your cluster against them.

## Versioning

This repository follows [Semantic Versioning 2.0](https://semver.org/) on Git tags:

| Bump  | Trigger                                                                                                |
| ----- | ------------------------------------------------------------------------------------------------------ |
| Patch | Upstream Helm chart bump that does not change the `openAPISchema`. Renovate auto-PRs these.            |
| Minor | New app added, new value field exposed, non-breaking dashboard metadata change.                        |
| Major | Breaking change in any `openAPISchema`, a Pattern A/B/C rewire, renamed `Kind`, or removed app.        |

Every tag has a GitHub Release with auto-generated notes. Major bumps include a `## Migration notes` section in the release body listing what changed and what action the operator needs to take.

## Pinning your cluster

Edit your `init.yaml` so the FluxCD `GitRepository` does **not** track `main` directly. Pick one of three patterns:

### Pattern A — Auto-patch within a minor line (recommended for most deployments)

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: cozyllm
  namespace: cozy-public
spec:
  interval: 1m0s
  ref:
    semver: '~1.4'           # any 1.4.x release, never 1.5.0 or later
  url: https://github.com/aenix-io/cozyllm
```

You get every patch bump (upstream chart pins, security fixes) automatically. Minor bumps stay opt-in.

### Pattern B — Hard pin to one tag (recommended for production-critical clusters)

```yaml
spec:
  interval: 1m0s
  ref:
    tag: v1.4.0
```

Nothing changes until you bump the tag manually. Strongest control, slowest cadence.

### Pattern C — Track `main` (dev / staging only)

```yaml
spec:
  interval: 1m0s
  ref:
    branch: main
```

Every push to `main` reconciles immediately. **Never use this in production** — a breaking commit lands instantly.

## Upgrading

### Patch / minor

Bump the `ref.semver` constraint or `ref.tag`, then commit your `init.yaml` change. Flux reconciles within `interval`. Existing CRs continue to render against the new chart version on next reconciliation — the cozystack controller picks up the schema change and re-renders the dashboard form.

### Major

1. Read the release notes' `## Migration notes` section before bumping.
2. Take a snapshot / backup of any stateful CR data that the migration touches (Postgres, persistent volumes).
3. Bump `ref.tag` (do not use `ref.semver: '^2.0'` for first major adoption — pin explicitly).
4. Apply, then watch the cozystack controller reconcile each affected `ApplicationDefinition` and its existing CRs.
5. Verify each affected app's dashboard form renders correctly and existing instances still report `READY=True`.

## Adding a new app to an existing pinned cluster

A new app shipped in `v1.5.0` (minor bump) does **not** require you to widen `ref.semver: '~1.4'` to `'~1.5'`. You can stay on `1.4.x` and skip the new app entirely. When you do want the new app, bump the constraint or the tag — Flux will materialise the new `ApplicationDefinition`, `HelmRepository`, namespaces, and `HelmChart` in one reconciliation.

## Release schedule

Renovate scans upstream Helm chart sources every Monday morning (UTC) and opens PRs for any chart bump it finds. After CI is green and the bump has been reviewed (patch bumps may auto-merge), the maintainer cuts a tag matching semver discipline and the `release.yml` workflow generates a GitHub Release.

## Schema-migration discipline

When you modify any `values.yaml`, regenerate `values.schema.json` (`make generate` in the app's directory) and mirror the new schema into `packages/core/platform/templates/cozyrds.yaml` under the app's `openAPISchema` field. The `openAPISchema` field title must always be exactly `"Chart Values"` — every form-rendering convention in the cozystack dashboard relies on this.

Breaking changes to `openAPISchema`:

- **Adding a required field**: major bump. Existing CRs may stop reconciling.
- **Removing a field**: major bump. Existing CRs will reject the new schema if they still carry the field.
- **Renaming a field**: major bump.
- **Tightening validation (new pattern, narrower enum)**: major bump.
- **Adding an optional field with a default**: minor bump. Safe.
- **Loosening validation (wider enum, looser pattern)**: minor bump. Safe.
- **Changing description / title**: patch bump. Cosmetic.
