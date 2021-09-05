resource "aws_iam_role" "eks_dev_role" {
  name = "EKS_Developer"

  assume_role_policy = "${data.template_file.trust_policy.rendered}"

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role" "eks_admin_role" {
  name = "EKS_Admin"

  assume_role_policy = "${data.template_file.trust_policy.rendered}"

  tags = {
    tag-key = "tag-value"
  }
}