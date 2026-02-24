terraform {
  required_providers {
    openstack = {
      source  = "openstack/openstack"
      version = "1.54.1"
    }
  }
}

provider "openstack" {}

resource "openstack_compute_instance_v2" "vm" {
  name            = "pixname-vm"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.keypair_name
  security_groups = ["default"]

  network {
    name = var.network_name
  }
}

output "public_ip" {
  value = openstack_compute_instance_v2.vm.access_ip_v4
}
