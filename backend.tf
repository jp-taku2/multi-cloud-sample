terraform {
  required_version = ">= 0.12.0"

  backend "s3" {
    bucket                  = "test-suzutaku"
    key                     = "terraform.tfstate"
    region                  = "ap-northeast-1"
    shared_credentials_file = "~/.aws/credentials"
    profile                 = "sandbox"
  }
}
