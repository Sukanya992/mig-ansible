provider "google" {
  project = "plated-epigram-452709-h6"
  zone    = "us-central1-a"
}

locals {
  ssh_pub_key = file("${path.module}/id_rsa.pub")
}

resource "google_compute_instance_template" "temp1" {
  name         = "template01"
  machine_type = "e2-standard-2"

  disk {
    auto_delete  = true
    boot         = true
    source_image = "centos-cloud/centos-stream-9"
  }

  network_interface {
    network = "default"

    # Adding access_config to assign an external IP
    access_config {}
  }

  metadata = {
    ssh-keys = "ansible:${local.ssh_pub_key}"
  }

  tags = ["harnessvms"]
}

resource "google_compute_health_check" "health" {
  name = "health01"

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
  name               = "instance-manager-01"
  base_instance_name = "instance"
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
