terraform {
  required_version = ">= 1.6.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.120.0"
    }
  }
}

variable "cloud_id" {}
variable "folder_id" {}
variable "zone" { default = "ru-central1-a" }
variable "sa_key_file" {}

provider "yandex" {
  service_account_key_file = var.sa_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_vpc_network" "net" {
  name = "pixname-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "pixname-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}

resource "yandex_vpc_security_group" "sg" {
  name       = "pixname-sg"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "App 8000"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8000
  }

  ingress {
    protocol       = "TCP"
    description    = "Grafana 3000"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 3000
  }

  egress {
    protocol       = "ANY"
    description    = "all egress"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vm" {
  name        = "pixname-vm"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    # ВАЖНО: сюда положи публичный ключ, который соответствует `vm-ssh-key` в Jenkins
    ssh-keys = "ubuntu:${file("id_rsa.pub")}"
  }
}

output "public_ip" {
  value = yandex_compute_instance.vm.network_interface[0].nat_ip_address
}
