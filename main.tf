provider "google" {
  project = "plated-epigram-452709-h6"
  region  = "us-west1"
  zone    = "us-west1-a"
}

resource "tls_private_key" "my_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance_template" "app_template" {
  name         = "app-instance-template"
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

resource "google_compute_region_instance_group_manager" "app_mig" {
  name               = "app-mig"
  base_instance_name = "app-instance"
  region             = "us-west1"
  version {
    instance_template = google_compute_instance_template.app_template.self_link
  }
  target_size = 2
}

output "private_key" {
  value     = tls_private_key.my_ssh_key.private_key_pem
  sensitive = true
}

output "mig_name" {
  value = google_compute_region_instance_group_manager.app_mig.name
}

output "mig_region" {
  value = google_compute_region_instance_group_manager.app_mig.region
}
