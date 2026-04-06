# -----------------------------------------------------------------------------
# Phase 1: VPC + Subnets + Firewall Rules
# -----------------------------------------------------------------------------
# GCP vs AWS mental model:
#   - VPC is GLOBAL (not regional like AWS). One VPC spans all regions.
#   - Subnets are REGIONAL (not per-AZ). A subnet in us-east4 spans all
#     zones in us-east4 automatically.
#   - Firewall rules are VPC-level and use "target tags" to scope which
#     instances they apply to — unlike AWS security groups that attach
#     directly to an ENI/instance.
#   - There's no "Internet Gateway" resource. Routes + firewall rules
#     control egress/ingress directly.
# -----------------------------------------------------------------------------

# --- VPC ---
resource "google_compute_network" "main" {
  name    = "${var.environment}-vpc"
  project = var.project_id

  # CRITICAL: Always set this to false in production/gov environments.
  # When true, GCP auto-creates a subnet in every region with a default
  # CIDR — you lose control of your IP space. In AWS terms, this is like
  # the default VPC you always delete.
  auto_create_subnetworks = false

  # Delete the default routes that GCP creates (including the default
  # internet route). We'll add back only what we need.
  delete_default_routes_on_create = true
}

# --- Subnets ---
# In GCP, one subnet covers the entire region (all zones). No need for
# separate subnets per AZ like AWS. This simplifies the design but means
# you think "regional" not "zonal" for subnets.

resource "google_compute_subnetwork" "private" {
  name    = "${var.environment}-private-subnet"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id # Use .id, not .name

  ip_cidr_range = "10.0.1.0/24"

  # CRITICAL for government environments:
  # This lets VMs without public IPs reach Google APIs (Cloud Storage,
  # BigQuery, etc.) via internal routes instead of going through the internet.
  # AWS equivalent: VPC Gateway Endpoints for S3/DynamoDB.
  private_ip_google_access = true

  # Secondary ranges for GKE pods and services (Phase 4 will use these).
  # GKE requires dedicated secondary ranges — it won't share the primary.
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.10.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.20.0.0/20"
  }

  # Enable VPC Flow Logs — required for FedRAMP/NIST compliance.
  # AWS equivalent: VPC Flow Logs to CloudWatch/S3.
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0 # 100% sampling for compliance
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# --- Cloud Router + NAT ---
# VMs without public IPs still need outbound internet access (package updates,
# external API calls). Cloud NAT provides this.
# AWS equivalent: NAT Gateway in a public subnet.

resource "google_compute_router" "main" {
  name    = "${var.environment}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.main.id
}

resource "google_compute_router_nat" "main" {
  name    = "${var.environment}-nat"
  project = var.project_id
  region  = var.region
  router  = google_compute_router.main.name

  # AUTO_ONLY = GCP allocates ephemeral external IPs for NAT.
  # For gov environments, you might use MANUAL_ONLY with static IPs
  # so you can whitelist them in firewall rules on the other end.
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# --- Default internet route ---
# We deleted default routes above, so we add back a controlled egress route
# through the default internet gateway. Cloud NAT will handle the actual
# translation for instances without public IPs.

resource "google_compute_route" "internet" {
  name             = "${var.environment}-internet-route"
  project          = var.project_id
  network          = google_compute_network.main.id
  dest_range       = "0.0.0.0/0"
  next_hop_gateway = "default-internet-gateway"
  priority         = 1000
}

# --- Firewall Rules ---
# GCP firewalls are VPC-level, not subnet-level. You scope them using
# "target_tags" (applied to instances) or "target_service_accounts".
# For gov/production, prefer target_service_accounts over tags — tags can
# be set by anyone with compute.instances.setTags, but SA-based rules
# require IAM permissions to impersonate.

# Allow internal communication within the VPC
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }

  # Only from our VPC CIDR ranges (primary + secondary)
  source_ranges = [
    "10.0.1.0/24",  # primary subnet
    "10.10.0.0/16", # pods
    "10.20.0.0/20", # services
  ]
}

# Allow SSH from IAP (Identity-Aware Proxy) only — NO direct SSH from internet.
# IAP tunneling is the GCP equivalent of AWS SSM Session Manager.
# Traffic comes from Google's IAP service (35.235.240.0/20), which
# authenticates users via IAM before forwarding to the instance.
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.environment}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # This is the IAP forwarding range — NOT the public internet.
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["allow-iap-ssh"]
}

# Deny all other ingress (explicit deny — defense in depth).
# GCP has implied deny-all-ingress and allow-all-egress rules, but being
# explicit about it is better for audits and compliance documentation.
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.environment}-deny-all-ingress"
  project = var.project_id
  network = google_compute_network.main.id

  direction = "INGRESS"
  priority  = 65534 # Just above the implied rules at 65535

  deny {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
}
