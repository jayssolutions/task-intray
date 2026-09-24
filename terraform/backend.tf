terraform {
  backend "s3" {
    bucket       = "jays-07092026-875285643708-us-east-1-an"
    key          = "node_app/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}