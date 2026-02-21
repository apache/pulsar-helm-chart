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
Define the pulsar certs ca issuer name
*/}}
{{- define "pulsar.certs.issuers.ca.name" -}}
{{- if .Values.certs.internal_issuer.enabled -}}
{{- if and (eq .Values.certs.internal_issuer.type "selfsigning") .Values.certs.issuers.selfsigning.name -}}
{{- .Values.certs.issuers.selfsigning.name -}}
{{- else if and (eq .Values.certs.internal_issuer.type "ca") .Values.certs.issuers.ca.name -}}
{{- .Values.certs.issuers.ca.name -}}
{{- else -}}
{{- template "pulsar.fullname" . }}-{{ .Values.certs.internal_issuer.component }}-ca-issuer
{{- end -}}
{{- else -}}
{{- if .Values.certs.issuers.ca.name -}}
{{- .Values.certs.issuers.ca.name -}}
{{- else -}}
{{- fail "certs.issuers.ca.name is required when TLS is enabled and certs.internal_issuer.enabled is false" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define the pulsar certs ca issuer secret name
*/}}
{{- define "pulsar.certs.issuers.ca.secretName" -}}
{{- if .Values.certs.internal_issuer.enabled -}}
{{- if and (eq .Values.certs.internal_issuer.type "selfsigning") .Values.certs.issuers.selfsigning.secretName -}}
{{- .Values.certs.issuers.selfsigning.secretName -}}
{{- else if and (eq .Values.certs.internal_issuer.type "ca") .Values.certs.issuers.ca.secretName -}}
{{- .Values.certs.issuers.ca.secretName -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Values.tls.ca_suffix -}}
{{- end -}}
{{- else -}}
{{- if .Values.certs.issuers.ca.secretName -}}
{{- .Values.certs.issuers.ca.secretName -}}
{{- else -}}
{{- fail "certs.issuers.ca.secretName is required when TLS is enabled and certs.internal_issuer.enabled is false" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common certificate template
Usage: {{- include "pulsar.cert.template" (dict "root" . "componentConfig" .Values.proxy "tlsConfig" .Values.tls.proxy) -}}
*/}}
{{- define "pulsar.cert.template" -}}
{{- if eq .root.Values.certs.internal_issuer.apiVersion "cert-manager.io/v1beta1" -}}
{{- fail "cert-manager.io/v1beta1 is no longer supported. Please set certs.internal_issuer.apiVersion to cert-manager.io/v1" -}}
{{- end -}}
apiVersion: "{{ .root.Values.certs.internal_issuer.apiVersion }}"
kind: Certificate
metadata:
  name: "{{ template "pulsar.fullname" .root }}-{{ .tlsConfig.cert_name }}"
  namespace: {{ template "pulsar.namespace" .root }}
  labels:
    {{- include "pulsar.standardLabels" .root | nindent 4 }}
spec:
  # Secret names are always required.
  secretName: "{{ .root.Release.Name }}-{{ .tlsConfig.cert_name }}"
{{- if .root.Values.tls.zookeeper.enabled }}
  additionalOutputFormats:
    - type: CombinedPEM
{{- end }}
  duration: "{{ .root.Values.tls.common.duration }}"
  renewBefore: "{{ .root.Values.tls.common.renewBefore }}"
  subject:
    organizations:
{{ toYaml .root.Values.tls.common.organization | indent 4 }}
  # The use of the common name field has been deprecated since 2000 and is
  # discouraged from being used.
  commonName: "{{ template "pulsar.fullname" .root }}-{{ .componentConfig.component }}"
  isCA: false
  privateKey:
    size: {{ .root.Values.tls.common.keySize }}
    algorithm: {{ .root.Values.tls.common.keyAlgorithm }}
    encoding: {{ .root.Values.tls.common.keyEncoding }}
  usages:
    - server auth
    - client auth
  # At least one of a DNS Name, USI SAN, or IP address is required.
  dnsNames:
{{- if .tlsConfig.dnsNames }}
{{ toYaml .tlsConfig.dnsNames | indent 4 }}
{{- end }}
    {{- if or (eq .componentConfig.component "broker") (eq .componentConfig.component "zookeeper") }}
    - {{ printf "*.%s-%s-headless.%s.svc.%s" (include "pulsar.fullname" .root) .componentConfig.component (include "pulsar.namespace" .root) .root.Values.clusterDomain | quote }}
    {{- end }}
    - {{ printf "*.%s-%s.%s.svc.%s" (include "pulsar.fullname" .root) .componentConfig.component (include "pulsar.namespace" .root) .root.Values.clusterDomain | quote }}
    - {{ printf "%s-%s" (include "pulsar.fullname" .root) .componentConfig.component | quote }}
  # Issuer references are always required.
  issuerRef:
    name: "{{ template "pulsar.certs.issuers.ca.name" .root }}"
    kind: "{{ default "Issuer" .root.Values.certs.issuers.ca.kind }}"
    group: "{{ default "cert-manager.io" .root.Values.certs.issuers.ca.group }}"
{{- end -}}

{{/*
CA certificates template
Usage: {{ include "pulsar.certs.cacerts" (dict "certs" .Values.tls.<component>.cacerts.certs) }}
*/}}
{{- define "pulsar.certs.cacerts" -}}
{{- $certs := .certs -}}
{{- $cacerts := list -}}
{{- $cacerts = print "/pulsar/certs/ca/ca.crt" | append $cacerts -}}
{{- range $cert := $certs -}}
{{- range $key := $cert.secretKeys -}}
{{- $cacerts = print "/pulsar/certs/" $cert.name "/" $key | append $cacerts -}}
{{- end -}}
{{- end -}}
{{ join " " $cacerts }}
{{- end -}}
