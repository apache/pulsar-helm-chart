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
Define the standalone service
*/}}
{{- define "pulsar.standalone.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.standalone.component }}
{{- end }}

{{/*
Define the standalone headless service
*/}}
{{- define "pulsar.standalone.service.headless" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.standalone.component }}-headless
{{- end }}

{{/*
Define standalone tls certs mounts
*/}}
{{- define "pulsar.standalone.certs.volumeMounts" -}}
{{- if .Values.tls.enabled }}
- name: standalone-certs
  mountPath: "/pulsar/certs/broker"
  readOnly: true
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- end }}

{{/*
Define standalone tls certs volumes
*/}}
{{- define "pulsar.standalone.certs.volumes" -}}
{{- if .Values.tls.enabled }}
- name: standalone-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.standalone.cert_name }}"
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
{{- end }}
