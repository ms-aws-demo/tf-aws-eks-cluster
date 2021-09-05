provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  namespace = "nginx-sites"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace = "nginx-sites"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
}

