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
{{- include "pulsar.component.zookeeper.tls.settings" (dict "component" "zookeeper" "isClient" false "isCacerts" .Values.tls.zookeeper.cacerts.enabled) -}}
{{- end }}
{{- end }}

{{- define "pulsar.component.zookeeper.tls.settings" }}
{{- $component := .component -}}
{{- $isClient := .isClient -}}
{{- $keyFile := printf "/pulsar/certs/%s/tls-combined.pem" $component -}}
{{- $caFile := ternary "/pulsar/certs/cacerts/ca-combined.pem" "/pulsar/certs/ca/ca.crt" .isCacerts -}}
{{- if $isClient }}
echo $'\n' >> conf/pulsar_env.sh
echo "PULSAR_EXTRA_OPTS=\"\${PULSAR_EXTRA_OPTS} -Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty -Dzookeeper.client.secure=true -Dzookeeper.client.certReload=true -Dzookeeper.ssl.keyStore.location={{- $keyFile }} -Dzookeeper.ssl.keyStore.type=PEM -Dzookeeper.ssl.trustStore.location={{- $caFile }} -Dzookeeper.ssl.trustStore.type=PEM\"" >> conf/pulsar_env.sh
echo $'\n' >> conf/bkenv.sh
echo "BOOKIE_EXTRA_OPTS=\"\${BOOKIE_EXTRA_OPTS} -Dzookeeper.clientCnxnSocket=org.apache.zookeeper.ClientCnxnSocketNetty -Dzookeeper.client.secure=true -Dzookeeper.client.certReload=true -Dzookeeper.ssl.keyStore.location={{- $keyFile }} -Dzookeeper.ssl.keyStore.type=PEM -Dzookeeper.ssl.trustStore.location={{- $caFile }} -Dzookeeper.ssl.trustStore.type=PEM\"" >> conf/bkenv.sh
{{- else }}
echo $'\n' >> conf/pulsar_env.sh
echo "PULSAR_EXTRA_OPTS=\"\${PULSAR_EXTRA_OPTS} -Dzookeeper.ssl.keyStore.location={{- $keyFile }} -Dzookeeper.ssl.keyStore.type=PEM -Dzookeeper.ssl.trustStore.location={{- $caFile }} -Dzookeeper.ssl.trustStore.type=PEM\"" >> conf/pulsar_env.sh
{{- end }}
{{- end }}

{{/*
Define zookeeper tls certs mounts
*/}}
{{- define "pulsar.zookeeper.certs.volumeMounts" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- mountPath: "/pulsar/certs/zookeeper"
  name: zookeeper-certs
  readOnly: true
- mountPath: "/pulsar/certs/ca"
  name: ca
  readOnly: true
{{- end }}
{{- if .Values.tls.zookeeper.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: zookeeper-cacerts
{{- range $cert := .Values.tls.zookeeper.cacerts.certs }}
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
Define zookeeper tls certs volumes
*/}}
{{- define "pulsar.zookeeper.certs.volumes" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
- name: zookeeper-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.zookeeper.cert_name }}"
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
{{- if .Values.tls.zookeeper.cacerts.enabled }}
- name: zookeeper-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.zookeeper.cacerts.certs }}
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
