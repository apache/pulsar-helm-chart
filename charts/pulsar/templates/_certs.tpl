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
Return the service name for a component.
Usage: {{ include "pulsar.certs.component.service" (dict "root" . "componentKey" "broker") }}
*/}}
{{- define "pulsar.certs.component.service" -}}
{{- $templateName := printf "pulsar.%s.service" .componentKey -}}
{{- include $templateName .root -}}
{{- end -}}

{{/*
Return the headless service name for a component.
Usage: {{ include "pulsar.certs.component.service.headless" (dict "root" . "componentKey" "broker") }}
*/}}
{{- define "pulsar.certs.component.service.headless" -}}
{{- $templateName := printf "pulsar.%s.service.headless" .componentKey -}}
{{- include $templateName .root -}}
{{- end -}}

{{/*
Return the component replica count.
When autoscaling is enabled, uses maxReplicas; otherwise uses replicaCount.
Usage: {{ include "pulsar.certs.component.replicaCount" (dict "componentKey" "broker" "componentConfig" .Values.broker) }}
*/}}
{{- define "pulsar.certs.component.replicaCount" -}}
{{- $componentKey := .componentKey -}}
{{- $componentConfig := .componentConfig -}}
{{- if and $componentConfig.autoscaling $componentConfig.autoscaling.enabled -}}
{{- if not $componentConfig.autoscaling.maxReplicas -}}
{{- fail (printf "%s.autoscaling.maxReplicas must be defined when %s.autoscaling.enabled is true" $componentKey $componentKey) -}}
{{- end -}}
{{- $componentConfig.autoscaling.maxReplicas -}}
{{- else -}}
{{- $componentConfig.replicaCount -}}
{{- end -}}
{{- end -}}

{{/*
Common certificate template
Usage: {{- include "pulsar.cert.template" (dict "root" . "componentKey" "proxy" "componentConfig" .Values.proxy "tlsConfig" .Values.tls.proxy) -}}
*/}}
{{- define "pulsar.cert.template" -}}
{{- if eq .root.Values.certs.internal_issuer.apiVersion "cert-manager.io/v1beta1" -}}
{{- fail "cert-manager.io/v1beta1 is no longer supported. Please set certs.internal_issuer.apiVersion to cert-manager.io/v1" -}}
{{- end -}}
{{- $root := .root -}}
{{- $fullname := include "pulsar.fullname" .root -}}
{{- $component := .componentConfig.component -}}
{{- $namespace := include "pulsar.namespace" .root -}}
{{- $clusterDomain := .root.Values.clusterDomain -}}
{{- $service := include "pulsar.certs.component.service" (dict "root" .root "componentKey" .componentKey "component" $component) -}}
{{- $serviceHeadless := "" -}}
{{- $serviceDns := $service -}}
{{- if or (eq .componentKey "broker") (eq .componentKey "zookeeper") }}
{{- $serviceHeadless = include "pulsar.certs.component.service.headless" (dict "root" .root "componentKey" .componentKey "component" $component) -}}
{{- $serviceDns = $serviceHeadless -}}
{{- end -}}
{{- /* Per-pod FQDNs are under the service the pod's DNS records are published in: the StatefulSet's
serviceName, or the standalone Deployment's subdomain. These are headless services for broker, zookeeper,
function_worker and standalone. */ -}}
{{- $podServiceDns := $serviceDns -}}
{{- if or (eq .componentKey "function_worker") (eq .componentKey "standalone") }}
{{- $podServiceDns = include "pulsar.certs.component.service.headless" (dict "root" .root "componentKey" .componentKey "component" $component) -}}
{{- end -}}
{{- $sanMode := .root.Values.tls.common.sanMode -}}
{{- if not (has $sanMode (list "wildcard" "fqdn" "none")) -}}
{{- fail (printf "tls.common.sanMode must be one of: wildcard, fqdn, none (got %q)" $sanMode) -}}
{{- end -}}
apiVersion: "{{ .root.Values.certs.internal_issuer.apiVersion }}"
kind: Certificate
metadata:
  name: "{{ template "pulsar.fullname" .root }}-{{ .tlsConfig.cert_name }}"
  namespace: {{ template "pulsar.namespace" .root }}
  labels:
    {{- include "pulsar.standardLabels" .root | nindent 4 }}
spec:
{{- if .tlsConfig.secretAnnotations }}
  secretTemplate:
    annotations: {{ toYaml .tlsConfig.secretAnnotations | nindent 6 }}
{{- end }}
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
  commonName: "{{ template "pulsar.fullname" .root }}-{{ $component }}"
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
{{ if .tlsConfig.dnsNames }}
{{ toYaml .tlsConfig.dnsNames | indent 4 }}
{{ end }}
{{ if eq $sanMode "wildcard" }}
    - {{ printf "*.%s.%s.svc.%s" $serviceDns $namespace $clusterDomain | quote }}
{{ end }}
{{/* The proxy uses a regular ClusterIP service, so it does not need per-pod FQDN SANs. */}}
{{ if and (eq $sanMode "fqdn") (not (eq .componentKey "proxy")) }}
      {{- $replicaCount := (include "pulsar.certs.component.replicaCount" (dict "componentKey" .componentKey "componentConfig" .componentConfig) | int) -}}
      {{- if gt $replicaCount 0 }}
        {{- range $i := until $replicaCount }}
    - {{ printf "%s-%s-%d.%s.%s.svc.%s" $fullname $component $i $podServiceDns $namespace $clusterDomain | quote }}
        {{- end }}
      {{- end }}
{{ end }}
{{- /* The standalone pod uses its component name as hostname in the headless service subdomain. */}}
{{- if and (eq $sanMode "fqdn") (eq .componentKey "standalone") }}
    - {{ printf "%s.%s.%s.svc.%s" $component $podServiceDns $namespace $clusterDomain | quote }}
{{- end }}
{{ if or (eq .componentKey "broker") (eq .componentKey "zookeeper") }}
    - {{ printf "%s.%s.svc.%s" $serviceHeadless $namespace $clusterDomain | quote }}
{{ end }}
    - {{ printf "%s.%s.svc.%s" $service $namespace $clusterDomain | quote }}
    - {{ printf "%s" $service | quote }}
{{- if .tlsConfig.ipAddresses }}
  ipAddresses:
{{ toYaml .tlsConfig.ipAddresses | indent 4 }}
{{- end }}
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
