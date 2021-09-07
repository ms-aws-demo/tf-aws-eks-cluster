resource "aws_iam_role_policy" "eks_dev_policy" {
  # ... other configuration ...
  policy = "${data.template_file.eks_dev_policy.rendered}"
  role = aws_iam_role.eks_dev_role.id
}

resource "aws_iam_role_policy" "eks_admin_policy" {
  # ... other configuration ...
  policy = "${data.template_file.eks_admin_policy.rendered}"
  role = aws_iam_role.eks_admin_role.id
}

data "template_file" "trust_policy" {
  template = "${file("policy_templates/trust_policy.json.tpl")}"

  vars = {
    admin_trust_arn = var.admin_user_arn
    tf_trust_arn = var.terraform_user_arn
    cyderes_trust_arn = var.cyderes_user_arn
    #"${aws_vpc.example.arn}"
  }
}

data "template_file" "eks_admin_policy" {
  template = "${file("policy_templates/eks_admin_policy.json.tpl")}"

  vars = {
    cluster_arn = module.eks.cluster_arn
  }
}

data "template_file" "eks_dev_policy" {
  template = "${file("policy_templates/eks_dev_policy.json.tpl")}"

  vars = {
    cluster_arn = module.eks.cluster_arn
  }
}
