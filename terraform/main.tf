terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
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
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.key_pair_name
  security_groups = ["default"]

  network {
    name = var.network_name
  }
}

output "public_ip" {
  value = openstack_compute_instance_v2.vm.access_ip_v4
}
