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
Define the pulsar brroker service
*/}}
{{- define "pulsar.broker.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.broker.component }}
{{- end }}

{{/*
Define the hostname
*/}}
{{- define "pulsar.broker.hostname" -}}
${HOSTNAME}.{{ template "pulsar.broker.service" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}

{{/*
Define the broker znode
*/}}
{{- define "pulsar.broker.znode" -}}
{{ .Values.metadataPrefix }}/loadbalance/brokers/{{ template "pulsar.broker.hostname" . }}:{{ .Values.broker.ports.http }}
{{- end }}

{{/*
Define broker zookeeper client tls settings
*/}}
{{- define "pulsar.broker.zookeeper.tls.settings" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
{{- include "pulsar.component.zookeeper.tls.settings" (dict "component" "broker" "isClient" true "isCacerts" .Values.tls.broker.cacerts.enabled) -}}
{{- end }}
{{- end }}

{{/*
Define broker tls certs mounts
*/}}
{{- define "pulsar.broker.certs.volumeMounts" -}}
{{- if .Values.tls.enabled }}
{{- if or .Values.tls.broker.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: broker-certs
  mountPath: "/pulsar/certs/broker"
  readOnly: true
{{- end }}
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- if .Values.tls.broker.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: broker-cacerts
{{- range $cert := .Values.tls.broker.cacerts.certs }}
- name: {{ $cert.name }}
  mountPath: "/pulsar/certs/{{ $cert.name }}"
  readOnly: true
{{- end }}
- name: certs-scripts
  mountPath: "/pulsar/bin/certs-combine-pem.sh"
  subPath: certs-combine-pem.sh
- name: certs-scripts
  mountPath: "/pulsar/bin/certs-combine-pem-infinity.sh"
  subPath: certs-combine-pem-infinity.sh
{{- end }}
{{- end }}

{{/*
Define broker tls certs volumes
*/}}
{{- define "pulsar.broker.certs.volumes" -}}
{{- if .Values.tls.enabled }}
{{- if or .Values.tls.broker.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: broker-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.broker.cert_name }}"
    items:
    - key: tls.crt
      path: tls.crt
    - key: tls.key
      path: tls.key
{{- if .Values.tls.zookeeper.enabled }}
    - key: tls-combined.pem
      path: tls-combined.pem
{{- end }}
{{- end }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
    - key: ca.crt
      path: ca.crt
{{- end }}
{{- if .Values.tls.broker.cacerts.enabled }}
- name: broker-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.broker.cacerts.certs }}
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
