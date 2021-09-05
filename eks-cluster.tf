module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.20"
  subnets         = module.vpc.private_subnets
  cluster_endpoint_private_access       = true
  #map_roles = var.map_roles
  #module.eks.aws_iam_role.EKS_Admin.arn
  map_roles = [ 
    {
      "groups": [ "system:masters" ], 
      "rolearn": aws_iam_role.eks_admin_role.arn, 
      "username": aws_iam_role.eks_admin_role.name
    },
    {
      "groups": [ "system:node" ], 
      "rolearn": aws_iam_role.eks_dev_role.arn, 
      "username": aws_iam_role.eks_dev_role.name
    },
  ]

  map_users = var.map_users
  manage_aws_auth = true

  tags = {
    terraform_managed = "true"
    Environment = "demo"
    GithubRepo  = "terraform-aws-eks"
    GithubOrg   = "terraform-aws-modules"
  }

  vpc_id = module.vpc.vpc_id

  workers_group_defaults = {
    root_volume_type = "gp2"
  }

  worker_groups = [
    {
      name                          = "worker-group-1"
      instance_type                 = var.eks_node_type
      asg_desired_capacity          = 1
      additional_security_group_ids = [aws_security_group.worker_group_mgmt_one.id]
    },
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
