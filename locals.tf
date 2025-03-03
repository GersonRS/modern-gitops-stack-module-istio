locals {
  helm_values = [{
    istiod = {
      profile = "ambient"
    }
    cni = {
      profile = "ambient"
    }
    kiali-operator = {
      cr = {
        create = true
        namespace : var.namespace
        annotations : {}
        spec = {
          auth = {
            strategy = "anonymous"
          }
          deployment = {
            cluster_wide_access = true
            # discovery_selectors = {
            #   default = [
            #     {
            #       matchLabels = {
            #         "kubernetes.io/metadata.name" = "default"
            #       }
            #     },
            #     {
            #       matchLabels = {
            #         region = "east"
            #       },
            #       matchExpressions = [
            #         {
            #           key      = "app"
            #           operator = "In"
            #           values   = ["ticketing"]
            #         },
            #         {
            #           key      = "color"
            #           operator = "In"
            #           values   = ["blue"]
            #         }
            #       ]
            #     }
            #   ]
            # }
            view_only_mode = false
          }
          server = {
            web_root = "/kiali"
          }
          external_services = {
            prometheus = {
              url = "http://kube-prometheus-stack-prometheus.kube-prometheus-stack.svc.cluster.local:9090/"
            }
            grafana = {
              enabled      = true
              internal_url = "http://kube-prometheus-stack-grafana.kube-prometheus-stack.svc.cluster.local:3000/"
              external_url = "https://grafana.apps.kind.172-19-0-101.nip.io/"
              dashboards = [
                {
                  name = "Istio Service Dashboard"
                  variables = {
                    namespace = var.namespace
                    service   = "var-service"
                  }
                },
                {
                  name = "Istio Workload Dashboard"
                  variables = {
                    namespace = var.namespace
                    workload  = "var-workload"
                  }
                },
                {
                  name = "Istio Mesh Dashboard"
                },
                {
                  name = "Istio Control Plane Dashboard"
                },
                {
                  name = "Istio Performance Dashboard"
                },
                {
                  name = "Istio Wasm Extension Dashboard"
                }
              ]
            }
          }
        }
      }
    }
  }]
}
