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

{{/*
Probe
*/}}
{{- define "oxia-cluster.probe" -}}
exec:
  command: ["oxia", "health", "--port={{ . }}"]
initialDelaySeconds: 10
timeoutSeconds: 10
{{- end }}


{{/*
Probe
*/}}
{{- define "oxia-cluster.readiness-probe" -}}
exec:
  command: ["oxia", "health", "--port={{ . }}", "--service=oxia-readiness"]
initialDelaySeconds: 10
timeoutSeconds: 10
{{- end }}

{{/*
Probe
*/}}
{{- define "oxia-cluster.startup-probe" -}}
exec:
  command: ["oxia", "health", "--port={{ . }}"]
initialDelaySeconds: 60
timeoutSeconds: 10
{{- end }}

{{/*
Define the pulsar oxia
*/}}
{{- define "pulsar.oxia.server.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-svc
{{- end }}

{{/*
oxia url for broker metadata
*/}}
{{- define "pulsar.oxia.metadata.url.broker" -}}
{{- if .Values.components.oxia -}}
oxia://{{ template "pulsar.oxia.server.service" . }}:{{ .Values.oxia.server.ports.public }}/broker
{{- end -}}
{{- end -}}

{{/*
oxia url for bookkeeper metadata
*/}}
{{- define "pulsar.oxia.metadata.url.bookkeeper" -}}
{{- if .Values.components.oxia -}}
metadata-store:oxia://{{ template "pulsar.oxia.server.service" . }}:{{ .Values.oxia.server.ports.public }}/bookkeeper
{{- end -}}
{{- end -}}

{{/*
Define coordinator configmap
*/}}
{{- define "oxia.coordinator.config.yaml" -}}
namespaces:
  - name: default
    initialShardCount: {{ .Values.oxia.initialShardCount }}
    replicationFactor: {{ .Values.oxia.replicationFactor }}
  - name: broker
    initialShardCount: {{ .Values.oxia.initialShardCount }}
    replicationFactor: {{ .Values.oxia.replicationFactor }}
  - name: bookkeeper
    initialShardCount: {{ .Values.oxia.initialShardCount }}
    replicationFactor: {{ .Values.oxia.replicationFactor }}
servers:
  {{- $servicename := printf "%s-%s-svc" (include "pulsar.fullname" .) .Values.oxia.component }}
  {{- $fqdnSuffix := printf "%s.svc.cluster.local" (include "pulsar.namespace" .) }}
  {{- $podnamePrefix := printf "%s-%s-server-" (include "pulsar.fullname" .) .Values.oxia.component }}
  {{- range until (int .Values.oxia.server.replicas) }}
  {{- $podnameIndex := . }}
  {{- $podname := printf "%s%d.%s" $podnamePrefix $podnameIndex $servicename }}
  {{- $podnameFQDN := printf "%s.%s" $podname $fqdnSuffix }}
  - public: {{ $podnameFQDN }}:{{ $.Values.oxia.server.ports.public }}
    internal: {{ $podname }}:{{ $.Values.oxia.server.ports.internal }}
  {{- end }}
{{- end }}

{{/*
Define coordinator entrypoint
*/}}
{{- define "oxia.coordinator.entrypoint" -}}
- "oxia"
- "coordinator"
- "--conf=configmap:{{ template "pulsar.namespace" . }}/{{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-coordinator"
- "--log-json"
- "--metadata=configmap"
- "--k8s-namespace={{ template "pulsar.namespace" . }}"
- "--k8s-configmap-name={{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-coordinator-status"
{{- if .Values.oxia.pprofEnabled }}
- "--profile"
{{- end}}
{{- end}}

