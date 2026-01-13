{{/*
Expand the name of the chart.
*/}}
{{- define "fluent.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "fluent.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "fluent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "fluent.labels" -}}
helm.sh/chart: {{ include "fluent.chart" . }}
{{ include "fluent.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "fluent.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fluent.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Fluent Bit component labels
*/}}
{{- define "fluent.fluentBit.labels" -}}
helm.sh/chart: {{ include "fluent.chart" . }}
app.kubernetes.io/name: {{ include "fluent.name" . }}-fluent-bit
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: fluent-bit
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Fluent Bit component selector labels
*/}}
{{- define "fluent.fluentBit.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fluent.name" . }}-fluent-bit
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: fluent-bit
{{- end }}

{{/*
Fluentd component labels
*/}}
{{- define "fluent.fluentd.labels" -}}
helm.sh/chart: {{ include "fluent.chart" . }}
app.kubernetes.io/name: {{ include "fluent.name" . }}-fluentd
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: fluentd
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Fluentd component selector labels
*/}}
{{- define "fluent.fluentd.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fluent.name" . }}-fluentd
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: fluentd
{{- end }}

{{/*
Fluentd service host (for Fluent Bit OUTPUT)
*/}}
{{- define "fluent.fluentdHost" -}}
{{- printf "%s-fluentd.%s.svc.cluster.local" (include "fluent.fullname" .) .Release.Namespace }}
{{- end }}

{{/*
OpenSearch host
*/}}
{{- define "fluent.opensearchHost" -}}
{{- printf "%s.%s.svc.cluster.local" .Values.fluentd.opensearch.service.name .Values.fluentd.opensearch.service.namespace }}
{{- end }}

{{/*
OpenSearch port
*/}}
{{- define "fluent.opensearchPort" -}}
{{- .Values.fluentd.opensearch.service.port }}
{{- end }}

{{/*
OpenSearch scheme
*/}}
{{- define "fluent.opensearchScheme" -}}
{{- .Values.fluentd.opensearch.scheme }}
{{- end }}
