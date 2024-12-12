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
/pulsar/keytool/keytool.sh bookie {{ template "pulsar.bookkeeper.hostname" . }} true;
{{- end }}
{{- end }}

{{/*
Define bookie tls certs mounts
*/}}
{{- define "pulsar.bookkeeper.certs.volumeMounts" -}}
{{- if and .Values.tls.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: bookie-certs
  mountPath: "/pulsar/certs/bookie"
  readOnly: true
- name: ca
  mountPath: "/pulsar/certs/ca"
  readOnly: true
{{- if .Values.tls.zookeeper.enabled }}
- name: keytool
  mountPath: "/pulsar/keytool/keytool.sh"
  subPath: keytool.sh
{{- end }}
{{- end }}
{{- end }}

{{/*
Define bookie tls certs volumes
*/}}
{{- define "pulsar.bookkeeper.certs.volumes" -}}
{{- if and .Values.tls.enabled (or .Values.tls.bookie.enabled .Values.tls.zookeeper.enabled) }}
- name: bookie-certs
  secret:
    secretName: "{{ template "pulsar.bookie.tls.secret.name" . }}"
    items:
    - key: tls.crt
      path: tls.crt
    - key: tls.key
      path: tls.key
{{- if .Values.tls.bookkeeper.untrustedCa }}
- name: ca
  secret:
    secretName: "{{ template "pulsar.tls.ca.secret.name" . }}"
    items:
    - key: ca.crt
      path: ca.crt
{{- end }}
{{- if .Values.tls.zookeeper.enabled }}
- name: keytool
  configMap:
    name: "{{ template "pulsar.fullname" . }}-keytool-configmap"
    defaultMode: 0755
{{- end }}
{{- end }}
{{- end }}

{{/*
Define bookie common config
*/}}
{{- define "pulsar.bookkeeper.config.common" -}}
{{- if .Values.components.zookeeper }}
zkServers: "{{ template "pulsar.zookeeper.connect" . }}"
zkLedgersRootPath: "{{ .Values.metadataPrefix }}/ledgers"
{{- else if .Values.components.oxia }}
metadataServiceUri: "{{ template "pulsar.oxia.metadata.url.bookkeeper" . }}"
{{- end }}
# enable bookkeeper http server
httpServerEnabled: "true"
httpServerPort: "{{ .Values.bookkeeper.ports.http }}"
# config the stats provider
statsProviderClass: org.apache.bookkeeper.stats.prometheus.PrometheusMetricsProvider
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
PULSAR_PREFIX_tlsTrustStore: /pulsar/certs/ca/ca.crt 
{{- end }}
{{- end }}

{{/*
Define bookie init container : verify cluster id
*/}}
{{- define "pulsar.bookkeeper.init.verify_cluster_id" -}}
{{- if not (and .Values.volumes.persistence .Values.bookkeeper.volumes.persistence) }}
bin/apply-config-from-env.py conf/bookkeeper.conf;
export BOOKIE_MEM="-Xmx128M";
{{- include "pulsar.bookkeeper.zookeeper.tls.settings" . -}}
until timeout 15 bin/bookkeeper shell whatisinstanceid; do
  sleep 3;
done;
bin/bookkeeper shell bookieformat -nonInteractive -force -deleteCookie || true
{{- end }}
{{- if and .Values.volumes.persistence .Values.bookkeeper.volumes.persistence }}
set -e;
bin/apply-config-from-env.py conf/bookkeeper.conf;
export BOOKIE_MEM="-Xmx128M";
{{- include "pulsar.bookkeeper.zookeeper.tls.settings" . -}}
until timeout 15 bin/bookkeeper shell whatisinstanceid; do
  sleep 3;
done;
{{- end }}
{{- end }}

{{/*
Define Bookie TLS certificate secret name
*/}}
{{- define "pulsar.bookie.tls.secret.name" -}}
{{- if .Values.tls.bookie.certSecretName -}}
{{- .Values.tls.bookie.certSecretName -}}
{{- else -}}
{{ .Release.Name }}-{{ .Values.tls.bookie.cert_name }}
{{- end -}}
{{- end -}}