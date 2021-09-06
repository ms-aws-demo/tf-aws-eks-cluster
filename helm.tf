provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "nginx" {
  name       = "nginx"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx"
  namespace = "nginx-sites"

  values = [
      "${data.template_file.nginx-values.rendered}"
  ]

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "fluentd" {
  name       = "fluentd"

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "fluentd"
  namespace = "aws-observability"

  #values = [
  #    "${data.template_file.fluentd-values.rendered}"
  #]

}

data "template_file" "nginx-values" {
  template = "${file("kubernetes_templates/nginx/values.yaml.tpl")}"

  vars = {
    nginx_alb_subnet = module.vpc.private_subnets[0]
  }
}

data "template_file" "fluentd-values" {
  template = "${file("kubernetes_templates/fluentd/values.yaml.tpl")}"

  vars = {
    es_domain_endpoint = aws_elasticsearch_domain.es.endpoint
  }
}
