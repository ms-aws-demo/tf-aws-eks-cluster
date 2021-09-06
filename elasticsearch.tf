variable "domain" {
  default = "ms-demo-es-domain"
}

data "aws_caller_identity" "current" {}

resource "aws_security_group" "es" {
  name        = "elasticsearch-${var.domain}"
  description = "Managed by Terraform"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
        module.vpc.vpc_cidr_block
    ]
  }
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}


resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.domain
  elasticsearch_version = "7.10"

  cluster_config {
    instance_type = "t3.small.elasticsearch"
  }

  vpc_options {
    subnet_ids = [
        module.vpc.private_subnets[0],
    ]

    security_group_ids = [aws_security_group.es.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp2"
    volume_size = 20
  }

  access_policies = <<CONFIG
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "es:*",
            "Principal": "*",
            "Effect": "Allow",
            "Resource": "arn:aws:es:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*",
            "Condition": {
            }
        }
    ]
}
CONFIG

  tags = {
    Domain = "es-domain-example"
  }

  depends_on = [aws_iam_service_linked_role.es]
}
