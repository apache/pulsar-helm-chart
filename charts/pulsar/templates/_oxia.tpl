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
Coordinator labels
*/}}
{{- define "oxia-cluster.coordinator.labels" -}}
{{ include "oxia-cluster.coordinator.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/part-of: oxia
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Coordinator selector labels
*/}}
{{- define "oxia-cluster.coordinator.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/component: oxia-coordinator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Server labels
*/}}
{{- define "oxia-cluster.server.labels" -}}
{{ include "oxia-cluster.server.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Server selector labels
*/}}
{{- define "oxia-cluster.server.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/component: oxia-server
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

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
Define the pulsar oxia
*/}}
{{- define "pulsar.oxia.connect" -}}
{{- if and (not .Values.components.zookeeper) .Values.components.oxia -}}
{{ template "pulsar.oxia.server.service" . }}:{{ .Values.oxia.server.ports.internal }}
{{- end -}}
{{- end -}}

{{/*
Define coordinator configmap
*/}}
{{- define "oxia.coordinator.config.yaml" -}}
namespaces:
  - name: broker
    initialShardCount: {{ .Values.oxia.initialShardCount }}
    replicationFactor: {{ .Values.oxia.replicationFactor }}
  - name: bookkeeper
    initialShardCount: {{ .Values.oxia.initialShardCount }}
    replicationFactor: {{ .Values.oxia.replicationFactor }}
servers:
  - public:  {{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-svc.{{ template "pulsar.namespace" . }}.svc.cluster.local:{{ .Values.oxia.server.ports.public }}
    internal:  {{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-svc.{{ template "pulsar.namespace" . }}.svc:{{ .Values.oxia.server.ports.internal }}
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

