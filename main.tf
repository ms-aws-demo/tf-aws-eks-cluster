
data "terraform_remote_state" "ms-aws-demo" {
  backend = "s3"
  config = {
    bucket  = "ms-aws-demo-tf-states"
    key     = "ms-aws-demo/main.tfstate"
    region  = "us-east-2"
  }
}


/*
terraform {

  backend "remote" {
    hostname = "app.terraform.io"
    organization = "ms-aws-demo"

    workspaces {
      name = "production"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.20.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.1.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.1"
    }
  }

  required_version = "> 0.14"
}
*/
