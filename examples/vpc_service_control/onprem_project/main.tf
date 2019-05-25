/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

provider "google" {
  credentials = "${file("${var.service_account_file}")}"
}

resource "google_project" "on_prem_network_project" {
  name = "On Prem Network"
  project_id = "${var.project_id}"
  org_id     = "${var.organization_id}"
  billing_account	= "${var.billing_account_id}"
  auto_create_network = true
}


/* STEP 1A: DELETE THIS COMMENT LINE TO RESERVE STATIC IP (costs ~$0.24/day) 
resource "google_compute_address" "onprem_vpn_ip" {
  address_type = "EXTERNAL"
  name         = "onprem-vpn-ip"
  network_tier = "PREMIUM"
  project      = "${google_project.on_prem_network_project.project_id}"
  region       = "${var.cloud_router_region}"
} 

output "ip_addr_of_onprem_vpn_router" {
  value = "${google_compute_address.onprem_vpn_ip.address}"
}
STEP 1B: DELETE THIS END-COMMENT LINE.  Then run terraform apply. */


/* STEP 3A: DELETE THIS COMMENT LINE TO CREATE ONPREM VPN ROUTER (costs ~$1.80/day)
resource "google_compute_router" "onprem_cloud_router" {
  bgp {
    advertise_mode = "DEFAULT"
    asn            = "64512"
  }

  name    = "onprem-cloud-router"
  network = "default"
  project = "${google_project.on_prem_network_project.project_id}"
  region  = "${var.cloud_router_region}"
}

resource "google_compute_vpn_gateway" "target_gateway" {
  name    = "target-vpn-gateway"
  network = "default"
  project = "${google_project.on_prem_network_project.project_id}"
  region  = "${var.cloud_router_region}"
}

resource "google_compute_forwarding_rule" "fr_for_vpn_gateway" {
  name        = "frforvpngateway"
  ip_protocol = "ESP"
  ip_address  = "${google_compute_address.onprem_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.target_gateway.self_link}"
  project = "${google_project.on_prem_network_project.project_id}"
  region = "${var.cloud_router_region}"
}

resource "google_compute_forwarding_rule" "fr_udp500" {
  name        = "frforvpngatewayudp500"
  ip_protocol = "UDP"
  port_range = "500"
  ip_address  = "${google_compute_address.onprem_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.target_gateway.self_link}"
  project = "${google_project.on_prem_network_project.project_id}"
  region = "${var.cloud_router_region}"
}

resource "google_compute_forwarding_rule" "fr_udp4500" {
  name        = "frforvpngatewayudp4500"
  ip_protocol = "UDP"
  port_range = "4500"
  ip_address  = "${google_compute_address.onprem_vpn_ip.address}"
  target      = "${google_compute_vpn_gateway.target_gateway.self_link}"
  project = "${google_project.on_prem_network_project.project_id}"
  region = "${var.cloud_router_region}"
}

resource "google_compute_vpn_tunnel" "onprem_vpn_tunnel" {
  ike_version             = "2"
  name                    = "onprem-vpn-tunnel"
  peer_ip                 = "${var.ip_addr_of_cloud_vpn_router}"
  project                 = "${google_project.on_prem_network_project.project_id}"
  region                  = "${var.cloud_router_region}"
  router                  = "${google_compute_router.onprem_cloud_router.self_link}"
  target_vpn_gateway      = "${google_compute_vpn_gateway.target_gateway.name}"
  shared_secret           = "${var.shared_secret_string_for_vpn_connection}"
}

resource "google_compute_router_interface" "onprem_router_interface" {
  name       = "onprem-router-interface"
  router     = "${google_compute_router.onprem_cloud_router.name}"
  region     = "${var.cloud_router_region}"
  ip_range   = "169.254.1.1/30"
  vpn_tunnel = "${google_compute_vpn_tunnel.onprem_vpn_tunnel.self_link}"
  project                 = "${google_project.on_prem_network_project.project_id}"
}

resource "google_compute_router_peer" "onprem_router_peer" {
  name                      = "peer-1"
  router                    = "${google_compute_router.onprem_cloud_router.name}"
  region                    = "${var.cloud_router_region}"
  peer_ip_address           = "169.254.1.2"
  peer_asn                  = 64513
  advertised_route_priority = 100
  interface                 = "${google_compute_router_interface.onprem_router_interface.name}"
  project                 = "${google_project.on_prem_network_project.project_id}"
}

resource "google_compute_route" "onprem_to_vpn_route" {
  name       = "onprem-to-vpn-route"
  network    = "default"
  dest_range = "10.7.0.0/16"
  priority   = 1000
  project                 = "${google_project.on_prem_network_project.project_id}"
  next_hop_vpn_tunnel = "${google_compute_vpn_tunnel.onprem_vpn_tunnel.self_link}"
}
 STEP 3B: DELETE THIS END-COMMENT LINE.  Then run terraform apply. */



/**********************************************/
/***** BEGIN JUMPHOST AND FWD PROXY VM'S ******/
/**********************************************/
/* STEP 5A: DELETE THIS COMMENT LINE TO CREATE ONPREM FORWARD PROXY AND WINDOWS JUMPHOST (costs ~$4.61/day) 

resource "google_compute_instance" "forward_proxy_instance" {
  boot_disk {
    auto_delete = true
    device_name = "forward-proxy-instance"

    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-9-stretch-v20190423"
      size  = "10"
      type  = "pd-standard"
    }

  }

  can_ip_forward      = true
  deletion_protection = false
  labels              {}
  machine_type        = "n1-standard-1"
  metadata            {}
  name                = "forward-proxy-instance"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    network            = "default"
    network_ip         = "10.138.0.2"
  }

  project = "${google_project.on_prem_network_project.project_id}"

  metadata_startup_script = "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; sysctl -w net.ipv4.ip_forward=1"

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  tags = ["forward-proxy"]
  zone = "${var.cloud_router_region}-b"
}

resource "google_compute_instance" "windows_jumphost" {
  boot_disk {
    auto_delete = true
    device_name = "windows-jumphost"

    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/windows-cloud/global/images/windows-server-2019-dc-v20190411"
      size  = "50"
      type  = "pd-ssd"
    }

  }

  can_ip_forward      = false
  deletion_protection = false
  labels              {}
  machine_type        = "n1-standard-2"


  name = "windows-jumphost"

  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    network            = "default"
    network_ip         = "10.138.0.3"
  }

  project = "${google_project.on_prem_network_project.project_id}"

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  service_account {
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  tags = ["forward-proxy"]
  zone = "${var.cloud_router_region}-b"
}

 STEP 5B: DELETE THIS END-COMMENT LINE.  Then run terraform apply. */





/*********************************/
/***** BEGIN FIREWALL RULES ******/
/*********************************/

resource "google_compute_firewall" "allow_all_from_internal" {
  allow {
    protocol = "all"
  }

  direction     = "INGRESS"
  disabled      = false
  name          = "allow-all-from-internal"
  network       = "default"
  priority      = "1000"
  project       = "${google_project.on_prem_network_project.project_id}"
  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["forward-proxy"]
}





/*************************/
/***** BEGIN ROUTES ******/
/*************************/

resource "google_compute_route" "default_for_all" {
  dest_range  = "0.0.0.0/0"
  name        = "default-for-all"
  network     = "default"
  next_hop_ip = "10.138.0.2"
  priority    = "1000"
  project     = "${google_project.on_prem_network_project.project_id}"
}

resource "google_compute_route" "default_for_forward_proxy" {
  dest_range       = "0.0.0.0/0"
  name             = "default-for-forward-proxy"
  network          = "default"
  next_hop_gateway = "https://www.googleapis.com/compute/v1/projects/${google_project.on_prem_network_project.project_id}/global/gateways/default-internet-gateway"
  priority         = "100"
  project          = "${google_project.on_prem_network_project.project_id}"
  tags             = ["forward-proxy"]
}
