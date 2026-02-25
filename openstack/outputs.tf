output "pixname-vm" {
  description = "IP-адрес ВМ в сети sutdents-net"
  value       = openstack_compute_instance_v2.pixname-vm.network[0].fixed_ip_v4
}
