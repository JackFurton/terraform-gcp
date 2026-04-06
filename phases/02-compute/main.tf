# -----------------------------------------------------------------------------
# Phase 2: Compute Engine + Custom Service Account
# -----------------------------------------------------------------------------
# GCP vs AWS mental model:
#   - Compute Engine instance ≈ EC2 instance
#   - Service account ≈ IAM instance profile/role
#   - NEVER use the default compute service account — it has Editor role
#     on the entire project. In DoD, that's an instant audit finding.
#   - No access_config block = no public IP (this is how you enforce it)
#   - Machine images: GCP uses "image families" (like AMI aliases)
#   - Metadata startup-script ≈ EC2 user-data
# -----------------------------------------------------------------------------

# --- Look up the VPC and subnet we created in Phase 1 ---
# Using data sources instead of hardcoded values. This is how you reference
# resources managed by a different Terraform state.
# In production, you'd use terraform_remote_state with a GCS backend.

data "google_compute_network" "main" {
  name    = "${var.environment}-vpc"
  project = var.project_id
}

data "google_compute_subnetwork" "private" {
  name    = "${var.environment}-private-subnet"
  project = var.project_id
  region  = var.region
}

# --- Custom Service Account ---
# AWS equivalent: creating an IAM role + instance profile.
# The default compute SA has roles/editor — way too broad.
# Always create a dedicated SA with only the permissions needed.

resource "google_service_account" "vm" {
  account_id   = "${var.environment}-vm-sa"
  display_name = "Compute Engine VM Service Account (${var.environment})"
  project      = var.project_id
}

# Grant the SA only the permissions it actually needs.
# In this example: read from Cloud Storage, write logs, export metrics.
# AWS equivalent: attaching IAM policies to a role.

resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

resource "google_project_iam_member" "vm_storage_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.vm.email}"
}

# --- Compute Engine Instance ---

resource "google_compute_instance" "main" {
  name         = "${var.environment}-vm-01"
  project      = var.project_id
  zone         = var.zone
  machine_type = var.machine_type

  # Tags are used by firewall rules to target specific instances.
  # The "allow-iap-ssh" tag matches the firewall rule from Phase 1.
  tags = ["allow-iap-ssh", "private-vm"]

  boot_disk {
    initialize_params {
      # Image families auto-resolve to the latest image in that family.
      # AWS equivalent: using an AMI alias like "amazon-linux-2" instead
      # of a specific AMI ID.
      image = "projects/rhel-cloud/global/images/family/rhel-9"
      size  = 20 # GB
      type  = "pd-balanced" # pd-standard, pd-balanced, pd-ssd

      # Labels for cost tracking and compliance tagging
      labels = {
        environment = var.environment
        managed_by  = "terraform"
      }
    }
  }

  network_interface {
    subnetwork = data.google_compute_subnetwork.private.id

    # ========================================================
    # NO access_config BLOCK = NO PUBLIC IP
    # ========================================================
    # This is the #1 thing to remember for the interview.
    # In AWS, you'd set associate_public_ip_address = false.
    # In GCP, the ABSENCE of access_config means no public IP.
    # If you see access_config {} in someone's code, that VM
    # gets a public IP — flag it as a security issue.
    # ========================================================
  }

  # Attach the custom service account (not the default compute SA).
  service_account {
    email = google_service_account.vm.email

    # Scopes are a legacy access control layer from before IAM existed.
    # "cloud-platform" grants the SA whatever IAM roles it has — you
    # control access through IAM roles, not scopes.
    # Never use narrow scopes thinking they add security — they don't,
    # they just confuse people. Use "cloud-platform" and control via IAM.
    scopes = ["cloud-platform"]
  }

  # Startup script — runs on first boot (and every reboot).
  # AWS equivalent: EC2 user-data.
  metadata = {
    startup-script = <<-EOT
      #!/bin/bash
      set -e

      # Install Ops Agent (GCP's unified logging + monitoring agent)
      # AWS equivalent: CloudWatch Agent
      curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
      sudo bash add-google-cloud-ops-agent-repo.sh --also-install

      # Log that the instance started successfully
      logger -t startup-script "Instance provisioned by Terraform"
    EOT

    # Block project-wide SSH keys — only IAP tunneling allowed.
    # This prevents someone with project-level SSH keys from accessing
    # this specific instance.
    block-project-ssh-keys = "true"

    # Enable OS Login — maps GCP IAM identities to Linux users.
    # AWS equivalent: EC2 Instance Connect.
    # In DoD environments, this is preferred over SSH keys because
    # access is controlled via IAM and fully audited.
    enable-oslogin = "true"
  }

  # Shielded VM settings — hardware-verified boot integrity.
  # Required for FedRAMP/CMMC compliance.
  # AWS equivalent: Nitro-based instances with Secure Boot.
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  # Allow Terraform to stop the VM to apply changes (like machine type).
  allow_stopping_for_update = true

  labels = {
    environment = var.environment
    managed_by  = "terraform"
    phase       = "02-compute"
  }
}
