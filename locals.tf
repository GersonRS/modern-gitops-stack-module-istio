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
            cluster_wide_access = false
            discovery_selectors = {
              default = [{
                matchLabels = {
                  "kubernetes.io/metadata.name" = "bookinfo"
                }
              }]
            }
            view_only_mode = false
          }
          server = {
            web_root = "/kiali"
          }
        }
      }
    }
  }]
}
