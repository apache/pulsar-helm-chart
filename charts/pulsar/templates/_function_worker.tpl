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
Define the function worker service (ordinary ClusterIP, targeted by the proxy and admin clients)
*/}}
{{- define "pulsar.function_worker.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.function_worker.component }}
{{- end }}

{{/*
Define the function worker headless service (used as the StatefulSet serviceName for pod DNS)
*/}}
{{- define "pulsar.function_worker.service.headless" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.function_worker.component }}-headless
{{- end }}

{{/*
Define the function worker pod hostname
*/}}
{{- define "pulsar.function_worker.hostname" -}}
${HOSTNAME}.{{ template "pulsar.function_worker.service.headless" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}

{{/*
Define function worker tls certs mounts.
The worker mounts its own server cert (when tls.function_worker.enabled) and the cluster CA so it can
trust the broker it connects to over TLS.
*/}}
{{- define "pulsar.function_worker.certs.volumeMounts" -}}
{{- if .Values.tls.enabled }}
{{- if .Values.tls.function_worker.enabled }}
- name: function-worker-certs
  mountPath: "/pulsar/certs/function-worker"
  readOnly: true
{{- end }}
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- if .Values.tls.function_worker.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: function-worker-cacerts
{{- range $cert := .Values.tls.function_worker.cacerts.certs }}
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
Define function worker tls certs volumes
*/}}
{{- define "pulsar.function_worker.certs.volumes" -}}
{{- if .Values.tls.enabled }}
{{- if .Values.tls.function_worker.enabled }}
- name: function-worker-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.function_worker.cert_name }}"
    items:
    - key: tls.crt
      path: tls.crt
    - key: tls.key
      path: tls.key
{{- end }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
    - key: ca.crt
      path: ca.crt
{{- end }}
{{- if .Values.tls.function_worker.cacerts.enabled }}
- name: function-worker-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.function_worker.cacerts.certs }}
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

{{/*
Define the function worker trust certs file path (cacerts bundle when enabled, otherwise the CA cert)
*/}}
{{- define "pulsar.function_worker.tlsTrustCertsFilePath" -}}
{{ ternary "/pulsar/certs/cacerts/ca-combined.pem" "/pulsar/certs/ca/ca.crt" .Values.tls.function_worker.cacerts.enabled }}
{{- end -}}
