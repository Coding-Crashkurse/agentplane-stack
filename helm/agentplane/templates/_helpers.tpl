{{- define "agentplane.fullname" -}}
{{- printf "%s" .Release.Name | trunc 53 | trimSuffix "-" -}}
{{- end -}}

{{- define "agentplane.labels" -}}
app.kubernetes.io/part-of: agentplane
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "agentplane.issuer" -}}
{{- if .Values.oidc.issuer -}}
{{- .Values.oidc.issuer -}}
{{- else -}}
https://{{ .Values.hosts.auth }}/realms/{{ .Values.keycloak.realm }}
{{- end -}}
{{- end -}}

{{- define "agentplane.postgresHost" -}}
{{- if .Values.postgres.enabled -}}
{{- include "agentplane.fullname" . }}-postgres
{{- else -}}
{{- required "postgres.externalHost is required when postgres.enabled=false" .Values.postgres.externalHost -}}
{{- end -}}
{{- end -}}

{{- define "agentplane.dbUrl" -}}
{{- $ := index . 0 -}}{{- $db := index . 1 -}}
postgresql+asyncpg://{{ $.Values.postgres.user }}:{{ $.Values.postgres.password }}@{{ include "agentplane.postgresHost" $ }}/{{ $db }}
{{- end -}}

{{- define "agentplane.appOrigin" -}}https://{{ .Values.hosts.app }}{{- end -}}
{{- define "agentplane.builderOrigin" -}}https://{{ .Values.hosts.builder }}{{- end -}}
{{- define "agentplane.publicBaseUrl" -}}https://{{ .Values.hosts.api }}{{- end -}}
