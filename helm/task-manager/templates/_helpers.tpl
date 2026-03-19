{{/*
Base image path shared by all three services.
Resolves to: ghcr.io/<owner>/task-manager
*/}}
{{- define "task-manager.imageBase" -}}
{{- .Values.image.registry }}/{{- .Values.image.owner }}/task-manager
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "task-manager.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
