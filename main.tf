provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
  credentials = file(var.credentials_file)
}

resource "google_compute_instance_template" "apache_template" {
  name         = "apache-template"
  machine_type = "e2-medium"

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = <<-EOT
      #!/bin/bash
      apt-get update
      apt-get install apache2 -y
      systemctl enable apache2
      systemctl start apache2
    EOT
  }

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]
}

resource "google_compute_region_instance_group_manager" "apache_mig" {
  name               = "apache-mig"
  base_instance_name = "apache"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.apache_template.self_link
  }

  target_size = 2

  auto_healing_policies {
    initial_delay_sec = 300
  }
}

resource "google_compute_autoscaler" "apache_autoscaler" {
  name   = "apache-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.apache_mig.self_link

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cpu_utilization {
      target = 0.6
    }
  }
}

resource "google_compute_health_check" "default" {
  name               = "apache-health-check"
  check_interval_sec = 5
  timeout_sec        = 5
  healthy_threshold  = 2
  unhealthy_threshold = 2

  http_health_check {
    port = 80
    request_path = "/"
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "apache-backend"
  load_balancing_scheme = "EXTERNAL"
  protocol              = "HTTP"

  backends {
    group = google_compute_region_instance_group_manager.apache_mig.instance_group
  }

  health_checks = [google_compute_health_check.default.self_link]
}

resource "google_compute_url_map" "default" {
  name            = "apache-url-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name    = "apache-http-proxy"
  url_map = google_compute_url_map.default.self_link
}

resource "google_compute_global_address" "default" {
  name = "apache-global-ip"
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "apache-forwarding-rule"
  ip_address = google_compute_global_address.default.address
  target     = google_compute_target_http_proxy.default.self_link
  port_range = "80"
}
