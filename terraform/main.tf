terraform {
  required_version = ">= 1.5.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = ">= 1.54.0"
    }
  }
}

provider "openstack" {
  auth_url    = var.os_auth_url
  tenant_name = var.os_tenant_name
  user_name   = var.os_username
  password    = var.os_password
  region      = var.os_region
  domain_name = var.os_domain_name
}

resource "openstack_compute_keypair_v2" "jenkins" {
  name       = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
}

resource "openstack_networking_secgroup_v2" "app" {
  name        = "${var.name_prefix}-sg"
  description = "Allow ssh and app ports"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = var.app_port
  port_range_max    = var.app_port
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.app.id
}

# Если у тебя бот/графана/что-то еще — добавь правила под 3000, 8000 и т.д.

data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.yaml")
}

resource "openstack_compute_instance_v2" "vm" {
  name            = "${var.name_prefix}-vm"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.jenkins.name
  security_groups = [openstack_networking_secgroup_v2.app.name]

  network {
    name = var.network_name
  }

  user_data = data.template_file.cloud_init.rendered
}

# Плавающий IP (если используешь floating ip)
resource "openstack_networking_floatingip_v2" "fip" {
  pool = var.floating_ip_pool
}

resource "openstack_compute_floatingip_associate_v2" "fip_assoc" {
  floating_ip = openstack_networking_floatingip_v2.fip.address
  instance_id = openstack_compute_instance_v2.vm.id
}
