{{/*
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
*/}}

{{- define "pulsar.podMonitor" -}}
{{- $root := index . 0 }}
{{- $component := index . 1 }}
{{- $matchLabel := index . 2 }}
{{- $portName := "http" }}
{{- if gt (len .) 3 }}
{{- $portName = index . 3 }}
{{- end }}

{{/* Extract component parts for nested values */}}
{{- $componentParts := splitList "." $component }}
{{- $valuesPath := $root.Values }}
{{- range $componentParts }}
  {{- $valuesPath = index $valuesPath . }}
{{- end }}

{{- if index $root.Values "victoria-metrics-k8s-stack" "enabled" }}
apiVersion: operator.victoriametrics.com/v1beta1
kind: VMPodScrape
{{- else }}
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
{{- end }}
metadata:
  name: {{ template "pulsar.fullname" $root }}-{{ replace "." "-" $component }}
  labels:
    app: {{ template "pulsar.name" $root }}
    chart: {{ template "pulsar.chart" $root }}
    release: {{ $root.Release.Name }}
    heritage: {{ $root.Release.Service }}
spec:
  jobLabel: {{ replace "." "-" $component }}
  podMetricsEndpoints:
    - port: {{ $portName }}
      path: /metrics
      scheme: http
      interval: {{ $valuesPath.podMonitor.interval }}
      scrapeTimeout: {{ $valuesPath.podMonitor.scrapeTimeout }}
      # Set honor labels to true to allow overriding namespace label with Pulsar's namespace label
      honorLabels: true
      {{- if index $root.Values "victoria-metrics-k8s-stack" "enabled" }}
      relabelConfigs:
      {{- else }}
      relabelings:
      {{- end }}
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
        - sourceLabels: [__meta_kubernetes_namespace]
          action: replace
          targetLabel: kubernetes_namespace
        - sourceLabels: [__meta_kubernetes_pod_label_component]
          action: replace
          targetLabel: job
        - sourceLabels: [__meta_kubernetes_pod_name]
          action: replace
          targetLabel: kubernetes_pod_name
      {{- if or $valuesPath.podMonitor.metricRelabelings (and $valuesPath.podMonitor.dropUnderscoreCreatedMetrics (index $valuesPath.podMonitor.dropUnderscoreCreatedMetrics "enabled")) }}
      {{- if index $root.Values "victoria-metrics-k8s-stack" "enabled" }}
      metricRelabelConfigs:
      {{- else }}
      metricRelabelings:
      {{- end }}
      {{- if and $valuesPath.podMonitor.dropUnderscoreCreatedMetrics (index $valuesPath.podMonitor.dropUnderscoreCreatedMetrics "enabled") }}
        # Drop metrics that end with _created, auto-created by metrics library to match OpenMetrics format
        - sourceLabels: [__name__]
          {{- if and (hasKey $valuesPath.podMonitor.dropUnderscoreCreatedMetrics "excludePatterns") $valuesPath.podMonitor.dropUnderscoreCreatedMetrics.excludePatterns }}
          regex: "(?!{{ $valuesPath.podMonitor.dropUnderscoreCreatedMetrics.excludePatterns | join "|" }}).*_created$"
          {{- else }}
          regex: ".*_created$"
          {{- end }}
          action: drop
      {{- end }}
      {{- with $valuesPath.podMonitor.metricRelabelings }}
{{ toYaml . | indent 8 }}
      {{- end }}
      {{- end }}
  selector:
    matchLabels:
      {{- include "pulsar.matchLabels" $root | nindent 6 }}
      {{ $matchLabel }}
{{- end -}}