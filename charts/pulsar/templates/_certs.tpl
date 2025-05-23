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