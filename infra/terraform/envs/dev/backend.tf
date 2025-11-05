terraform {
  backend "s3" {
    bucket         = "cloud-native-eks-ha-stack-dev-tfstate"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloud-native-eks-ha-stack-terraform-locks"
    encrypt        = true
  }
}
