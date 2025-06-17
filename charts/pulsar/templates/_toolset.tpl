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
Define the pulsar toolset service
*/}}
{{- define "pulsar.toolset.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.toolset.component }}
{{- end }}

{{/*
Define the toolset hostname
*/}}
{{- define "pulsar.toolset.hostname" -}}
${HOSTNAME}.{{ template "pulsar.toolset.service" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}

{{/*
Define toolset zookeeper client tls settings
*/}}
{{- define "pulsar.toolset.zookeeper.tls.settings" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled -}}
{{- include "pulsar.component.zookeeper.tls.settings" (dict "component" "toolset" "isClient" true "isCacerts" .Values.tls.toolset.cacerts.enabled) -}}
{{- end -}}
{{- end }}

{{/*
Define toolset tls certs mounts
*/}}
{{- define "pulsar.toolset.certs.volumeMounts" -}}
{{- if .Values.tls.enabled }}
{{- if or .Values.tls.broker.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: toolset-certs
  mountPath: "/pulsar/certs/toolset"
  readOnly: true
{{- end }}
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- if .Values.tls.toolset.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: toolset-cacerts
{{- range $cert := .Values.tls.toolset.cacerts.certs }}
- name: {{ $cert.name }}
  mountPath: "/pulsar/certs/{{ $cert.name }}"
  readOnly: true
{{- end }}
- name: certs-scripts
  mountPath: "/pulsar/bin/certs-combine-pem.sh"
  subPath: certs-combine-pem.sh
{{- end }}
{{- end }}

{{/*
Define toolset tls certs volumes
*/}}
{{- define "pulsar.toolset.certs.volumes" -}}
{{- if .Values.tls.enabled  }}
{{- if or .Values.tls.broker.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: toolset-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.toolset.cert_name }}"
    items:
    - key: tls.crt
      path: tls.crt
    - key: tls.key
      path: tls.key
    - key: tls-combined.pem
      path: tls-combined.pem
{{- end }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
    - key: ca.crt
      path: ca.crt
{{- end }}
{{- if .Values.tls.toolset.cacerts.enabled }}
- name: toolset-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.toolset.cacerts.certs }}
- name: {{ $cert.name }}
  secret:
    secretName: "{{ $cert.existingSecret }}"
    items:
    {{- range $key := $cert.secretKeys }}
      - key: {{ $key }}
        path: {{ $key }}
    {{- end }}
{{- end }}
- name: certs-scripts
  configMap:
    name: "{{ template "pulsar.fullname" . }}-certs-scripts"
    defaultMode: 0755
{{- end }}
{{- end }}
