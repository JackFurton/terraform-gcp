# Copy to terraform.tfvars and fill in your values.
# NEVER commit terraform.tfvars — it contains the db_password.

project_id  = "your-gcp-project-id"
region      = "us-east4"
environment = "dev"
db_password = "CHANGE-ME-use-a-real-password"
db_tier     = "db-f1-micro"
