terraform {
  backend "s3" {
    bucket         = "cloud-native-eks-ha-stack-tfstate-dev"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
