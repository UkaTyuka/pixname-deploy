output "Pixname-terraform_ip" {
  description = "IP-адрес ВМ в сети sutdents-net"
  value       = openstack_compute_instance_v2.Pixname-terraform.network[0].fixed_ip_v4
}
