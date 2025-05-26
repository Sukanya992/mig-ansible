provider "google" {
  project = "plated-epigram-452709-h6"
  region  = "us-west1"
  zone    = "us-west1-a"
}

resource "google_compute_instance_template" "default" {
  name_prefix = "mig-template-"
  machine_type = "e2-standard-2"

  disk {
    source_image = "centos-stream-9"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "ansible:${tls_private_key.my_ssh_key.public_key_openssh}"
  }
}

resource "tls_private_key" "my_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_region_instance_group_manager" "mig" {
  name               = "my-mig"
  region             = var.region
  base_instance_name = "ansible-instance"
  version {
    instance_template = google_compute_instance_template.default.self_link
  }
  target_size = 2
}

data "google_compute_instance_group" "mig_group" {
  name   = google_compute_region_instance_group_manager.mig.instance_group
  region = var.region
}

data "google_compute_instance" "instances" {
  count = length(data.google_compute_instance_group.mig_group.instances)
  name  = element(data.google_compute_instance_group.mig_group.instances, count.index)
  zone  = var.zone
}

output "instance_ips" {
  value = [for inst in data.google_compute_instance.instances : inst.network_interface[0].access_config[0].nat_ip]
  description = "Public IPs of MIG instances"
  sensitive = false
}

variable "region" {
  default = "us-west1"
}

variable "zone" {
  default = "us-west1-a"
}
