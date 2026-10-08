{{- define "lib.labels" -}}
app.kubernetes.io/part-of: {{ .Values.name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
