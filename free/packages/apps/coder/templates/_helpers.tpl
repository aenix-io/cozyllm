{{/*
  The database password is needed in two places — the Secret CNPG bootstraps
  from, and the DSN handed to the Coder server — and `randAlphaNum` returns a
  fresh value on every call. Generating it in each template independently gives
  a Secret and a DSN that disagree, and a server that can never authenticate on
  a fresh install.

  So it is resolved once and cached on .Values, which persists for the whole
  render. Order of precedence: an explicit value from the user, then the
  password already stored in the Secret from a previous reconcile, and only a
  genuinely absent Secret produces a new one.
*/}}
{{- define "coder.dbPassword" -}}
{{- if not (hasKey .Values "_resolvedDbPassword") -}}
  {{- $pw := .Values.database.password -}}
  {{- if not $pw -}}
    {{- $name := printf "postgres-%s-db-app" .Release.Name -}}
    {{- $existing := lookup "v1" "Secret" .Release.Namespace $name -}}
    {{- if and $existing $existing.data (hasKey $existing.data "password") -}}
      {{- $pw = index $existing.data "password" | b64dec -}}
    {{- else -}}
      {{- $pw = randAlphaNum 24 -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set .Values "_resolvedDbPassword" $pw -}}
{{- end -}}
{{- get .Values "_resolvedDbPassword" -}}
{{- end -}}
