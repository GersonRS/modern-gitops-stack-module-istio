locals {
  helm_values = [{
    istiod = {
      profile = "ambient"
    }
    cni = {
      profile = "ambient"
    }
  }]
}
