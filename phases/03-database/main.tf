# -----------------------------------------------------------------------------
# Phase 3: Cloud SQL (PostgreSQL) with Private VPC Peering
# -----------------------------------------------------------------------------
# GCP vs AWS mental model — THIS IS THE BIG DIFFERENCE:
#
#   AWS RDS: Your database sits IN your subnet. You pick the subnet group,
#   attach security groups, done. The database has a private IP in your CIDR.
#
#   GCP Cloud SQL: The database runs in a GOOGLE-MANAGED VPC (not yours).
#   To give it a private IP reachable from your VPC, you must set up
#   VPC peering between your network and Google's internal service network.
#   This is called "Private Services Access" (PSA).
#
#   Think of it like this:
#   - AWS: RDS is a tenant in YOUR house
#   - GCP: Cloud SQL lives in GOOGLE'S house, you build a private hallway
#     (VPC peering) between the two houses
#
#   This is one of the most commonly asked GCP interview questions because
#   it trips up everyone coming from AWS.
# -----------------------------------------------------------------------------

# --- Look up existing VPC from Phase 1 ---
data "google_compute_network" "main" {
  name    = "${var.environment}-vpc"
  project = var.project_id
}

# --- Private Services Access (VPC Peering to Google) ---
# Step 1: Reserve an IP range in YOUR VPC for Google to use.
# Google's managed services (Cloud SQL, Memorystore, etc.) will get IPs
# from this range. You're carving out address space and handing it to Google.

resource "google_compute_global_address" "private_services" {
  name          = "${var.environment}-private-services-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20 # /20 = 4096 IPs for Google-managed services
  network       = data.google_compute_network.main.id
}

# Step 2: Create the peering connection.
# This tells Google "use the IP range we reserved above for your managed
# services, and peer it with our VPC so traffic flows privately."

resource "google_service_networking_connection" "private_services" {
  network                 = data.google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]

  # deletion_policy = "ABANDON" means if you destroy this resource,
  # Terraform won't try to delete the peering (which can fail if Cloud SQL
  # instances still exist). Safer for teardown ordering.
  deletion_policy = "ABANDON"
}

# --- Cloud SQL Instance (PostgreSQL) ---

resource "google_sql_database_instance" "main" {
  name             = "${var.environment}-postgres-01"
  project          = var.project_id
  region           = var.region
  database_version = "POSTGRES_15"

  # Don't destroy the database if someone runs terraform destroy accidentally.
  # In production, set this to true. For practice, false is fine.
  deletion_protection = false

  # The instance can't be created until the VPC peering is ready.
  depends_on = [google_service_networking_connection.private_services]

  settings {
    tier              = var.db_tier
    availability_type = "REGIONAL" # Multi-zone HA — AWS equivalent: Multi-AZ RDS
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = true

    ip_configuration {
      # ========================================================
      # ipv4_enabled = false — NO PUBLIC IP ON THE DATABASE
      # ========================================================
      # This is the Cloud SQL equivalent of "no access_config" on VMs.
      # If this is true, the database gets a public IP and is reachable
      # from the internet (even with SSL required, this is a finding).
      # ========================================================
      ipv4_enabled    = false
      private_network = data.google_compute_network.main.id
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true # Continuous WAL archiving

      # Backup during off-hours (UTC)
      start_time = "03:00"

      # Keep backups for 30 days — FedRAMP requires defined retention.
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4 # 4 AM UTC
      update_track = "stable"
    }

    # Database flags — GCP's equivalent of RDS parameter groups.
    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_statement"
      value = "ddl" # Log all DDL statements (CREATE, ALTER, DROP)
    }
  }
}

# --- Database ---
resource "google_sql_database" "app" {
  name     = "app"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
}

# --- Database User ---
resource "google_sql_user" "app" {
  name     = "app_user"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = var.db_password
}
