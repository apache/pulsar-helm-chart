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
Define the pulsar autorecovery service
*/}}
{{- define "pulsar.autorecovery.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.autorecovery.component }}
{{- end }}

{{/*
Define the autorecovery hostname
*/}}
{{- define "pulsar.autorecovery.hostname" -}}
${HOSTNAME}.{{ template "pulsar.autorecovery.service" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}

{{/*
Define autorecovery zookeeper client tls settings
*/}}
{{- define "pulsar.autorecovery.zookeeper.tls.settings" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
{{- include "pulsar.component.zookeeper.tls.settings" (dict "component" "autorecovery" "isClient" true "isCacerts" .Values.tls.autorecovery.cacerts.enabled) -}}
{{- end }}
{{- end }}

{{/*
Define autorecovery tls certs mounts
*/}}
{{- define "pulsar.autorecovery.certs.volumeMounts" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- name: autorecovery-certs
  mountPath: "/pulsar/certs/autorecovery"
  readOnly: true
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- if .Values.tls.autorecovery.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: autorecovery-cacerts
{{- range $cert := .Values.tls.autorecovery.cacerts.certs }}
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
Define autorecovery tls certs volumes
*/}}
{{- define "pulsar.autorecovery.certs.volumes" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- name: autorecovery-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.autorecovery.cert_name }}"
    items:
    - key: tls.crt
      path: tls.crt
    - key: tls.key
      path: tls.key
    - key: tls-combined.pem
      path: tls-combined.pem
- name: ca
  secret:
    secretName: "{{ template "pulsar.certs.issuers.ca.secretName" . }}"
    items:
    - key: ca.crt
      path: ca.crt
{{- end }}
{{- if .Values.tls.autorecovery.cacerts.enabled }}
- name: autorecovery-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.autorecovery.cacerts.certs }}
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
Define autorecovery init container : verify cluster id
*/}}
{{- define "pulsar.autorecovery.init.verify_cluster_id" -}}
bin/apply-config-from-env.py conf/bookkeeper.conf;
export BOOKIE_MEM="-Xmx128M";
{{- include "pulsar.autorecovery.zookeeper.tls.settings" . }}
until timeout 15 bin/bookkeeper shell whatisinstanceid; do
  sleep 3;
done;
{{- end }}
