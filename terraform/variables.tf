variable "name_prefix" { type = string }

variable "os_auth_url"     { type = string }
variable "os_tenant_name"  { type = string }
variable "os_username"     { type = string }
variable "os_password"     { type = string }
variable "os_region"       { type = string }
variable "os_domain_name"  { type = string }

variable "image_name"   { type = string }
variable "flavor_name"  { type = string }
variable "network_name" { type = string }

variable "floating_ip_pool" { type = string }

variable "ssh_public_key" { type = string }

variable "app_port" {
  type    = number
  default = 8000
}
