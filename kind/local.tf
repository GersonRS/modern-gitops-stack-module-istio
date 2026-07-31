locals {
  # try() avoids a hard failure (and blocking the entire plan/apply) when the
  # gateway Service doesn't have a LoadBalancer IP yet, e.g. on a fresh
  # bootstrap where MetalLB hasn't assigned one. Self-heal reconciles the
  # real domain once the IP becomes available on a later apply.
  gateway_ip   = try(data.kubernetes_resource.istio_gateway.object.status.loadBalancer.ingress[0].ip, "127.0.0.1")
  gateway_name = format("%s.nip.io", replace(local.gateway_ip, ".", "-"))

  helm_values = [{
    gateway_certificate_config = {
      name           = "istio-gateway-tls"
      namespace      = "istio-ingress"
      cluster_issuer = var.cluster_issuer
      dns_names = [
        "*.${local.gateway_name}",
        "*.${var.subdomain}.${local.gateway_name}",
      ]
    }
  }]
}
