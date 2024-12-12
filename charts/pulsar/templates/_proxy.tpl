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
Define Proxy TLS certificate secret name
*/}}
{{- define "pulsar.proxy.tls.secret.name" -}}
{{- if .Values.tls.proxy.existingCertSecret -}}
{{- .Values.tls.proxy.existingCertSecret -}}
{{- else -}}
{{ .Release.Name }}-{{ .Values.tls.proxy.cert_name }}
{{- end -}}
{{- end -}}

{{/*
Define proxy certs mounts
*/}}
{{- define "pulsar.proxy.certs.volumeMounts" -}}
{{- if and .Values.tls.enabled (or .Values.tls.proxy.enabled .Values.tls.broker.enabled) }}
{{- if .Values.tls.proxy.enabled }}
- mountPath: "/pulsar/certs/proxy"
  name: proxy-certs
  readOnly: true
{{- if .Values.tls.proxy.selfSigned }}
- mountPath: "/pulsar/certs/ca"
  name: proxy-ca
  readOnly: true
{{- end }}
{{- end }}
{{- if .Values.tls.broker.enabled }}
- mountPath: "/pulsar/certs/broker"
  name: broker-ca
  readOnly: true
{{- end }}
{{- end }}
{{- end }}

{{/*
Define proxy certs volumes
*/}}
{{- define "pulsar.proxy.certs.volumes" -}}
{{- if and .Values.tls.enabled .Values.tls.proxy.enabled }}
{{- if .Values.tls.proxy.selfSigned }}
- name: proxy-ca
  secret:
    secretName: "{{ template "pulsar.tls.ca.secret.name" . }}"
    items:
      - key: ca.crt
        path: ca.crt
  {{- end }}
- name: proxy-certs
  secret:
    secretName: "{{ template "pulsar.proxy.tls.secret.name" . }}"
    items:
      - key: tls.crt
        path: tls.crt
      - key: tls.key
        path: tls.key
{{- end }}
{{- if and .Values.tls.enabled .Values.tls.broker.enabled }}
- name: broker-ca
  secret:
    secretName: "{{ template "pulsar.tls.ca.secret.name" . }}"
    items:
      - key: ca.crt
        path: ca.crt
{{- end }}
{{- end }}