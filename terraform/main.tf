provider "openstack" {
  auth_url    = var.auth_url
  user_name   = var.user_name
  password    = var.password
  tenant_name = var.tenant_name
  domain_name = var.domain_name
  region      = var.region
}

data "openstack_images_image_v2" "img" {
  name        = var.image_name
  most_recent = true
}

data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor_name
}

data "openstack_networking_network_v2" "net" {
  name = var.network_name
}

resource "openstack_networking_secgroup_v2" "sg" {
  name        = "${var.vm_name}-sg"
  description = "pixname security group"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allow_ssh_cidr
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = var.allow_http_cidr
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = var.allow_http_cidr
  security_group_id = openstack_networking_secgroup_v2.sg.id
}

resource "openstack_compute_instance_v2" "vm" {
  name            = var.vm_name
  image_id        = data.openstack_images_image_v2.img.id
  flavor_id       = data.openstack_compute_flavor_v2.flavor.id
  key_pair        = var.keypair_name
  security_groups = [openstack_networking_secgroup_v2.sg.name]

  network {
    uuid = data.openstack_networking_network_v2.net.id
  }
}

# Floating IP из пула (часто pool называется "public" / "ext-net" / "external")
variable "floating_ip_pool" { default = "public" }

resource "openstack_networking_floatingip_v2" "fip" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  instance_id = openstack_compute_instance_v2.vm.id
}
