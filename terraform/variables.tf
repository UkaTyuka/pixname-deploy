variable "auth_url" {}
variable "user_name" {}
variable "password" { sensitive = true }
variable "tenant_name" {}
variable "domain_name" { default = "Default" }
variable "region"      { default = null }

variable "vm_name"     { default = "pixname-vm" }
variable "image_name"  {}
variable "flavor_name" {}
variable "network_name" {}
variable "keypair_name" {}

# security group ingress
variable "allow_ssh_cidr"  { default = "0.0.0.0/0" }
variable "allow_http_cidr" { default = "0.0.0.0/0" }
