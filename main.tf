provider "google" {
  project = "plated-epigram-452709-h6"
  zone    = "us-central1-a"
}

resource "tls_private_key" "my_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  ssh_pub_key = tls_private_key.my_ssh_key.public_key_openssh
}

resource "google_compute_instance_template" "temp1" {
  name         = "template1"
  machine_type = "e2-standard-2"

  disk {
    auto_delete  = true
    boot         = true
    source_image = "centos-cloud/centos-stream-9"
  }

  network_interface {
    network = "default"

    access_config {}
  }

  metadata = {
    ssh-keys              = "ansible:${local.ssh_pub_key}"
    startup-script        = <<-EOT
      #!/bin/bash
      sudo yum update -y
      sudo dnf install epel-release -y
      sudo dnf install ansible -y
      ansible --version
    EOT
  }

  tags = ["harnessvms"]
}

resource "google_compute_health_check" "health" {
  name = "health1"

  http_health_check {
    port         = 80
    request_path = "/"
  }

  healthy_threshold   = 2
  unhealthy_threshold = 2
  timeout_sec         = 5
  check_interval_sec  = 10
}

resource "google_compute_instance_group_manager" "manager" {
  name               = "instance-manager-1"
  base_instance_name = "okay"
  zone               = "us-central1-a"

  version {
    instance_template = google_compute_instance_template.temp1.self_link
  }

  target_size = 2

  auto_healing_policies {
    health_check      = google_compute_health_check.health.self_link
    initial_delay_sec = 300
  }
}
