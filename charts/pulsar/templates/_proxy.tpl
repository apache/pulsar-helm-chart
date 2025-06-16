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
Define proxy tls certs mounts
*/}}
{{- define "pulsar.proxy.certs.volumeMounts" -}}
{{- if .Values.tls.proxy.enabled }}
- mountPath: "/pulsar/certs/proxy"
  name: proxy-certs
  readOnly: true
{{- end}}
{{- if .Values.tls.enabled }}
- mountPath: "/pulsar/certs/ca"
  name: ca
  readOnly: true
{{- end}}
{{- if .Values.tls.proxy.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: proxy-cacerts
{{- range $cert := .Values.tls.proxy.cacerts.certs }}
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
Define proxy tls certs volumes
*/}}
{{- define "pulsar.proxy.certs.volumes" -}}
{{- if .Values.tls.proxy.enabled }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
      - key: ca.crt
        path: ca.crt
- name: proxy-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.proxy.cert_name }}"
    items:
      - key: tls.crt
        path: tls.crt
      - key: tls.key
        path: tls.key
      {{- if .Values.tls.zookeeper.enabled }}
      - key: tls-combined.pem
        path: tls-combined.pem
      {{- end }}
{{- end}}
{{- if .Values.tls.proxy.cacerts.enabled }}
- name: proxy-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.proxy.cacerts.certs }}
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
