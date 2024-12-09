data "google_client_config" "default" {}

locals {
  coder_admin_email         = "admin@coder.com"
  coder_admin_full_name     = "Coder Admin"
  coder_admin_user          = "coder"
  coder_admin_password      = "SomeSecurePassword!"
  coder_helm_repo           = "https://helm.coder.com/v2"
  coder_helm_chart          = "coder"
  coder_namespace           = "coder"
  coder_release_name        = "${var.name}-coder"
  provisionerd_helm_chart   = "coder-provisioner"
  provisionerd_release_name = "${var.name}-provisionerd"

}

resource "random_password" "provisionerd_psk" {
  length = 26
}

resource "kubernetes_namespace" "coder_primary" {
  provider = kubernetes.primary

  metadata {
    name = local.coder_namespace
  }
  lifecycle {
    ignore_changes = [timeouts, wait_for_default_service_account]
  }

  depends_on = [google_container_node_pool.node_pool["primary_misc"]]
}

resource "kubernetes_secret" "coder_db" {
  provider = kubernetes.primary

  type = "Opaque"
  metadata {
    name      = "coder-db-url"
    namespace = kubernetes_namespace.coder_primary.metadata.0.name
  }
  data = {
    url = local.coder_db_url
  }
  lifecycle {
    ignore_changes = [timeouts, wait_for_service_account_token]
  }
}

resource "kubernetes_secret" "provisionerd_psk_primary" {
  provider = kubernetes.primary

  type = "Opaque"
  metadata {
    name      = "coder-provisioner-psk"
    namespace = kubernetes_namespace.coder_primary.metadata.0.name
  }
  data = {
    psk = random_password.provisionerd_psk.result
  }
  lifecycle {
    ignore_changes = [timeouts, wait_for_service_account_token]
  }
}

resource "helm_release" "coder_primary" {
  provider = helm.primary

  repository = local.coder_helm_repo
  chart      = local.coder_helm_chart
  name       = local.coder_release_name
  version    = var.coder_chart_version
  namespace  = kubernetes_namespace.coder_primary.metadata.0.name
  values = [<<EOF
coder:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: "cloud.google.com/gke-nodepool"
            operator: "In"
            values: ["${google_container_node_pool.node_pool["primary_coder"].name}"]
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        podAffinityTerm:
          topologyKey: "kubernetes.io/hostname"
          labelSelector:
            matchExpressions:
            - key:      "app.kubernetes.io/instance"
              operator: "In"
              values:   ["${local.coder_release_name}"]
  env:
    - name: "CODER_ACCESS_URL"
      value: "${local.deployments.primary.url}"
    - name: "CODER_CACHE_DIRECTORY"
      value: "/tmp/coder"
    - name: "CODER_TELEMETRY_ENABLE"
      value: "false"
    - name: "CODER_LOGGING_HUMAN"
      value: "/dev/null"
    - name: "CODER_LOGGING_STACKDRIVER"
      value: "/dev/stderr"
    - name: "CODER_PG_CONNECTION_URL"
      valueFrom:
        secretKeyRef:
          name: "${kubernetes_secret.coder_db.metadata.0.name}"
          key: url
    - name: "CODER_PPROF_ENABLE"
      value: "true"
    - name: "CODER_PROMETHEUS_ENABLE"
      value: "true"
    - name: "CODER_PROMETHEUS_COLLECT_AGENT_STATS"
      value: "true"
    - name: "CODER_PROMETHEUS_COLLECT_DB_METRICS"
      value: "true"
    - name: "CODER_VERBOSE"
      value: "true"
    - name: "CODER_EXPERIMENTS"
      value: "${var.coder_experiments}"
    - name: "CODER_DANGEROUS_DISABLE_RATE_LIMITS"
      value: "true"
    # Disabling built-in provisioner daemons
    - name: "CODER_PROVISIONER_DAEMONS"
      value: "0"
    - name: CODER_PROVISIONER_DAEMON_PSK
      valueFrom:
        secretKeyRef:
          key: psk
          name: "${kubernetes_secret.provisionerd_psk_primary.metadata.0.name}"
  image:
    repo: ${var.coder_image_repo}
    tag: ${var.coder_image_tag}
  replicaCount: "${local.scenarios[var.scenario].coder.replicas}"
  resources:
    requests:
      cpu: "${local.scenarios[var.scenario].coder.cpu_request}"
      memory: "${local.scenarios[var.scenario].coder.mem_request}"
    limits:
      cpu: "${local.scenarios[var.scenario].coder.cpu_limit}"
      memory: "${local.scenarios[var.scenario].coder.mem_limit}"
  securityContext:
    readOnlyRootFilesystem: true
  service:
    enable: true
    sessionAffinity: None
    loadBalancerIP: "${google_compute_address.coder["primary"].address}"
  volumeMounts:
  - mountPath: "/tmp"
    name: cache
    readOnly: false
  volumes:
  - emptyDir:
      sizeLimit: 1024Mi
    name: cache
EOF
  ]
}

resource "helm_release" "provisionerd_chart" {
  provider = helm.primary

  repository = local.coder_helm_repo
  chart      = local.provisionerd_helm_chart
  name       = local.provisionerd_release_name
  version    = var.provisionerd_chart_version
  namespace  = kubernetes_namespace.coder_primary.metadata.0.name
  values = [<<EOF
coder:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: "cloud.google.com/gke-nodepool"
            operator: "In"
            values: ["${google_container_node_pool.node_pool["primary_coder"].name}"]
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 1
        podAffinityTerm:
          topologyKey: "kubernetes.io/hostname"
          labelSelector:
            matchExpressions:
            - key:      "app.kubernetes.io/instance"
              operator: "In"
              values:   ["${local.coder_release_name}"]
  env:
    - name: "CODER_URL"
      value: "${local.deployments.primary.url}"
    - name: "CODER_VERBOSE"
      value: "true"
    - name: "CODER_CONFIG_DIR"
      value: "/tmp/config"
    - name: "CODER_CACHE_DIRECTORY"
      value: "/tmp/coder"
    - name: "CODER_TELEMETRY_ENABLE"
      value: "false"
    - name: "CODER_LOGGING_HUMAN"
      value: "/dev/null"
    - name: "CODER_LOGGING_STACKDRIVER"
      value: "/dev/stderr"
    - name: "CODER_PROMETHEUS_ENABLE"
      value: "true"
    - name: "CODER_PROVISIONERD_TAGS"
      value: "scope=organization"
  image:
    repo: ${var.provisionerd_image_repo}
    tag: ${var.provisionerd_image_tag}
  replicaCount: "${local.scenarios[var.scenario].provisionerd.replicas}"
  resources:
    requests:
      cpu: "${local.scenarios[var.scenario].provisionerd.cpu_request}"
      memory: "${local.scenarios[var.scenario].provisionerd.mem_request}"
    limits:
      cpu: "${local.scenarios[var.scenario].provisionerd.cpu_limit}"
      memory: "${local.scenarios[var.scenario].provisionerd.mem_limit}"
  securityContext:
    readOnlyRootFilesystem: true
  volumeMounts:
  - mountPath: "/tmp"
    name: cache
    readOnly: false
  volumes:
  - emptyDir:
      sizeLimit: 1024Mi
    name: cache
EOF
  ]
}