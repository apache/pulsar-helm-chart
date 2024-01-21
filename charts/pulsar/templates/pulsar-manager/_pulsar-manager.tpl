{{/*
Define the pulsar brroker service
*/}}
{{- define "pulsar.manager-secrets" -}}
- name: USERNAME
  valueFrom:
    secretKeyRef:
      key: PULSAR_MANAGER_ADMIN_USER
      {{- if .Values.pulsar_manager.existingSecretName }}
      name: "{{ .Values.pulsar_manager.existingSecretName }}"
      {{- else }}
      name: "{{ template "pulsar.fullname" . }}-{{ .Values.pulsar_manager.component }}-secret"
      {{- end }}
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      key: PULSAR_MANAGER_ADMIN_PASSWORD
      {{- if .Values.pulsar_manager.existingSecretName }}
      name: "{{ .Values.pulsar_manager.existingSecretName }}"
      {{- else }}
      name: "{{ template "pulsar.fullname" . }}-{{ .Values.pulsar_manager.component }}-secret"
      {{- end }}
{{- end }}