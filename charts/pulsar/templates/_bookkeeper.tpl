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
Define the pulsar bookkeeper service
*/}}
{{- define "pulsar.bookkeeper.service" -}}
{{ template "pulsar.fullname" . }}-{{ .Values.bookkeeper.component }}
{{- end }}

{{/*
Define the bookkeeper hostname
*/}}
{{- define "pulsar.bookkeeper.hostname" -}}
${HOSTNAME}.{{ template "pulsar.bookkeeper.service" . }}.{{ template "pulsar.namespace" . }}.svc.{{ .Values.clusterDomain }}
{{- end -}}


{{/*
Define bookie zookeeper client tls settings
*/}}
{{- define "pulsar.bookkeeper.zookeeper.tls.settings" -}}
{{- if and .Values.tls.enabled .Values.tls.zookeeper.enabled }}
{{- include "pulsar.component.zookeeper.tls.settings" (dict "component" "bookie" "isClient" true "isCacerts" .Values.tls.bookie.cacerts.enabled) -}}
{{- end }}
{{- end }}

{{/*
Define bookie tls certs mounts
*/}}
{{- define "pulsar.bookkeeper.certs.volumeMounts" -}}
{{- if .Values.tls.enabled }}
{{- if or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled }}
- name: bookie-certs
  mountPath: "/pulsar/certs/bookie"
  readOnly: true
{{- end }}
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- end }}
{{- if .Values.tls.bookie.cacerts.enabled }}
- mountPath: "/pulsar/certs/cacerts"
  name: bookie-cacerts
{{- range $cert := .Values.tls.bookie.cacerts.certs }}
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
Define bookie tls certs volumes
*/}}
{{- define "pulsar.bookkeeper.certs.volumes" -}}
{{- if .Values.tls.enabled }}
{{- if or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled }}
- name: bookie-certs
  secret:
    secretName: "{{ .Release.Name }}-{{ .Values.tls.bookie.cert_name }}"
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
{{- if .Values.tls.bookie.cacerts.enabled }}
- name: bookie-cacerts
  emptyDir: {}
{{- range $cert := .Values.tls.bookie.cacerts.certs }}
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
Define bookie common config
*/}}
{{- define "pulsar.bookkeeper.config.common" -}}
{{/*
Configure BookKeeper's metadata store (available since BookKeeper 4.7.0 / BP-29)
https://bookkeeper.apache.org/bps/BP-29-metadata-store-api-module/
https://bookkeeper.apache.org/docs/deployment/manual#cluster-metadata-setup
*/}}
# Set empty values for zkServers and zkLedgersRootPath since we're using the metadataServiceUri to configure BookKeeper's metadata store
zkServers: ""
zkLedgersRootPath: ""
{{- if .Values.components.zookeeper }}
{{- if (and (hasKey .Values.pulsar_metadata "bookkeeper") .Values.pulsar_metadata.bookkeeper.usePulsarMetadataBookieDriver) }}
# there's a bug when using PulsarMetadataBookieDriver since it always appends /ledgers to the metadataServiceUri
# Possibly a bug in org.apache.pulsar.metadata.bookkeeper.AbstractMetadataDriver#resolveLedgersRootPath in Pulsar code base
metadataServiceUri: "metadata-store:zk:{{ template "pulsar.zookeeper.connect" . }}{{ .Values.metadataPrefix }}"
{{- else }}
# use zk+hierarchical:// when using BookKeeper's built-in metadata driver
metadataServiceUri: "zk+hierarchical://{{ template "pulsar.zookeeper.connect" . }}{{ .Values.metadataPrefix }}/ledgers"
{{- end }}
{{- else if .Values.components.oxia }}
metadataServiceUri: "{{ template "pulsar.oxia.metadata.url.bookkeeper" . }}"
{{- end }}
{{- /* metadataStoreSessionTimeoutMillis maps to zkTimeout in bookkeeper.conf for both zookeeper and oxia metadata stores */}}
{{- if (and (hasKey .Values.pulsar_metadata "bookkeeper") (hasKey .Values.pulsar_metadata.bookkeeper "metadataStoreSessionTimeoutMillis")) }}
zkTimeout: "{{ .Values.pulsar_metadata.bookkeeper.metadataStoreSessionTimeoutMillis }}"
{{- end }}

# enable bookkeeper http server
httpServerEnabled: "true"
httpServerPort: "{{ .Values.bookkeeper.ports.http }}"
# use hostname as the bookie id
useHostNameAsBookieID: "true"
{{- end }}

{{/*
Define bookie tls config
*/}}
{{- define "pulsar.bookkeeper.config.tls" -}}
{{- if and .Values.tls.enabled .Values.tls.bookie.enabled }}
PULSAR_PREFIX_tlsProviderFactoryClass: org.apache.bookkeeper.tls.TLSContextFactory
PULSAR_PREFIX_tlsCertificatePath: /pulsar/certs/bookie/tls.crt  
PULSAR_PREFIX_tlsKeyStoreType: PEM
PULSAR_PREFIX_tlsKeyStore: /pulsar/certs/bookie/tls.key
PULSAR_PREFIX_tlsTrustStoreType: PEM
PULSAR_PREFIX_tlsTrustStore: {{ ternary "/pulsar/certs/cacerts/ca-combined.pem" "/pulsar/certs/ca/ca.crt" .Values.tls.bookie.cacerts.enabled | quote }}
{{- end }}
{{- end }}

{{/*
Render BookKeeper indexDirectories as comma-separated string.
Accepts either a string or a list of strings.
*/}}
{{- define "pulsar.bookkeeper.indexDirectories" -}}
{{- $v := .Values.bookkeeper.indexDirectories -}}
{{- if $v -}}
{{- if kindIs "string" $v -}}
{{- $v -}}
{{- else -}}
{{- $v | join "," -}}
{{- end -}}
{{- else if and .Values.bookkeeper.volumes.index.enabled .Values.bookkeeper.volumes.index.mountPath -}}
{{- .Values.bookkeeper.volumes.index.mountPath -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Define bookie init container : verify cluster id
*/}}
{{- define "pulsar.bookkeeper.init.verify_cluster_id" -}}
{{- if not (and .Values.volumes.persistence .Values.bookkeeper.volumes.persistence) }}
bin/apply-config-from-env.py conf/bookkeeper.conf;
export BOOKIE_MEM="-Xmx128M";
{{- include "pulsar.bookkeeper.zookeeper.tls.settings" . }}
until timeout 15 bin/bookkeeper shell whatisinstanceid; do
  sleep 3;
done;
bin/bookkeeper shell bookieformat -nonInteractive -force -deleteCookie || true
{{- end }}
{{- if and .Values.volumes.persistence .Values.bookkeeper.volumes.persistence }}
set -e;
bin/apply-config-from-env.py conf/bookkeeper.conf;
export BOOKIE_MEM="-Xmx128M";
{{- include "pulsar.bookkeeper.zookeeper.tls.settings" . }}
until timeout 15 bin/bookkeeper shell whatisinstanceid; do
  sleep 3;
done;
{{- end }}
{{- end }}
