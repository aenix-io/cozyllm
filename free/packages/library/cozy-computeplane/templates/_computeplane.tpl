{{/*
  Remote-apply wiring for charts whose workload must run on the tenant's
  ComputePlane.

  There is no platform-side routing and there will not be: the `placement` field
  once sketched on ApplicationDefinition was dropped, and a tenant has exactly
  one ComputePlane, so nothing chooses between planes. Every such chart therefore
  carries this wiring itself. Because it is permanent rather than a bridge to a
  future platform feature, it lives here once instead of being copied into each
  chart, where three copies would drift.

  How it works: the release stays on the MANAGEMENT cluster and renders an inner
  Flux HelmRelease pointing at the ComputePlane's admin kubeconfig. The
  management helm-controller resolves the chart locally and applies the rendered
  manifests remotely, so no Flux is needed inside the ComputePlane.
*/}}

{{/*
  cozy-computeplane.secretName — the Kamaji-written admin kubeconfig Secret.

  This is a fixed contract, not a configurable reference. The cluster HelmRelease
  in extra/computeplane is named `computeplane-cluster`, and Kamaji derives the
  Secret name from it. A chart that let the user point elsewhere would be letting
  them aim untrusted code at an arbitrary cluster.
*/}}
{{- define "cozy-computeplane.secretName" -}}
computeplane-cluster-admin-kubeconfig
{{- end }}

{{/*
  cozy-computeplane.require — fail rendering when the tenant has no ComputePlane.

  With no toggle and no fallback there is nothing safe to degrade to: rendering
  into the tenant namespace instead would place untrusted code exactly where this
  design exists to keep it out of. So the chart refuses, and says which module to
  enable rather than failing with a missing-Secret error at apply time.

  Usage: {{ include "cozy-computeplane.require" (list "airflow" $) }}
*/}}
{{- define "cozy-computeplane.require" -}}
{{- $name := index . 0 -}}
{{- $ctx := index . 1 -}}
{{- $secret := lookup "v1" "Secret" $ctx.Release.Namespace (include "cozy-computeplane.secretName" $ctx) -}}
{{- if not $secret -}}
{{- fail (printf "%s runs user-supplied code and is placed on the ComputePlane only. Secret %q was not found in namespace %q — enable the `computeplane` module on this tenant first (spec.computeplane: true on the Tenant), wait for its cluster to come up, then retry." $name (include "cozy-computeplane.secretName" $ctx) $ctx.Release.Namespace) -}}
{{- end -}}
{{- end }}

{{/*
  cozy-computeplane.target — the HelmRelease fields that redirect the apply.

  Emitted inside a HelmRelease spec. The tenant namespace does not exist on the
  ComputePlane, so it is created there and the Helm release is stored in it;
  createNamespace alone is a no-op without an explicit targetNamespace on a
  remote cluster.

  Usage, inside spec:
    {{- include "cozy-computeplane.target" $ | nindent 2 }}
*/}}
{{- define "cozy-computeplane.target" -}}
kubeConfig:
  secretRef:
    name: {{ include "cozy-computeplane.secretName" . }}
    key: super-admin.svc
targetNamespace: {{ .Release.Namespace }}
storageNamespace: {{ .Release.Namespace }}
install:
  createNamespace: true
{{- end }}
