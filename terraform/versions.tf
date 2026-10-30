terraform {
  required_version = ">= 1.9"

  required_providers {
    lxd = {
      source  = "terraform-lxd/lxd"
      version = "~> 3.1"
    }
  }
}

provider "lxd" {
  default_remote = "local"

  remote {
    name    = "local"
    address = "unix://"
  }

  # Resolves the "ubuntu:" prefix of instance images.
  remote {
    name     = "ubuntu"
    address  = "https://cloud-images.ubuntu.com/releases"
    protocol = "simplestreams"
  }
}
