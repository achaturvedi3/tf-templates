terraform {
  backend "s3" {
    bucket         = "vbcappsdevops-hdap-terraform-state"
    key            = "VBCAPPSDEVOPS/HDAP/hdap.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}