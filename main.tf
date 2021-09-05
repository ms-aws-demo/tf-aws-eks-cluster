data "terraform_remote_state" "ms-aws-demo" {
  backend = "s3"
  config = {
    bucket  = "ms-aws-demo-tf-states"
    key     = "ms-aws-demo/main.tfstate"
    region  = "us-east-2"
  }
}