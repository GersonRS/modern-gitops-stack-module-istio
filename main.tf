resource "null_resource" "dependencies" {
  triggers = var.dependency_ids
}

data "utils_deep_merge_yaml" "values" {
  input = [for i in concat(local.helm_values, var.helm_values) : yamlencode(i)]
}

resource "argocd_project" "this" {
  count = var.argocd_project == null ? 1 : 0

  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-${var.destination_cluster}" : "istio"
    namespace = var.argocd_namespace
    annotations = {
      "modern-gitops-stack.io/argocd_namespace" = var.argocd_namespace
    }
  }

  spec {
    description  = "istio application project for cluster ${var.destination_cluster}"
    source_repos = [var.project_source_repo]


    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    orphaned_resources {
      warn = true
    }

    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

resource "null_resource" "check_crd" {
  depends_on = [resource.null_resource.dependencies]
  provisioner "local-exec" {
    command = <<EOT
      if kubectl get crd gateways.gateway.networking.k8s.io &>/dev/null; then
        echo "CRD já instalado."
      else
        echo "CRD não encontrado. Instalando..."
        kubectl kustomize "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v1.2.0" | kubectl apply -f -
      fi
    EOT
  }
}

resource "argocd_application" "base" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-base-${var.destination_cluster}" : "istio-base"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "istio-base"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/istio-base"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    ignore_difference {
      group         = "admissionregistration.k8s.io"
      kind          = "ValidatingWebhookConfiguration"
      name          = "istiod-default-validator"
      json_pointers = ["/webhooks/0/failurePolicy"]
    }

    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }

      sync_options = [
        "CreateNamespace=true",
      ]
    }
  }
  depends_on = [null_resource.check_crd]
}

resource "argocd_application" "istiod" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-istiod-${var.destination_cluster}" : "istio-istiod"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "istio-istiod"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/istio-istiod"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    ignore_difference {
      group         = "admissionregistration.k8s.io"
      kind          = "ValidatingWebhookConfiguration"
      name          = "istio-validator-istio-system"
      json_pointers = ["/webhooks/0/failurePolicy"]
    }

    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }
    }
  }

  depends_on = [
    resource.argocd_application.base
  ]
}

resource "argocd_application" "cni" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-cni-${var.destination_cluster}" : "istio-cni"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "istio-cni"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/istio-cni"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }
    }
  }

  depends_on = [
    resource.argocd_application.istiod
  ]
}

resource "argocd_application" "ztunnel" {
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-ztunnel-${var.destination_cluster}" : "istio-ztunnel"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "istio-ztunnel"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/istio-ztunnel"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }
    }
  }

  depends_on = [
    resource.argocd_application.cni
  ]
}

resource "argocd_application" "gateway" {
  count = var.gateway ? 1 : 0
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "istio-ingressgateway-${var.destination_cluster}" : "istio-ingressgateway"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "istio-ingressgateway"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/istio-gateway"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = "istio-ingress"
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }

      sync_options = [
        "CreateNamespace=true",
      ]
    }
  }

  depends_on = [
    resource.argocd_application.ztunnel
  ]
}

resource "argocd_application" "kiali" {
  count = var.kiali ? 1 : 0
  metadata {
    name      = var.destination_cluster != "in-cluster" ? "kiali-${var.destination_cluster}" : "kiali"
    namespace = var.argocd_namespace
    labels = merge({
      "application" = "kiali"
      "cluster"     = var.destination_cluster
    }, var.argocd_labels)
  }

  timeouts {
    create = "15m"
    delete = "15m"
  }

  wait = var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? false : true

  spec {
    project = var.argocd_project == null ? argocd_project.this[0].metadata.0.name : var.argocd_project

    source {
      repo_url        = var.project_source_repo
      path            = "charts/kiali-operator"
      target_revision = var.target_revision
      helm {
        values = data.utils_deep_merge_yaml.values.output
      }
    }

    destination {
      name      = var.destination_cluster
      namespace = var.namespace
    }

    sync_policy {
      dynamic "automated" {
        for_each = toset(var.app_autosync == { "allow_empty" = tobool(null), "prune" = tobool(null), "self_heal" = tobool(null) } ? [] : [var.app_autosync])
        content {
          prune       = automated.value.prune
          self_heal   = automated.value.self_heal
          allow_empty = automated.value.allow_empty
        }
      }

      retry {
        backoff {
          duration     = "20s"
          max_duration = "2m"
          factor       = "2"
        }
        limit = "5"
      }

      sync_options = [
        "CreateNamespace=true",
      ]
    }
  }

  depends_on = [
    resource.argocd_application.ztunnel
  ]
}

resource "null_resource" "this" {
  depends_on = [
    resource.argocd_application.ztunnel,
    var.gateway ? resource.argocd_application.gateway : null,
    var.kiali ? resource.argocd_application.kiali : null,
  ]
}
