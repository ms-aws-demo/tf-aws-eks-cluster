## @section Global parameters
## Global Docker image parameters
## Please, note that this will override the image parameters, including dependencies, configured to use the global value
## Current available global Docker image parameters: imageRegistry, imagePullSecrets and storageClass

## @param global.imageRegistry Global Docker image registry
## @param global.imagePullSecrets Global Docker registry secret names as an array
## @param global.storageClass Global StorageClass for Persistent Volume(s)
##
global:
  imageRegistry: ""
  ## E.g.
  ## imagePullSecrets:
  ##   - myRegistryKeySecretName
  ##
  imagePullSecrets: []
  storageClass: ""

## @section Common parameters

## @param kubeVersion Force target Kubernetes version (using Helm capabilities if not set)
##
kubeVersion: ""
## @param nameOverride String to partially override common.names.fullname template (will maintain the release name)
##
nameOverride: ""
## @param fullnameOverride String to fully override common.names.fullname template
##
fullnameOverride: ""
## @param clusterDomain Cluster Domain
##
clusterDomain: cluster.local
## @param extraDeploy Array of extra objects to deploy with the release
##
extraDeploy: []

## Enable diagnostic mode in the deployment
##
diagnosticMode:
  ## @param diagnosticMode.enabled Enable diagnostic mode (all probes will be disabled and the command will be overridden)
  ##
  enabled: false
  ## @param diagnosticMode.command Command to override all containers in the deployment
  ##
  command:
    - sleep
  ## @param diagnosticMode.args Args to override all containers in the deployment
  ##
  args:
    - infinity

## @section Fluentd parameters

## Bitnami Fluentd image version
## ref: https://hub.docker.com/r/bitnami/fluentd/tags/
## @param image.registry Fluentd image registry
## @param image.repository Fluentd image repository
## @param image.tag Fluentd image tag (immutable tags are recommended)
## @param image.pullPolicy Fluentd image pull policy
## @param image.pullSecrets Fluentd image pull secrets
## @param image.debug Enable image debug mode
##
image:
  registry: docker.io
  repository: bitnami/fluentd
  tag: 1.14.0-debian-10-r6
  ## Specify a imagePullPolicy
  ## Defaults to 'Always' if image tag is 'latest', else set to 'IfNotPresent'
  ## ref: http://kubernetes.io/docs/user-guide/images/#pre-pulling-images
  ##
  pullPolicy: IfNotPresent
  ## Optionally specify an array of imagePullSecrets.
  ## Secrets must be manually created in the namespace.
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
  ##
  ## pullSecrets:
  ##   - myRegistryKeySecretName
  pullSecrets: []
  ## Enable debug mode
  ##
  debug: false
## Forwarder parameters
##
forwarder:
  ## @param forwarder.enabled Enable forwarder daemonset
  ##
  enabled: true
  ## @param forwarder.daemonUser Forwarder daemon user and group (set to root by default because it reads from host paths)
  ##
  daemonUser: root
  ## @param forwarder.daemonGroup Fluentd forwarder daemon system group
  ##
  daemonGroup: root
  ## @param forwarder.hostAliases Add deployment host aliases
  ## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
  ##
  hostAliases: []
  ## K8s Security Context for forwarder pods
  ## https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param forwarder.securityContext.enabled Enable security context for forwarder pods
  ## @param forwarder.securityContext.runAsUser User ID for forwarder's containers
  ## @param forwarder.securityContext.runAsGroup Group ID for forwarder's containers
  ## @param forwarder.securityContext.fsGroup Group ID for forwarder's containers filesystem
  ##
  securityContext:
    enabled: true
    runAsUser: 0
    runAsGroup: 0
    fsGroup: 0
  ## K8s Security Context for forwarder container
  ## https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param forwarder.containerSecurityContext.enabled Enable security context for the forwarder container
  ## @param forwarder.containerSecurityContext.privileged Run as privileged
  ## @param forwarder.containerSecurityContext.allowPrivilegeEscalation Allow Privilege Escalation
  ## @param forwarder.containerSecurityContext.readOnlyRootFilesystem Require the use of a read only root file system
  ## @param forwarder.containerSecurityContext.capabilities.drop [array] Drop capabilities for the securityContext
  ##
  containerSecurityContext:
    enabled: true
    privileged: false
    allowPrivilegeEscalation: false
    ## Requires mounting an `extraVolume` of type `emptyDir` into /tmp
    ##
    readOnlyRootFilesystem: false
    capabilities:
      drop:
        - ALL
  ## @param forwarder.terminationGracePeriodSeconds Duration in seconds the pod needs to terminate gracefully
  ## https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/
  ##
  terminationGracePeriodSeconds: 30
  ## @param forwarder.configFile Name of the config file that will be used by Fluentd at launch under the `/opt/bitnami/fluentd/conf` directory
  ##
  configFile: fluentd.conf
  ## @param forwarder.configMap Name of the config map that contains the Fluentd configuration files
  ## If not specified, one will be created by default
  ##
  configMap: ""
  ## @param forwarder.configMapFiles [object] Files to be added to be config map. Ignored if `forwarder.configMap` is set
  ##
  configMapFiles:
    fluentd.conf: |
      # Ignore fluentd own events
      <match fluent.**>
        @type null
      </match>
      @include fluentd-inputs.conf
      @include fluentd-output.conf
      {{- if .Values.metrics.enabled }}
      @include metrics.conf
      {{- end }}
    fluentd-inputs.conf: |
      # HTTP input for the liveness and readiness probes
      <source>
        @type http
        port 9880
      </source>
      # Get the logs from the containers running in the node
      <source>
        @type tail
        path /var/log/containers/*.log
        # exclude Fluentd logs
        exclude_path /var/log/containers/*fluentd*.log
        pos_file /opt/bitnami/fluentd/logs/buffers/fluentd-docker.pos
        tag kubernetes.*
        read_from_head true
        <parse>
          @type json
          time_key time
          time_format %Y-%m-%dT%H:%M:%S.%NZ
        </parse>
      </source>
      # enrich with kubernetes metadata
      <filter kubernetes.**>
        @type kubernetes_metadata
      </filter>
    fluentd-output.conf: |
      # Throw the healthcheck to the standard output instead of forwarding it
      <match fluentd.healthcheck>
        @type stdout
      </match>
      {{- if .Values.aggregator.enabled }}
      # Forward all logs to the aggregators
      <match **>
        @type elasticsearch
        host ${es_domain_endpoint}
        port 443
        scheme https
        logstash_format true
      </match>
      {{- else }}
      # Send the logs to the standard output
      <match **>
        @type stdout
      </match>
      {{- end }}
    metrics.conf: |
      # Prometheus Exporter Plugin
      # input plugin that exports metrics
      <source>
        @type prometheus
        port {{ .Values.metrics.service.port }}
      </source>
      # input plugin that collects metrics from MonitorAgent
      <source>
        @type prometheus_monitor
        <labels>
          host #{hostname}
        </labels>
      </source>
      # input plugin that collects metrics for output plugin
      <source>
        @type prometheus_output_monitor
        <labels>
          host #{hostname}
        </labels>
      </source>
      # input plugin that collects metrics for in_tail plugin
      <source>
        @type prometheus_tail_monitor
        <labels>
          host #{hostname}
        </labels>
      </source>
  ## @param forwarder.extraArgs Extra arguments for the Fluentd command line
  ## ref: https://docs.fluentd.org/deployment/command-line-option
  ##
  extraArgs: ""
  ## @param forwarder.extraEnv Extra environment variables to pass to the container
  ## extraEnv:
  ##   - name: MY_ENV_VAR
  ##     value: my_value
  ##
  extraEnv: []
  ## @param forwarder.containerPorts [array] Ports the forwarder containers will listen on
  ##
  containerPorts:
    ## - name: syslog-tcp
    ##   containerPort: 5140
    ##   protocol: TCP
    ## - name: syslog-udp
    ##   containerPort: 5140
    ##   protocol: UDP
    ## - name: tcp
    ##   containerPort: 24224
    ##   protocol: TCP
    - name: http
      containerPort: 9880
      protocol: TCP
  ## Service parameters
  ##
  service:
    ## @param forwarder.service.type Kubernetes service type (`ClusterIP`, `NodePort`, or `LoadBalancer`) for the forwarders
    ##
    type: ClusterIP
    ## @param forwarder.service.ports [object] Array containing the forwarder service ports
    ##
    ports:
      ## syslog-udp:
      ##   port: 5140
      ##   targetPort: syslog-udp
      ##   protocol: UDP
      ##   nodePort: 31514
      ## syslog-tcp:
      ##   port: 5140
      ##   targetPort: syslog-tcp
      ##   protocol: TCP
      ##   nodePort: 31514
      ## tcp:
      ##   port: 24224
      ##   targetPort: tcp
      ##   protocol: TCP
      http:
        port: 9880
        targetPort: http
        protocol: TCP
    ## @param forwarder.service.loadBalancerIP loadBalancerIP if service type is `LoadBalancer` (optional, cloud specific)
    ## ref: http://kubernetes.io/docs/user-guide/services/#type-loadbalancer
    ##
    loadBalancerIP: ""
    ## @param forwarder.service.loadBalancerSourceRanges Addresses that are allowed when service is LoadBalancer
    ## https://kubernetes.io/docs/tasks/access-application-cluster/configure-cloud-provider-firewall/#restrict-access-for-loadbalancer-service
    ##
    ## loadBalancerSourceRanges:
    ##   - 10.10.10.0/24
    ##
    loadBalancerSourceRanges: []
    ## @param forwarder.service.clusterIP Static clusterIP or None for headless services
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#choosing-your-own-ip-address
    ## e.g:
    ## clusterIP: None
    ##
    clusterIP: ""
    ## @param forwarder.service.annotations Provide any additional annotations which may be required
    ##
    annotations: {}
  ## Configure extra options for liveness probe
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
  ## @param forwarder.livenessProbe.enabled Enable livenessProbe
  ## @param forwarder.livenessProbe.httpGet.path Request path for livenessProbe
  ## @param forwarder.livenessProbe.httpGet.port Port for livenessProbe
  ## @param forwarder.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
  ## @param forwarder.livenessProbe.periodSeconds Period seconds for livenessProbe
  ## @param forwarder.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
  ## @param forwarder.livenessProbe.failureThreshold Failure threshold for livenessProbe
  ## @param forwarder.livenessProbe.successThreshold Success threshold for livenessProbe
  ##
  livenessProbe:
    enabled: true
    httpGet:
      path: /fluentd.healthcheck?json=%7B%22ping%22%3A+%22pong%22%7D
      port: http
    initialDelaySeconds: 60
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## Configure extra options for readiness probe
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
  ## @param forwarder.readinessProbe.enabled Enable readinessProbe
  ## @param forwarder.readinessProbe.httpGet.path Request path for readinessProbe
  ## @param forwarder.readinessProbe.httpGet.port Port for readinessProbe
  ## @param forwarder.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
  ## @param forwarder.readinessProbe.periodSeconds Period seconds for readinessProbe
  ## @param forwarder.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
  ## @param forwarder.readinessProbe.failureThreshold Failure threshold for readinessProbe
  ## @param forwarder.readinessProbe.successThreshold Success threshold for readinessProbe
  ##
  readinessProbe:
    enabled: true
    httpGet:
      path: /fluentd.healthcheck?json=%7B%22ping%22%3A+%22pong%22%7D
      port: http
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param forwarder.updateStrategy.type Set up update strategy.
  ## ref: https://kubernetes.io/docs/tasks/manage-daemon/update-daemon-set/#daemonset-update-strategy
  ## Example:
  ## updateStrategy:
  ##  type: RollingUpdate
  ##  rollingUpdate:
  ##    maxSurge: 25%
  ##    maxUnavailable: 25%
  ##
  updateStrategy:
    type: RollingUpdate
  ## Forwarder containers' resource requests and limits
  ## ref: http://kubernetes.io/docs/user-guide/compute-resources/
  ## We usually recommend not to specify default resources and to leave this as a conscious
  ## choice for the user. This also increases chances charts run on environments with little
  ## resources, such as Minikube. If you do want to specify resources, uncomment the following
  ## lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  ## @param forwarder.resources.limits The resources limits for the container
  ## @param forwarder.resources.requests The requested resources for the container
  ##
  resources:
    ## Example:
    ## limits:
    ##    cpu: 500m
    ##    memory: 1Gi
    limits: {}
    ## Examples:
    ## requests:
    ##    cpu: 300m
    ##    memory: 512Mi
    requests: {}
  ## @param forwarder.priorityClassName Set Priority Class Name to allow priority control over other pods
  ## ref: https://kubernetes.io/docs/concepts/configuration/pod-priority-preemption/
  ##
  priorityClassName: ""
  ## @param forwarder.podAffinityPreset Forwarder Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAffinityPreset: ""
  ## @param forwarder.podAntiAffinityPreset Forwarder Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
  ## Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAntiAffinityPreset: ""
  ## Node affinity preset
  ## Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
  ##
  nodeAffinityPreset:
    ## @param forwarder.nodeAffinityPreset.type Forwarder Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
    ##
    type: ""
    ## @param forwarder.nodeAffinityPreset.key Forwarder Node label key to match Ignored if `affinity` is set.
    ## E.g.
    ## key: "kubernetes.io/e2e-az-name"
    ##
    key: ""
    ## @param forwarder.nodeAffinityPreset.values Forwarder Node label values to match. Ignored if `affinity` is set.
    ## E.g.
    ## values:
    ##   - e2e-az1
    ##   - e2e-az2
    ##
    values: []
  ## @param forwarder.affinity Forwarder Affinity for pod assignment
  ## Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ## Note: podAffinityPreset, podAntiAffinityPreset, and  nodeAffinityPreset will be ignored when it's set
  ##
  affinity: {}
  ## @param forwarder.nodeSelector Forwarder Node labels for pod assignment
  ## Ref: https://kubernetes.io/docs/user-guide/node-selection/
  ##
  nodeSelector: {}
  ## @param forwarder.tolerations Forwarder Tolerations for pod assignment
  ## Ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  ##
  tolerations: []
  ## @param forwarder.podAnnotations Pod annotations
  ## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  ##
  podAnnotations: {}
  ## @param forwarder.podLabels Extra labels to add to Pod
  ##
  podLabels: {}
  ## Pods Service Account
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
  ##
  serviceAccount:
    ## @param forwarder.serviceAccount.create Specify whether a ServiceAccount should be created.
    ##
    create: true
    ## @param forwarder.serviceAccount.name The name of the ServiceAccount to create
    ## If not set and create is true, a name is generated using the common.names.fullname template
    name: ""
    ## @param forwarder.serviceAccount.annotations Additional Service Account annotations (evaluated as a template)
    ##
    annotations: {}
  ## Role Based Access
  ## ref: https://kubernetes.io/docs/admin/authorization/rbac/
  ## @param forwarder.rbac.create Specify whether RBAC resources should be created and used, allowing the get, watch and list of pods/namespaces
  ## @param forwarder.rbac.pspEnabled Specify whether the bundled Pod Security Policy should be created and bound with RBAC
  ##
  rbac:
    create: true
    pspEnabled: false
  ## Persist data to a persistent volume
  ##
  persistence:
    ## @param forwarder.persistence.enabled Enable persistence volume for the forwarder
    ##
    enabled: false
    ## @param forwarder.persistence.hostPath.path Directory from the host node's filesystem to mount as hostPath volume for persistence.
    ## The host directory you chose is mounted into /opt/bitnami/fluentd/logs/buffers in your Pod
    ## Example use case: mount host directory /tmp/buffer (if the directory doesn't exist, it creates it) into forwarder pod.
    ##   persistence:
    ##     enabled: true
    ##     hostPath:
    ##       path: /tmp/buffer
    ##
    hostPath:
      path: /opt/bitnami/fluentd/logs/buffers
  ## @param forwarder.initContainers Additional init containers to add to the pods
  ## For example:
  ## initContainers:
  ##   - name: your-image-name
  ##     image: your-image
  ##     imagePullPolicy: Always
  ##
  initContainers: []
  ## @param forwarder.sidecars Add sidecars to forwarder pods
  ##
  ## For example:
  ## sidecars:
  ##   - name: your-image-name
  ##     image: your-image
  ##     imagePullPolicy: Always
  ##     ports:
  ##       - name: portname
  ##         containerPort: 1234
  ##
  sidecars: []
  ## @param forwarder.extraVolumes Extra volumes
  ## Example Use Case: mount systemd journal volume
  ##  - name: systemd
  ##      hostPath:
  ##        path: /run/log/journal/
  ##
  extraVolumes: []
  ## @param forwarder.extraVolumeMounts Mount extra volume(s)
  ##   - name: systemd
  ##     mountPath: /run/log/journal/
  ##
  extraVolumeMounts: []
## Aggregator parameters
##
aggregator:
  ## @param aggregator.enabled Enable Fluentd aggregator statefulset
  ##
  enabled: true
  ## @param aggregator.replicaCount Number of aggregator pods to deploy in the Stateful Set
  ##
  replicaCount: 1
  ## K8s Security Context for Aggregator pods
  ## https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param aggregator.securityContext.enabled Enable security context for aggregator pods
  ## @param aggregator.securityContext.runAsUser User ID for aggregator's containers
  ## @param aggregator.securityContext.runAsGroup Group ID for aggregator's containers
  ## @param aggregator.securityContext.fsGroup Group ID for aggregator's containers filesystem
  ##
  securityContext:
    enabled: true
    runAsUser: 1001
    runAsGroup: 1001
    fsGroup: 1001
  ## @param aggregator.hostAliases Add deployment host aliases
  ## https://kubernetes.io/docs/concepts/services-networking/add-entries-to-pod-etc-hosts-with-host-aliases/
  ##
  hostAliases: []
  ## K8s Security Context for Aggregator containers
  ## https://kubernetes.io/docs/tasks/configure-pod-container/security-context/
  ## @param aggregator.containerSecurityContext.enabled Enable security context for the aggregator container
  ## @param aggregator.containerSecurityContext.privileged Run as privileged
  ## @param aggregator.containerSecurityContext.allowPrivilegeEscalation Allow Privilege Escalation
  ## @param aggregator.containerSecurityContext.readOnlyRootFilesystem Require the use of a read only root file system
  ## @param aggregator.containerSecurityContext.capabilities.drop [array] Drop capabilities for the securityContext
  ##
  containerSecurityContext:
    enabled: true
    privileged: false
    allowPrivilegeEscalation: false
    ## Requires mounting an `extraVolume` of type `emptyDir` into /tmp
    ##
    readOnlyRootFilesystem: false
    capabilities:
      drop:
        - ALL
  ## @param aggregator.terminationGracePeriodSeconds Duration in seconds the pod needs to terminate gracefully
  ## https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/
  ##
  terminationGracePeriodSeconds: 30
  ## @param aggregator.configFile Name of the config file that will be used by Fluentd at launch under the `/opt/bitnami/fluentd/conf` directory
  ##
  configFile: fluentd.conf
  ## @param aggregator.configMap Name of the config map that contains the Fluentd configuration files
  ##
  configMap: ""
  ## @param aggregator.configMapFiles [object] Files to be added to be config map. Ignored if `aggregator.configMap` is set
  ##
  configMapFiles:
    fluentd.conf: |
      # Ignore fluentd own events
      <match fluent.**>
        @type null
      </match>
      @include fluentd-inputs.conf
      @include fluentd-output.conf
      {{- if .Values.metrics.enabled }}
      @include metrics.conf
      {{- end }}
    fluentd-inputs.conf: |
      # TCP input to receive logs from
      {{- if .Values.aggregator.port }}
      <source>
        @type forward
        bind 0.0.0.0
        port {{ .Values.aggregator.port }}
        {{- if .Values.tls.enabled }}
        <transport tls>
          ca_path /opt/bitnami/fluentd/certs/in_forward/ca.crt
          cert_path /opt/bitnami/fluentd/certs/in_forward/tls.crt
          private_key_path /opt/bitnami/fluentd/certs/in_forward/tls.key
          client_cert_auth true
        </transport>
        {{- end }}
      </source>
      {{- end }}
      # HTTP input for the liveness and readiness probes
      <source>
        @type http
        bind 0.0.0.0
        port 9880
      </source>
    fluentd-output.conf: |
      # Throw the healthcheck to the standard output
      <match fluentd.healthcheck>
        @type stdout
      </match>
      # Send the logs to the standard output
      <match **>
        @type stdout
      </match>
    metrics.conf: |
      # Prometheus Exporter Plugin
      # input plugin that exports metrics
      <source>
        @type prometheus
        port {{ .Values.metrics.service.port }}
      </source>
      # input plugin that collects metrics from MonitorAgent
      <source>
        @type prometheus_monitor
        <labels>
          host #{hostname}
        </labels>
      </source>
      # input plugin that collects metrics for output plugin
      <source>
        @type prometheus_output_monitor
        <labels>
          host #{hostname}
        </labels>
      </source>
  ## @param aggregator.port Port the Aggregator container will listen for logs. Leave it blank to ignore.
  ## You can specify other ports in the aggregator.containerPorts parameter
  ##
  port: 24224
  ## @param aggregator.extraArgs Extra arguments for the Fluentd command line
  ## ref: https://docs.fluentd.org/deployment/command-line-option
  ##
  extraArgs: ""
  ## @param aggregator.extraEnv Extra environment variables to pass to the container
  ## extraEnv:
  ##   - name: MY_ENV_VAR
  ##     value: my_value
  ##
  extraEnv: []
  ## @param aggregator.containerPorts [array] Ports the aggregator containers will listen on
  ##
  containerPorts:
    # - name: my-port
    #   containerPort: 24222
    #   protocol: TCP
    - name: http
      containerPort: 9880
      protocol: TCP
  ## Service parameters
  ##
  service:
    ## @param aggregator.service.type Kubernetes service type (`ClusterIP`, `NodePort`, or `LoadBalancer`) for the aggregators
    ##
    type: ClusterIP
    ## @param aggregator.service.ports [object] Array containing the aggregator service ports
    ##
    ports:
      http:
        port: 9880
        targetPort: http
        protocol: TCP
      tcp:
        port: 24224
        targetPort: tcp
        protocol: TCP
    ## @param aggregator.service.loadBalancerIP loadBalancerIP if service type is `LoadBalancer` (optional, cloud specific)
    ## ref: http://kubernetes.io/docs/user-guide/services/#type-loadbalancer
    ##
    loadBalancerIP: ""
    ## @param aggregator.service.loadBalancerSourceRanges Addresses that are allowed when service is LoadBalancer
    ## https://kubernetes.io/docs/tasks/access-application-cluster/configure-cloud-provider-firewall/#restrict-access-for-loadbalancer-service
    ##
    ## loadBalancerSourceRanges:
    ##   - 10.10.10.0/24
    loadBalancerSourceRanges: []
    ## @param aggregator.service.clusterIP Static clusterIP or None for headless services
    ## ref: https://kubernetes.io/docs/concepts/services-networking/service/#choosing-your-own-ip-address
    ## e.g:
    ## clusterIP: None
    ##
    clusterIP: ""
    ## @param aggregator.service.annotations Provide any additional annotations which may be required
    ##
    annotations: {}
  ## Configure the ingress resource that allows you to access the
  ## Fluentd aggregator. Set up the URL
  ## ref: http://kubernetes.io/docs/user-guide/ingress/
  ##
  ingress:
    ## @param aggregator.ingress.enabled Set to true to enable ingress record generation
    ##
    enabled: false
    ## @param aggregator.ingress.certManager Set this to true in order to add the corresponding annotations for cert-manager
    ##
    certManager: false
    ## @param aggregator.ingress.pathType Ingress Path type. How the path matching is interpreted
    ##
    pathType: ImplementationSpecific
    ## @param aggregator.ingress.apiVersion Override API Version (automatically detected if not set)
    ##
    apiVersion: ""
    ## @param aggregator.ingress.hostname Default host for the ingress resource
    ##
    hostname: fluentd.local
    ## @param aggregator.ingress.path Default path for the ingress resource
    ## You may need to set this to '/*' in order to use this with ALB ingress controllers.
    ##
    path: /
    ## @param aggregator.ingress.annotations Ingress annotations
    ## For a full list of possible ingress annotations, please see
    ## ref: https://github.com/kubernetes/ingress-nginx/blob/master/docs/user-guide/nginx-configuration/annotations.md
    ##
    ## If certManager is set to true, annotation kubernetes.io/tls-acme: "true" will automatically be set
    ##
    annotations: {}
    ## @param aggregator.ingress.tls Enable TLS configuration for the hostname defined at ingress.hostname parameter
    ## TLS certificates will be retrieved from a TLS secret with name: {{- printf "%s-tls" .Values.aggregator.ingress.hostname }}
    ## You can use the ingress.secrets parameter to create this TLS secret or relay on cert-manager to create it
    ##
    tls: false
    ## @param aggregator.ingress.extraHosts The list of additional hostnames to be covered with this ingress record.
    ## Most likely the hostname above will be enough, but in the event more hosts are needed, this is an array
    ## extraHosts:
    ## - name: fluentd.local
    ##   path: /
    ##
    extraHosts: []
    ## @param aggregator.ingress.extraPaths Any additional arbitrary paths that may need to be added to the ingress under the main host.
    ## For example: The ALB ingress controller requires a special rule for handling SSL redirection.
    ## extraPaths:
    ## - path: /*
    ##   backend:
    ##     serviceName: ssl-redirect
    ##     servicePort: use-annotation
    ##
    extraPaths: []
    ## @param aggregator.ingress.extraTls The tls configuration for additional hostnames to be covered with this ingress record.
    ## see: https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
    ## extraTls:
    ## - hosts:
    ##     - fluentd.local
    ##   secretName: fluentd.local-tls
    ##
    extraTls: []
    ## @param aggregator.ingress.secrets If you're providing your own certificates, please use this to add the certificates as secrets
    ## key and certificate should start with -----BEGIN CERTIFICATE----- or
    ## -----BEGIN RSA PRIVATE KEY-----
    ##
    ## name should line up with a tlsSecret set further up
    ## If you're using cert-manager, this is unneeded, as it will create the secret for you if it is not set
    ##
    ## It is also possible to create and manage the certificates outside of this helm chart
    ## Please see README.md for more information
    ## e.g:
    ## - name: fluentd.local-tls
    ##   key:
    ##   certificate:
    ##
    secrets: []
  ## Configure extra options for liveness probe
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
  ## @param aggregator.livenessProbe.enabled Enable livenessProbe
  ## @param aggregator.livenessProbe.httpGet.path Request path for livenessProbe
  ## @param aggregator.livenessProbe.httpGet.port Port for livenessProbe
  ## @param aggregator.livenessProbe.initialDelaySeconds Initial delay seconds for livenessProbe
  ## @param aggregator.livenessProbe.periodSeconds Period seconds for livenessProbe
  ## @param aggregator.livenessProbe.timeoutSeconds Timeout seconds for livenessProbe
  ## @param aggregator.livenessProbe.failureThreshold Failure threshold for livenessProbe
  ## @param aggregator.livenessProbe.successThreshold Success threshold for livenessProbe
  ##
  livenessProbe:
    enabled: true
    httpGet:
      path: /fluentd.healthcheck?json=%7B%22ping%22%3A+%22pong%22%7D
      port: http
    initialDelaySeconds: 60
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## Configure extra options for readiness probe
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/#configure-probes
  ## @param aggregator.readinessProbe.enabled Enable readinessProbe
  ## @param aggregator.readinessProbe.httpGet.path Request path for readinessProbe
  ## @param aggregator.readinessProbe.httpGet.port Port for readinessProbe
  ## @param aggregator.readinessProbe.initialDelaySeconds Initial delay seconds for readinessProbe
  ## @param aggregator.readinessProbe.periodSeconds Period seconds for readinessProbe
  ## @param aggregator.readinessProbe.timeoutSeconds Timeout seconds for readinessProbe
  ## @param aggregator.readinessProbe.failureThreshold Failure threshold for readinessProbe
  ## @param aggregator.readinessProbe.successThreshold Success threshold for readinessProbe
  ##
  readinessProbe:
    enabled: true
    httpGet:
      path: /fluentd.healthcheck?json=%7B%22ping%22%3A+%22pong%22%7D
      port: http
    initialDelaySeconds: 5
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 6
    successThreshold: 1
  ## @param aggregator.updateStrategy.type Set up update strategy.
  ## ref: https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/#updating-statefulsets
  ## Example:
  ## updateStrategy:
  ##  type: RollingUpdate
  ##  rollingUpdate:
  ##    maxSurge: 25%
  ##    maxUnavailable: 25%
  ##
  updateStrategy:
    type: RollingUpdate
  ## Aggregator containers' resource requests and limits
  ## ref: http://kubernetes.io/docs/user-guide/compute-resources/
  ## We usually recommend not to specify default resources and to leave this as a conscious
  ## choice for the user. This also increases chances charts run on environments with little
  ## resources, such as Minikube. If you do want to specify resources, uncomment the following
  ## lines, adjust them as necessary, and remove the curly braces after 'resources:'.
  ## @param aggregator.resources.limits The resources limits for the container
  ## @param aggregator.resources.requests The requested resources for the container
  ##
  resources:
    ## Example:
    ## limits:
    ##    cpu: 500m
    ##    memory: 1Gi
    limits: {}
    ## Examples:
    ## requests:
    ##    cpu: 300m
    ##    memory: 512Mi
    requests: {}
  ## @param aggregator.podAffinityPreset Aggregator Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
  ## ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAffinityPreset: ""
  ## @param aggregator.podAntiAffinityPreset Aggregator Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
  ## Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#inter-pod-affinity-and-anti-affinity
  ##
  podAntiAffinityPreset: soft
  ## Node affinity preset
  ## Ref: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#node-affinity
  ##
  nodeAffinityPreset:
    ## @param aggregator.nodeAffinityPreset.type Aggregator Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`
    ##
    type: ""
    ## @param aggregator.nodeAffinityPreset.key Aggregator Node label key to match Ignored if `affinity` is set.
    ##
    key: ""
    ## @param aggregator.nodeAffinityPreset.values Aggregator Node label values to match. Ignored if `affinity` is set.
    ## E.g.
    ## values:
    ##   - e2e-az1
    ##   - e2e-az2
    ##
    values: []
  ## @param aggregator.affinity Aggregator Affinity for pod assignment
  ## Ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity
  ## Note: podAffinityPreset, podAntiAffinityPreset, and  nodeAffinityPreset will be ignored when it's set
  ##
  affinity: {}
  ## @param aggregator.nodeSelector Aggregator Node labels for pod assignment
  ## Ref: https://kubernetes.io/docs/user-guide/node-selection/
  ##
  nodeSelector: {}
  ## @param aggregator.tolerations Aggregator Tolerations for pod assignment
  ## Ref: https://kubernetes.io/docs/concepts/configuration/taint-and-toleration/
  ##
  tolerations: []
  ## @param aggregator.podAnnotations Pod annotations
  ## ref: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/
  ##
  podAnnotations: {}
  ## @param aggregator.podLabels Extra labels to add to Pod
  ##
  podLabels: {}
  ## Pods Service Account
  ## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
  ##
  serviceAccount:
    ## @param aggregator.serviceAccount.create Specify whether a ServiceAccount should be created
    ##
    create: false
    ## @param aggregator.serviceAccount.name The name of the ServiceAccount to create
    ## If not set and create is true, a name is generated using the common.names.fullname template
    name: ""
    ## @param aggregator.serviceAccount.annotations Additional Service Account annotations (evaluated as a template)
    ##
    annotations: {}
  ## Autoscaling parameters
  ## This is not recommended in a forwarder+aggregator architecture
  ## @param aggregator.autoscaling.enabled Create an Horizontal Pod Autoscaler
  ## @param aggregator.autoscaling.minReplicas Minimum number of replicas for the HPA
  ## @param aggregator.autoscaling.maxReplicas Maximum number of replicas for the HPA
  ## @param aggregator.autoscaling.metrics [array] Metrics for the HPA to manage the scaling
  ##
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 5
    metrics:
      - type: Resource
        resource:
          name: cpu
          target:
            type: Utilization
            averageUtilization: 60
      - type: Resource
        resource:
          name: memory
          target:
            type: Utilization
            averageUtilization: 60
  ## Persist data to a persistent volume
  ## @param aggregator.persistence.enabled Enable persistence volume for the aggregator
  ## @param aggregator.persistence.storageClass Persistent Volume storage class
  ## @param aggregator.persistence.accessMode Persistent Volume access mode
  ## @param aggregator.persistence.size Persistent Volume size
  ##
  persistence:
    enabled: false
    ## If defined, storageClassName: <storageClass>
    ## If set to "-", storageClassName: "", which disables dynamic provisioning
    ## If undefined (the default) or set to null, no storageClassName spec is
    ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
    ##   GKE, AWS & OpenStack)
    ##
    storageClass: ""
    accessMode: ReadWriteOnce
    size: 10Gi
  ## @param aggregator.initContainers Add init containers to aggregator pods
  ## Example
  ##
  ## initContainers:
  ##   - name: do-something
  ##     image: busybox
  ##     command: ['do', 'something']
  ##
  initContainers: []
  ## @param aggregator.sidecars Add sidecars to aggregator pods
  ##
  ## For example:
  ## sidecars:
  ##   - name: your-image-name
  ##     image: your-image
  ##     imagePullPolicy: Always
  ##     ports:
  ##       - name: portname
  ##         containerPort: 1234
  ##
  sidecars: []
  ## @param aggregator.extraVolumes Extra volumes
  ## Example Use Case: mount an emptyDir into /tmp to support running with readOnlyRootFileSystem
  ##   - name: tmpDir
  ##       emptyDir: {}
  ##
  extraVolumes: []
  ## @param aggregator.extraVolumeMounts Mount extra volume(s)
  ##   - name: tmpDir
  ##     mountPath: /tmp
  ##
  extraVolumeMounts: []
## @param serviceAccount Pods Service Account. This top-level global entry is DEPRECATED. Please use "forwarder.serviceAccount" instead.
## Only the forwarder was affected by the historical usage here.
## ref: https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
##
serviceAccount: {}
## @param rbac Role Based Access. This top-level global entry is DEPRECATED. Please use "forwarder.rbac" instead.
## Only the forwarder was affected by the historical usage here.
## ref: https://kubernetes.io/docs/admin/authorization/rbac/
##
rbac: {}
## Prometheus Exporter / Metrics
##
metrics:
  ## @param metrics.enabled Enable the export of Prometheus metrics
  ##
  enabled: false
  ## Prometheus Exporter service parameters
  ##
  service:
    ## @param metrics.service.type Prometheus metrics service type
    ##
    type: ClusterIP
    ## @param metrics.service.port Prometheus metrics service port
    ##
    port: 24231
    ## @param metrics.service.loadBalancerIP Load Balancer IP if the Prometheus metrics server type is `LoadBalancer`
    ## ref: http://kubernetes.io/docs/user-guide/services/#type-loadbalancer
    ##
    loadBalancerIP: ""
    ## @param metrics.service.annotations [object] Annotations for the Prometheus Exporter service service
    ##
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/port: "24231"
      prometheus.io/path: "/metrics"
  ## Prometheus Operator ServiceMonitor configuration
  ##
  serviceMonitor:
    ## @param metrics.serviceMonitor.enabled if `true`, creates a Prometheus Operator ServiceMonitor (also requires `metrics.enabled` to be `true`)
    ##
    enabled: false
    ## @param metrics.serviceMonitor.namespace Namespace in which Prometheus is running
    ##
    namespace: ""
    ## @param metrics.serviceMonitor.interval Interval at which metrics should be scraped.
    ## ref: https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#endpoint
    ## e.g:
    ## interval: 10s
    ##
    interval: ""
    ## @param metrics.serviceMonitor.scrapeTimeout Timeout after which the scrape is ended
    ## ref: https://github.com/coreos/prometheus-operator/blob/master/Documentation/api.md#endpoint
    ## e.g:
    ## scrapeTimeout: 10s
    ##
    scrapeTimeout: ""
    ## @param metrics.serviceMonitor.selector Prometheus instance selector labels
    ## ref: https://github.com/bitnami/charts/tree/master/bitnami/prometheus-operator#prometheus-configuration
    ## e.g:
    ## selector:
    ##   prometheus: my-prometheus
    ##
    selector: {}
    ## @param metrics.serviceMonitor.labels ServiceMonitor extra labels
    ##
    labels: {}
    ## @param metrics.serviceMonitor.annotations ServiceMonitor annotations
    ##
    annotations: {}
## Enable internal SSL/TLS encryption
##
tls:
  ## @param tls.enabled Enable TLS/SSL encrytion for internal communications
  ##
  enabled: false
  ## @param tls.autoGenerated Generate automatically self-signed TLS certificates.
  ##
  autoGenerated: false
  ## @param tls.forwarder.existingSecret Name of the existing secret containing the TLS certificates for the Fluentd forwarder
  ##
  forwarder:
    existingSecret: ""
  ## @param tls.aggregator.existingSecret Name of the existing secret containing the TLS certificates for the Fluentd aggregator
  ##
  aggregator:
    existingSecret: ""