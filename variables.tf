variable "eks_node_type" {
  default = "t2.nano"
}

variable "region" {
  default     = "us-east-2"
  description = "AWS region"
}

variable "terraform_user_arn" {
  default = "arn:aws:iam::184521843984:user/ms-aws-demo-tf"
  #default = "arn:aws:iam::184521843984:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS"
}

variable "aws_auth_additional_labels" {
  description = "Additional kubernetes labels applied on aws-auth ConfigMap"
  default     = {}
  type        = map(string)
}

variable "trusted_user_arns" {
  description = "User arns for the AWS account allowed to assume managed roles"
  default     = {}
  type        = map(string)
}

variable "map_roles" {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      rolearn  = "arn:aws:iam::184521843984:role/EKS_Admin"
      username = "EKS_Admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::184521843984:role/EKS_Developer"
      username = "EKS_Developer"
      groups   = ["system:masters"]
    },
  ]
}

variable "map_users" {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))

  default = [
    {
      userarn  = "arn:aws:iam::184521843984:user/ms-admin-user"
      username = "ms-admin-user"
      groups   = ["system:masters"]
    },
  ]
}