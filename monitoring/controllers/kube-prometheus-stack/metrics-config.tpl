kube-state-metrics:
  # For kube-prometheus-stacks that are already installed and configured with
  # custom collectors, commenting out the collectors and extraArgs below will
  # retain any existing kube-state-metrics configuration.
  collectors: [ ]
  resources:
    limits:
      cpu: 200m
      memory: 400Mi
    requests:
      cpu: 50m
      memory: 200Mi
  extraArgs:
    - --custom-resource-state-only=true
  rbac:
    extraRules:
      - apiGroups:
          # flux
          - source.toolkit.fluxcd.io
          - kustomize.toolkit.fluxcd.io
          - helm.toolkit.fluxcd.io
          - notification.toolkit.fluxcd.io
          - image.toolkit.fluxcd.io
          # user
          {{- range $v := .values.apiGroups }}
          - {{ $v }}
          {{- end }}
        resources:
          # user
          {{- range $v := .values.resources }}
          - {{ $v }}
          {{- end }}
          # flux
          - gitrepositories
          - buckets
          - helmrepositories
          - helmcharts
          - ocirepositories
          - kustomizations
          - helmreleases
          - alerts
          - providers
          - receivers
          - imagerepositories
          - imagepolicies
          - imageupdateautomations
        verbs: [ "list", "watch" ]
  customResourceState:
    enabled: true
    config:
      spec:
        resources:
          # user
{{- range .values.details }}
          - groupVersionKind:
              group: {{ .group }}
              version: {{ .version }}
              kind: {{ .kind }}
            metricNamePrefix: user
            metrics:
              - name: "resource_info"
                help: "The current state of a {{ .kind }} resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
{{- if .namespaced }}
                  exported_namespace: [ metadata, namespace ]
{{- end }}
                  synced: [ status, conditions, "[type=Synced]", status ]
                  ready: [ status, conditions, "[type=Ready]", status ]
{{- range .resourceConfigs }}
                  {{ . }}: [ spec, resourceConfig, {{ . }} ]
{{- end }}
{{- if .providerConfigInProject }}
                  providerConfig: [ spec, project, providerConfigName ]
{{- end }}
{{- if .providerConfigInResourceConfig }}
                  providerConfig: [ spec, resourceConfig, providerConfigName ]
{{- end }}
{{- end }}
          # flux
          - groupVersionKind:
              group: kustomize.toolkit.fluxcd.io
              version: v1
              kind: Kustomization
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux Kustomization resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, lastAppliedRevision ]
                  source_name: [ spec, sourceRef, name ]
          - groupVersionKind:
              group: helm.toolkit.fluxcd.io
              version: v2
              kind: HelmRelease
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux HelmRelease resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, history, "0", chartVersion ]
                  chart_name: [ status, history, "0", chartName ]
                  chart_app_version: [ status, history, "0", appVersion ]
                  chart_ref_name: [ spec, chartRef, name ]
                  chart_source_name: [ spec, chart, spec, sourceRef, name ]
          - groupVersionKind:
              group: source.toolkit.fluxcd.io
              version: v1
              kind: GitRepository
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux GitRepository resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, artifact, revision ]
                  url: [ spec, url ]
          - groupVersionKind:
              group: source.toolkit.fluxcd.io
              version: v1
              kind: Bucket
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux Bucket resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, artifact, revision ]
                  endpoint: [ spec, endpoint ]
                  bucket_name: [ spec, bucketName ]
          - groupVersionKind:
              group: source.toolkit.fluxcd.io
              version: v1
              kind: HelmRepository
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux HelmRepository resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, artifact, revision ]
                  url: [ spec, url ]
          - groupVersionKind:
              group: source.toolkit.fluxcd.io
              version: v1
              kind: HelmChart
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux HelmChart resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, artifact, revision ]
                  chart_name: [ spec, chart ]
                  chart_version: [ spec, version ]
          - groupVersionKind:
              group: source.toolkit.fluxcd.io
              version: v1
              kind: OCIRepository
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux OCIRepository resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  revision: [ status, artifact, revision ]
                  url: [ spec, url ]
          - groupVersionKind:
              group: notification.toolkit.fluxcd.io
              version: v1beta3
              kind: Alert
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux Alert resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  suspended: [ spec, suspend ]
          - groupVersionKind:
              group: notification.toolkit.fluxcd.io
              version: v1beta3
              kind: Provider
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux Provider resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  suspended: [ spec, suspend ]
          - groupVersionKind:
              group: notification.toolkit.fluxcd.io
              version: v1
              kind: Receiver
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux Receiver resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  webhook_path: [ status, webhookPath ]
          - groupVersionKind:
              group: image.toolkit.fluxcd.io
              version: v1
              kind: ImageRepository
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux ImageRepository resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  image: [ spec, image ]
          - groupVersionKind:
              group: image.toolkit.fluxcd.io
              version: v1
              kind: ImagePolicy
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux ImagePolicy resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  source_name: [ spec, imageRepositoryRef, name ]
          - groupVersionKind:
              group: image.toolkit.fluxcd.io
              version: v1
              kind: ImageUpdateAutomation
            metricNamePrefix: gotk
            metrics:
              - name: "resource_info"
                help: "The current state of a Flux ImageUpdateAutomation resource."
                each:
                  type: Info
                  info:
                    labelsFromPath:
                      name: [ metadata, name ]
                labelsFromPath:
                  exported_namespace: [ metadata, namespace ]
                  ready: [ status, conditions, "[type=Ready]", status ]
                  suspended: [ spec, suspend ]
                  source_name: [ spec, sourceRef, name ]
