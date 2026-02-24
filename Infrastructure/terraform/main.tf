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
  image_name      = "Ubuntu 22.04"
  flavor_name     = "m1.small"
  key_pair        = var.keypair_name
  security_groups = ["default"]

  network {
    name = "private"
  }
}

output "public_ip" {
  value = openstack_compute_instance_v2.vm.access_ip_v4
}
