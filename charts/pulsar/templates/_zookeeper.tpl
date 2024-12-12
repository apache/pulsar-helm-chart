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
Define the pulsar zookeeper
*/}}
{{- define "pulsar.zookeeper.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.zookeeper.component }}
{{- end }}

{{/*
Define the pulsar zookeeper
*/}}
{{- define "pulsar.zookeeper.connect" -}}
{{$zk:=.Values.pulsar_metadata.userProvidedZookeepers}}
{{- if and (not .Values.components.zookeeper) $zk }}
{{- $zk -}}
{{ else }}
{{- if not (and .Values.tls.enabled .Values.tls.zookeeper.enabled) -}}
{{ template "pulsar.zookeeper.service" . }}:{{ .Values.zookeeper.ports.client }}
{{- end -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled -}}
{{ template "pulsar.zookeeper.service" . }}:{{ .Values.zookeeper.ports.clientTls }}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define the zookeeper hostname
*/}}
{{- define "pulsar.zookeeper.hostname" -}}
${HOSTNAME}.{{ template "pulsar.zookeeper.service" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}

{{/*
Define zookeeper tls settings
*/}}
{{- define "pulsar.zookeeper.tls.settings" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
/pulsar/keytool/keytool.sh zookeeper {{ template "pulsar.zookeeper.hostname" . }} false;
{{- end }}
{{- end }}

{{/*
Define zookeeper certs mounts
*/}}
{{- define "pulsar.zookeeper.certs.volumeMounts" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- mountPath: "/pulsar/certs/zookeeper"
  name: zookeeper-certs
  readOnly: true
{{- if .Values.tls.zookeeper.untrustedCa }}
- mountPath: "/pulsar/certs/ca"
  name: ca
  readOnly: true
{{- end }}
- name: keytool
  mountPath: "/pulsar/keytool/keytool.sh"
  subPath: keytool.sh
{{- end }}
{{- end }}

{{/*
Define zookeeper certs volumes
*/}}
{{- define "pulsar.zookeeper.certs.volumes" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- name: zookeeper-certs
  secret:
    secretName: "{{ template "pulsar.zookeeper.tls.secret.name" . }}"
    items:
      - key: tls.crt
        path: tls.crt
      - key: tls.key
        path: tls.key
{{- if .Values.tls.zookeeper.untrustedCa }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.tls.ca.secret.name" . }}"
    items:
      - key: ca.crt
        path: ca.crt
{{- end}}
- name: keytool
  configMap:
    name: "{{ template "pulsar.fullname" . }}-keytool-configmap"
    defaultMode: 0755
{{- end}}
{{- end }}

{{/*
Define ZooKeeper TLS certificate secret name
*/}}
{{- define "pulsar.zookeeper.tls.secret.name" -}}
{{- if .Values.tls.zookeeper.certSecretName -}}
{{- .Values.tls.zookeeper.certSecretName -}}
{{- else -}}
{{ .Release.Name }}-{{ .Values.tls.zookeeper.cert_name }}
{{- end -}}
{{- end -}}