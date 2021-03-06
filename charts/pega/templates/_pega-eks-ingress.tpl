{{- define "pega.eks.ingress" -}}
# Ingress to be used for {{ .name }}
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: {{ .name }}
  namespace: {{ .root.Release.Namespace }}
  annotations:
    # Ingress class used is 'alb'
    kubernetes.io/ingress.class: alb
{{ if (.node.service.domain) }}
    {{ template "eksHttpsAnnotationSnippet" }}
{{ else }}
{{- if (.node.ingress) }}
{{- if (.node.ingress.tls) }}
{{- if (eq .node.ingress.tls.enabled true) }}
    {{ template "eksHttpsAnnotationSnippet" }}
{{ if (.node.ingress.tls.ssl_annotation) }}
{{ toYaml .node.ingress.tls.ssl_annotation | indent 4 }}
{{ end }}
{{ end }}
{{ end }}
{{ else }}
    # specifies the ports that ALB used to listen on
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
{{ end }}
{{ end }}
{{- if .node.ingress.annotations }}
{{ toYaml .node.ingress.annotations | indent 4 }}
{{- else }}
    # override the default scheme internal as ALB should be internet-facing
    alb.ingress.kubernetes.io/scheme: internet-facing
    # set to ip mode to route traffic directly to the pods ip
    alb.ingress.kubernetes.io/target-type: ip
{{- end }}
{{- if not (and (.node.ingress.annotations) ( .node.ingress.annotations | quote | regexFind "alb.ingress.kubernetes.io/target-group-attributes:" ) ) }}
    # enable sticky sessions on target group
    alb.ingress.kubernetes.io/target-group-attributes: stickiness.enabled=true,stickiness.lb_cookie.duration_seconds={{ include "lbSessionCookieStickiness" . }}
{{- end }}
{{- if (.node.ingress.redirectToPegaSSO) }}
    alb.ingress.kubernetes.io/actions.redirect-to-pega-sso: '{"Type":"redirect","RedirectConfig":{"Host":"#{host}","Path":"/prweb/PRAuth/SSO","Port":"443","Protocol":"HTTPS","StatusCode":"HTTP_302"}}'
    
{{- end }}
spec:
  rules:
  {{ if (.node.service.domain) }}
  - http:
      paths:
      - backend:
          serviceName: ssl-redirect
          servicePort: use-annotation
  {{ else }}
  {{ if ( include "ingressTlsEnabled" . ) }}
  - http:
      paths:
      - backend:
          serviceName: ssl-redirect
          servicePort: use-annotation
  {{ end }}
  {{ end }}
  # The calls will be redirected from {{ .node.domain }} to below mentioned backend serviceName and servicePort.
  # To access the below service, along with {{ .node.domain }}, alb http port also has to be provided in the URL.
  - host: {{ template "domainName" dict "node" .node }}
    http:
      paths:
{{- if (.node.ingress.redirectToPegaSSO) }}
      - path: /
        backend:
          serviceName: redirect-to-pega-sso
          servicePort: use-annotation
      - path: /*
        backend:
          serviceName: {{ .name }}
          servicePort: {{ .node.service.port }}          
{{ else }}
      - backend:
          serviceName: {{ .name }}
          servicePort: {{ .node.service.port }}
{{- end }}
{{- if (.node.ingress.altHost) }}
  - host: {{ .node.ingress.altHost }}
    http:
      paths:
      - backend:
          serviceName: {{ .name }}
          servicePort: {{ .node.service.port }}
{{- end }}
---
{{- end }}
