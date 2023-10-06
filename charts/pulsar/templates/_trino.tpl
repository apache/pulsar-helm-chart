{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "trino.coordinator" -}}
{{ template "pulsar.fullname" . }}-trino-coordinator
{{- end -}}

{{- define "trino.worker" -}}
{{ template "pulsar.fullname" . }}-trino-worker
{{- end -}}

{{- define "trino.service" -}}
{{ template "pulsar.fullname" . }}-trino
{{- end -}}

{{- define "trino.worker.service" -}}
{{ template "pulsar.fullname" . }}-trino-worker
{{- end -}}

{{- define "trino.hostname" -}}
{{ template "trino.service" . }}.{{ template "pulsar.namespace"  $ }}.svc.cluster.local
{{- end -}}

{{- define "trino.worker.hostname" -}}
{{ template "trino.worker.service" . }}.{{ template "pulsar.namespace" $ }}.svc.cluster.local
{{- end -}}

{{/*
trino service domain
*/}}
{{- define "trino.service_domain" -}}
{{- if .Values.domain.enabled -}}
{{- printf "trino.%s.%s" .Release.Name .Values.domain.suffix -}}
{{- else -}}
{{- if .Values.ingress.trino.external_domain -}}
{{- printf "%s" .Values.ingress.trino.external_domain -}}
{{- else -}}
{{- print "" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
pulsar ingress target port for http endpoint
*/}}
{{- define "trino.ingress.targetPort.http" -}}
{{- if .Values.tls.trino.enabled }}
{{- print "https" -}}
{{- else -}}
{{- print "http" -}}
{{- end -}}
{{- end -}}

{{/*
pulsar trino worker image
*/}}
{{- define "trino.worker.image" -}}
{{- if .Values.images.trino_worker }}
image: "{{ .Values.images.trino_worker.repository }}:{{ .Values.images.trino_worker.tag }}"
imagePullPolicy: {{ .Values.images.trino_worker.pullPolicy }}
{{- else }}
image: "{{ .Values.images.trino.repository }}:{{ .Values.images.trino.tag }}"
imagePullPolicy: {{ .Values.images.trino.pullPolicy }}
{{- end }}
{{- end }}

{{/*
Define trino TLS certificate secret name
*/}}
{{- define "pulsar.trino.tls.secret.name" -}}
{{- if .Values.tls.trino.certSecretName -}}
{{- .Values.tls.trino.certSecretName -}}
{{- else -}}
{{ .Release.Name }}-{{ .Values.tls.trino.cert_name }}
{{- end -}}
{{- end -}}

{{/*
Defines trino jks password
*/}}
{{- define "pulsar.trino.jks.password" -}}
{{- if .Values.tls.trino.passwordSecretRef -}}
{{- print "/pulsar/jks-password/password" -}}
{{- else -}}
{{- print "changeit" -}}
{{- end -}}
{{- end -}}