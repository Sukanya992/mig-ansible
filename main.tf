provider "google" {
  project = "plated-epigram-452709-h6"
  region  = "us-west1"
  zone    = "us-west1-a"
}

resource "tls_private_key" "my_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance_template" "template" {
  name_prefix = "mig-template"

  machine_type = "e2-standard-2"

  tags = ["web"]

  disk {
    auto_delete  = true
    boot         = true
    source_image = "centos-stream-9"
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "ansible:${tls_private_key.my_ssh_key.public_key_openssh}"
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_instance_group_manager" "mig" {
  name               = "harness-mig"
  base_instance_name = "mig-instance"
  version {
    instance_template = google_compute_instance_template.template.self_link
  }
  zone              = "us-west1-a"
  target_size       = 1
  wait_for_instances = true
}

data "google_compute_instance" "mig_instance" {
  name = google_compute_instance_group_manager.mig.instance_group
  zone = "us-west1-a"
  depends_on = [google_compute_instance_group_manager.mig]
}

output "private_key" {
  value     = tls_private_key.my_ssh_key.private_key_pem
  sensitive = true
}

output "vm_external_ip" {
  value = data.google_compute_instance.mig_instance.network_interface[0].access_config[0].nat_ip
}
