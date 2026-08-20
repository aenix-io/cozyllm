{{- define "vllm-inference.fullname" -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vllm-inference.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{ include "vllm-inference.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "vllm-inference.selectorLabels" -}}
app.kubernetes.io/name: vllm-inference
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
