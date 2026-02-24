terraform {
  required_providers {
    openstack = {
      source  = "openstack/openstack"
      version = ">= 1.50.0"
    }
  }
}

provider "openstack" {
  auth_url    = var.auth_url
  user_name   = var.user_name
  password    = var.password
  tenant_name = var.tenant_name
  region      = var.region
}

resource "openstack_compute_instance_v2" "vm" {
  name            = "pixname-vm"
  image_name      = "Ubuntu 22.04"
  flavor_name     = "m1.small"
  key_pair        = var.key_pair_name
  security_groups = ["default"]

  network {
    name = "private"
  }
}

output "public_ip" {
  value = openstack_compute_instance_v2.vm.access_ip_v4
}
