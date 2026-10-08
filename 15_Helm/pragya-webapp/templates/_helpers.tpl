{{/*
Short name of the chart (can be changed with nameOverride).
*/}}
{{- define "pragya-webapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Full name used for every object: <release>-<chart>, unless the release name
already contains the chart name. Kubernetes names are limited to 63 chars.
*/}}
{{- define "pragya-webapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
"chart-version" string for the helm.sh/chart label.
*/}}
{{- define "pragya-webapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Image reference: tag from values, otherwise the chart's appVersion.
*/}}
{{- define "pragya-webapp.image" -}}
{{- printf "%s:%s" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}

{{/*
Labels put on every object.
*/}}
{{- define "pragya-webapp.labels" -}}
helm.sh/chart: {{ include "pragya-webapp.chart" . }}
{{ include "pragya-webapp.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/environment: {{ .Values.app.environment }}
{{- end }}

{{/*
Labels used by the Service and Deployment selectors. These must never
change between upgrades, so they only contain name + release.
*/}}
{{- define "pragya-webapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pragya-webapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name.
*/}}
{{- define "pragya-webapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "pragya-webapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
