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
Service name for the Oxia certificate (see pulsar.cert.template): the servers' headless service
*/}}
{{- define "pulsar.oxia.service" -}}
{{ template "pulsar.oxia.server.service" . }}
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
  {{- $publicservicename := printf "%s-%s" (include "pulsar.fullname" .) .Values.oxia.component }}
  {{- $fqdnSuffix := printf "%s.svc.%s" (include "pulsar.namespace" .) .Values.clusterDomain }}

  {{- $podnamePrefix := printf "%s-%s-server-" (include "pulsar.fullname" .) .Values.oxia.component }}
  {{- $publicPort := $.Values.oxia.server.ports.public }}
  {{- range until (int .Values.oxia.server.replicas) }}
  {{- $podnameIndex := . }}
  {{- $podname := printf "%s%d.%s" $podnamePrefix $podnameIndex $servicename }}
  {{- $podnameFQDN := printf "%s.%s" $podname $fqdnSuffix }}
  - public: {{ $podnameFQDN }}:{{ $publicPort }}
    internal: {{ $podname }}:{{ $.Values.oxia.server.ports.internal }}
  {{- end }}
allowExtraAuthorities:
  # Authority hostnames clients use before they receive shard assignments.
  # Required since Oxia 0.16.3 (oxia-db/oxia#1038) — bootstrap connections
  # to the headless/public services must be in this list or be a configured
  # public address; otherwise the data server rejects them.
  - {{ $servicename }}:{{ $publicPort }}
  - {{ $servicename }}.{{ $fqdnSuffix }}:{{ $publicPort }}
  - {{ $publicservicename }}:{{ $publicPort }}
  - {{ $publicservicename }}.{{ $fqdnSuffix }}:{{ $publicPort }}
  {{- range .Values.oxia.coordinator.allowExtraAuthorities }}
  - {{ . }}
  {{- end }}
{{- end }}

{{/*
Define coordinator entrypoint
*/}}
{{- define "oxia.coordinator.entrypoint" -}}
- "oxia"
- "coordinator"
{{- if .Values.oxia.coordinator.customConfigMapName }}
- "--conf=configmap:{{ template "pulsar.namespace" . }}/{{ .Values.oxia.coordinator.customConfigMapName }}"
{{- else }}
- "--conf=configmap:{{ template "pulsar.namespace" . }}/{{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-coordinator"
{{- end }}
- "--log-json"
- "--metadata=configmap"
- "--k8s-namespace={{ template "pulsar.namespace" . }}"
- "--k8s-configmap-name={{ template "pulsar.fullname" . }}-{{ .Values.oxia.component }}-coordinator-status"
{{- if .Values.oxia.pprofEnabled }}
- "--profile"
{{- end}}
{{- if include "pulsar.oxia.tls.enabled" . }}
{{ include "pulsar.oxia.peer.tls.args" . }}
{{- end }}
{{- end}}

{{/*
Whether TLS is enabled for the traffic between the Oxia processes
*/}}
{{- define "pulsar.oxia.tls.enabled" -}}
{{- if and .Values.components.oxia .Values.tls.enabled .Values.tls.oxia.enabled -}}
true
{{- end -}}
{{- end -}}

{{/*
Client TLS flags for the connections to the servers' internal endpoint: replication between the
servers and the coordinator's calls. The servers share one certificate, so the connections verify
it against the headless service name, which the certificate includes in every SAN mode.
*/}}
{{- define "pulsar.oxia.peer.tls.args" -}}
- "--peer-tls-cert-file=/pulsar/certs/oxia/tls.crt"
- "--peer-tls-key-file=/pulsar/certs/oxia/tls.key"
- "--peer-tls-trusted-ca-file=/pulsar/certs/ca/ca.crt"
- "--peer-tls-server-name={{ template "pulsar.oxia.server.service" . }}"
{{- end }}

{{/*
Define Oxia TLS certs mounts (when pulsar.oxia.tls.enabled)
*/}}
{{- define "pulsar.oxia.certs.volumeMounts" -}}
- mountPath: "/pulsar/certs/oxia"
  name: oxia-certs
  readOnly: true
- mountPath: "/pulsar/certs/ca"
  name: ca
  readOnly: true
{{- end }}

{{/*
Define Oxia TLS certs volumes (when pulsar.oxia.tls.enabled)
*/}}
{{- define "pulsar.oxia.certs.volumes" -}}
- name: oxia-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.oxia.cert_name }}"
    items:
      - key: tls.crt
        path: tls.crt
      - key: tls.key
        path: tls.key
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
      - key: ca.crt
        path: ca.crt
{{- end }}
