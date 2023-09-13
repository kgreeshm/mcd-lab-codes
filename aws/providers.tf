provider "aws" {
  region     = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

terraform {
  backend "s3" {
    bucket         = "kgreeshm-test-bucket"
    key            = "" #local.key #"pod-${var.pod_number}-terraform.tfstate"
    region         = "us-east-1" # Change to your desired region
    encrypt        = true
    #dynamodb_table = "<OPTIONAL_DYNAMODB_TABLE_NAME>"
  }
}