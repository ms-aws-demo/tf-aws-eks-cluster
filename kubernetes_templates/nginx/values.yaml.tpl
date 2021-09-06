service:
  type: LoadBalancer
  port: 80
  httpsPort: 443
  additionalHeadless: true
  annotations:
    name: nginx-elb
    alb.ingress.kubernetes.io/subnets: ${nginx_alb_subnet}
    kubernetes.io/ingress.class: alb
    service.beta.kubernetes.io/aws-load-balancer-type: alb
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
    service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: '300'
  labels:
    app: nginx
  externalTrafficPolicy: Cluster
ingress:
  enabled: true