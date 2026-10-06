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

{{/* vim: set filetype=mustache: */}}

{{/*
pulsar home
*/}}
{{- define "pulsar.home" -}}
{{- print "/pulsar" -}}
{{- end -}}

{{/*
Expand the name of the chart.
*/}}
{{- define "pulsar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Expand the namespace of the chart.
*/}}
{{- define "pulsar.namespace" -}}
{{- default .Release.Namespace .Values.namespace  -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pulsar.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Define cluster's name
*/}}
{{- define "pulsar.cluster.name" -}}
{{- if .Values.clusterName }}
{{- .Values.clusterName }}
{{- else -}}
{{- template "pulsar.fullname" .}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pulsar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the common labels.
*/}}
{{- define "pulsar.standardLabels" -}}
app: {{ template "pulsar.name" . }}
chart: {{ template "pulsar.chart" . }}
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
cluster: {{ template "pulsar.cluster.name" . }}
{{- if .Values.labels }}
{{ .Values.labels | toYaml | trim }}
{{- end }}
{{- end }}

{{/*
Create the template labels.
*/}}
{{- define "pulsar.template.labels" -}}
app: {{ template "pulsar.name" . }}
release: {{ .Release.Name }}
cluster: {{ template "pulsar.cluster.name" . }}
{{- if .Values.labels }}
{{ .Values.labels | toYaml | trim }}
{{- end }}
{{- end }}

{{/*
Create the match labels.
*/}}
{{- define "pulsar.matchLabels" -}}
app: {{ template "pulsar.name" . }}
release: {{ .Release.Name }}
{{- end }}

{{/*
Render a pod-level securityContext.

Merges the chart-wide `.Values.podSecurityContext` defaults with a per-component
`<component>.securityContext` override, where the per-component value wins. Renders
nothing when both are empty, so charts that set neither are unaffected.

Usage:
  {{- include "pulsar.podSecurityContext" (dict "securityContext" .Values.broker.securityContext "root" . "indent" 6) }}
*/}}
{{- define "pulsar.podSecurityContext" -}}
{{- include "pulsar.mergedSecurityContext" (dict "global" .root.Values.podSecurityContext "component" .securityContext "indent" .indent) -}}
{{- end -}}

{{/*
Render a container-level securityContext.

Merges the chart-wide `.Values.containerSecurityContext` defaults with a per-component
`<component>.containerSecurityContext` override, where the per-component value wins.
Applies to both containers and initContainers. Renders nothing when both are empty.

Usage:
  {{- include "pulsar.containerSecurityContext" (dict "securityContext" .Values.broker.containerSecurityContext "root" . "indent" 8) }}
*/}}
{{- define "pulsar.containerSecurityContext" -}}
{{- include "pulsar.mergedSecurityContext" (dict "global" .root.Values.containerSecurityContext "component" .securityContext "indent" .indent) -}}
{{- end -}}

{{/*
Merge a global and a per-component securityContext and render the resulting block,
indented by `indent` spaces. Nested maps are deep-merged; the per-component value
takes precedence. Renders nothing when the merged result is empty.

`mergeOverwrite` is used rather than `merge` because `merge` treats zero values
(`0`, `false`, `""`) in its destination as absent, which would silently discard a
per-component `fsGroup: 0` or `allowPrivilegeEscalation: false` override.
Both operands are deep-copied so that `.Values` is never mutated.
*/}}
{{- define "pulsar.mergedSecurityContext" -}}
{{- $global := deepCopy (.global | default dict) -}}
{{- $component := deepCopy (.component | default dict) -}}
{{- $merged := mergeOverwrite $global $component -}}
{{- if $merged -}}
{{- printf "securityContext:\n%s" (toYaml $merged | indent 2) | nindent (int .indent) -}}
{{- end -}}
{{- end -}}

{{/*
Resolve the effective emptyDirVolumes list for a component, returned as JSON (a template
can only return a string; callers pipe it through `fromJsonArray`).

Precedence, highest first:
  1. `<component>.emptyDirVolumes`
  2. the caller's `default`, passed only by components that do not run the Pulsar image,
     so that the chart-wide list -- which describes the Pulsar layout -- cannot apply
  3. `.Values.emptyDirVolumes`
  4. the chart default below, a copy of the values.yaml default. `helm upgrade
     --reuse-values` does not coalesce in new chart defaults, so the key is absent there;
     treating that as `[]` would give a read-only root filesystem and none of the volumes
     that make it work. Keep the two copies in sync.
A list REPLACES the one above it rather than extending it, because Helm merges maps per
key but replaces lists whole.

Entries whose path the component already mounts via `extraVolumeMounts` are dropped: a
duplicate mountPath is rejected by the API server, so an existing setup that provides one
of these paths itself keeps working.

Usage:
  {{- $edv := fromJsonArray (include "pulsar.emptyDirVolumes.resolve" (dict "component" .Values.broker "root" .)) }}
*/}}
{{- define "pulsar.emptyDirVolumes.resolve" -}}
{{- $list := list (dict "path" "/pulsar/conf" "seedFromImage" true) (dict "path" "/pulsar/logs" "sizeLimit" "1Gi") (dict "path" "/tmp" "sizeLimit" "1Gi") -}}
{{- if hasKey .root.Values "emptyDirVolumes" -}}
{{- $list = .root.Values.emptyDirVolumes | default list -}}
{{- end -}}
{{- if hasKey . "default" -}}
{{- $list = .default | default list -}}
{{- end -}}
{{- $component := .component | default dict -}}
{{- if hasKey $component "emptyDirVolumes" -}}
{{- $list = (index $component "emptyDirVolumes") | default list -}}
{{- end -}}
{{- include "pulsar.emptyDirVolumes.validate" $list -}}
{{- $mounted := list -}}
{{- range (index $component "extraVolumeMounts") | default list -}}
{{- $mounted = append $mounted .mountPath -}}
{{- end -}}
{{- $effective := list -}}
{{- range $list -}}
{{- if not (has .path $mounted) -}}
{{- $effective = append $effective . -}}
{{- end -}}
{{- end -}}
{{- $effective | toJson -}}
{{- end -}}

{{/*
Whether to render the emptyDir volumes for a component: true when the effective container
securityContext sets `readOnlyRootFilesystem` and the resolved list is non-empty. The
merge matches `pulsar.containerSecurityContext`, so a component that opts out of a
read-only root filesystem also opts out of these volumes.

Usage (as a guard):
  {{- if include "pulsar.emptyDirVolumes.enabled" (dict "securityContext" .Values.broker.containerSecurityContext "volumes" $edv "root" .) }}
*/}}
{{- define "pulsar.emptyDirVolumes.enabled" -}}
{{- $global := deepCopy (.root.Values.containerSecurityContext | default dict) -}}
{{- $override := deepCopy (.securityContext | default dict) -}}
{{- if and (mergeOverwrite $global $override).readOnlyRootFilesystem .volumes -}}
true
{{- end -}}
{{- end -}}

{{/*
Turn a path into a DNS-1123 volume name: /pulsar/conf -> pulsar-conf, /tmp -> tmp.
*/}}
{{- define "pulsar.emptyDirVolumes.name" -}}
{{- $n := . | trim | trimAll "/" | replace "/" "-" | replace "_" "-" | replace "." "-" | lower -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]*[a-z0-9])?$" $n) -}}
{{- fail (printf "emptyDirVolumes: path %q does not yield a valid volume name (got %q)" . $n) -}}
{{- end -}}
{{- if gt (len $n) 63 -}}
{{- fail (printf "emptyDirVolumes: path %q yields the volume name %q, which exceeds the 63 character limit for a Kubernetes name" . $n) -}}
{{- end -}}
{{- $n -}}
{{- end -}}

{{/*
Validate an emptyDirVolumes list. Every entry needs an absolute `path` and no key beyond
path/seedFromImage/sizeLimit -- a typo such as `seedFromimage` would otherwise leave the
conf directory unseeded and only fail at runtime. No two entries may collide on path or on
derived name (/pulsar/logs and /pulsar-logs both give pulsar-logs).
*/}}
{{- define "pulsar.emptyDirVolumes.validate" -}}
{{- if not (kindIs "slice" .) -}}
{{- fail (printf "emptyDirVolumes must be a list, got %v (%s). Note that `--set emptyDirVolumes=[]` assigns the string \"[]\"; use a values file to set an empty list." . (kindOf .)) -}}
{{- end -}}
{{- $names := dict -}}
{{- $paths := dict -}}
{{- range . -}}
{{- if not (kindIs "map" .) -}}
{{- fail (printf "emptyDirVolumes: every entry must be a mapping with a `path` key, got %v (%s)." . (kindOf .)) -}}
{{- end -}}
{{- range $k, $_ := . -}}
{{- if not (has $k (list "path" "seedFromImage" "sizeLimit")) -}}
{{- fail (printf "emptyDirVolumes: unknown key %q; supported keys are path, seedFromImage and sizeLimit" $k) -}}
{{- end -}}
{{- end -}}
{{- if not .path -}}
{{- fail "emptyDirVolumes: every entry requires a `path`" -}}
{{- end -}}
{{- if not (hasPrefix "/" .path) -}}
{{- fail (printf "emptyDirVolumes: path %q must be absolute" .path) -}}
{{- end -}}
{{- if hasKey $paths .path -}}
{{- fail (printf "emptyDirVolumes: path %q is listed twice" .path) -}}
{{- end -}}
{{- $_ := set $paths .path true -}}
{{- $n := include "pulsar.emptyDirVolumes.name" .path -}}
{{- if hasKey $names $n -}}
{{- fail (printf "emptyDirVolumes: paths %q and %q both map to volume name %q; rename one" (index $names $n) .path $n) -}}
{{- end -}}
{{- $_ := set $names $n .path -}}
{{- end -}}
{{- end -}}

{{/*
The emptyDir volumes for a resolved list.

Usage:
  {{- include "pulsar.emptyDirVolumes.volumes" $edv | nindent 6 }}
*/}}
{{- define "pulsar.emptyDirVolumes.volumes" -}}
{{- range . }}
- name: {{ include "pulsar.emptyDirVolumes.name" .path }}
  emptyDir:
    {{- if .sizeLimit }}
    sizeLimit: {{ .sizeLimit }}
    {{- else }}
    {}
    {{- end }}
{{- end -}}
{{- end -}}

{{/*
The matching mounts, applied to every container and initContainer of the component.

Usage:
  {{- include "pulsar.emptyDirVolumes.mounts" $edv | nindent 8 }}
*/}}
{{- define "pulsar.emptyDirVolumes.mounts" -}}
{{- range . }}
- name: {{ include "pulsar.emptyDirVolumes.name" .path }}
  mountPath: {{ .path }}
{{- end -}}
{{- end -}}

{{/*
An initContainer that seeds the entries marked `seedFromImage: true`, because an emptyDir
starts empty and the Pulsar images rewrite files under /pulsar/conf that must exist.

Must render as the *first* initContainer, ahead of any built-in one that reads the seeded
path. Each seeded volume is mounted at /mnt/<name>, not at its real path, so it does not
shadow the copy in the image. `cp -r` rather than `cp -a`: preserving ownership fails as a
non-root user. Renders nothing when no entry is seeded.

Usage:
  {{- include "pulsar.emptyDirVolumes.seedContainer" (dict "volumes" $edv "image" .Values.images.broker "securityContext" .Values.broker.containerSecurityContext "root" .) | nindent 6 }}
*/}}
{{- define "pulsar.emptyDirVolumes.seedContainer" -}}
{{- $seed := list -}}
{{- range .volumes -}}
{{- if .seedFromImage -}}
{{- $seed = append $seed . -}}
{{- end -}}
{{- end -}}
{{- if $seed -}}
- name: copy-pulsar-conf
  image: "{{ template "pulsar.imageFullName" (dict "image" .image "root" .root) }}"
  imagePullPolicy: "{{ template "pulsar.imagePullPolicy" (dict "image" .image "root" .root) }}"
  {{- include "pulsar.containerSecurityContext" (dict "securityContext" .securityContext "root" .root "indent" 2) }}
  resources: {{ toYaml .root.Values.initContainer.resources | nindent 4 }}
  command: ["sh", "-c"]
  args:
  - |
    {{- range $seed }}
    cp -r {{ .path }}/. /mnt/{{ include "pulsar.emptyDirVolumes.name" .path }}/
    {{- end }}
  volumeMounts:
  {{- range $seed }}
  - name: {{ include "pulsar.emptyDirVolumes.name" .path }}
    mountPath: /mnt/{{ include "pulsar.emptyDirVolumes.name" .path }}
  {{- end }}
{{- end -}}
{{- end -}}

{{/*
Create ImagePullSecrets
*/}}
{{- define "pulsar.imagePullSecrets" -}}
{{- if .Values.images.imagePullSecrets -}}
imagePullSecrets:
{{- range .Values.images.imagePullSecrets }}
- name: {{ . }}
{{- end }}
{{- end -}}
{{- end }}

{{/*
Create full image name
*/}}
{{- define "pulsar.imageFullName" -}}
{{- printf "%s:%s" (.image.repository | default .root.Values.defaultPulsarImageRepository) (.image.tag | default .root.Values.defaultPulsarImageTag | default .root.Chart.AppVersion) -}}
{{- end -}}

{{/*
Lookup pull policy, default to defaultPullPolicy
*/}}
{{- define "pulsar.imagePullPolicy" -}}
{{- printf "%s" (.image.pullPolicy | default .root.Values.defaultPullPolicy) -}}
{{- end -}}

