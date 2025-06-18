resource "random_pet" "db_suffix" {
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_database_instance" "db1" {
  database_version    = var.database_version
  name                = "${var.app_name_db}-db-${random_pet.db_suffix.id}"
  deletion_protection = true
  region              = var.region
  project             = var.project_id
  # it assumed that a private vpc connection has been created.
  # depends_on          = [google_service_networking_connection.private_vpc_connection]
  settings {
    tier = var.db_tier
    availability_type = var.db_availability_type
    ip_configuration {
      ipv4_enabled    = var.sql_public_ip
      private_network = data.google_compute_network.private_network.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }
    database_flags {
        name  = "cloudsql.enable_pgaudit"
        value = "on"
    }
    database_flags{
        name  = "pgaudit.log"
        value = "all"
    }
    database_flags{
        name  = "log_connections"
        value = "on"
    }
    database_flags{
        name  = "log_disconnections"
        value = "on"
    }
    database_flags{
        name  = "log_duration"
        value = "on"
    }
    database_flags {
        name  = "log_statement"
        value = "ddl"
    }
    database_flags {
        name  = "log_lock_waits"
        value = "on"
    }
    database_flags {
        name  = "log_temp_files"
        value = "0"
    }
    database_flags {
        name  = "log_checkpoints"
        value = "on"
    }
    password_validation_policy {
      enable_password_policy = true
      min_length = 8
      complexity = "COMPLEXITY_DEFAULT"
      disallow_username_substring = true
      # reuse_interval = 5
      # password_change_interval = 1 # hours before password can be changed again
    }
    data_cache_config {
        data_cache_enabled = false # adds SSD for data caching for additional cost
    }
    backup_configuration {
      enabled = true
      start_time = "12:00"
      location = "us-central1"
      point_in_time_recovery_enabled = true
    }
    location_preference {
      zone = var.db_primary_zone
      secondary_zone = var.db_availability_type == "REGIONAL" ? var.db_secondary_zone : null
    }
  }
}

resource "google_sql_database" "caredelivery_db" {
  project = var.project_id
  name     = "caredelivery_db"
  instance = google_sql_database_instance.db1.id

  lifecycle {
    ignore_changes = [deletion_policy]
  }
}

resource "google_sql_user" "user1" {
  project = var.project_id
  name     = "caredelivery-${random_pet.db_suffix.id}"
  instance = google_sql_database_instance.db1.name
#   host     = "%"
  password = random_password.password.result
}

resource "google_secret_manager_secret" "dbuser_secret" {
  secret_id = google_sql_user.user1.name
  project = var.project_id

  labels = {
    label = "db-user-password"
  }

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "dbuser_secret_version" {
  secret      = google_secret_manager_secret.dbuser_secret.id
  secret_data = random_password.password.result
}

resource "google_secret_manager_secret_iam_member" "dbuser_secret_access" {
  for_each = {
    for index, cps in var.cloudrun_public_services :
    cps.app_name => cps
  }
  secret_id  = google_secret_manager_secret.dbuser_secret.id
  role       = "roles/secretmanager.secretAccessor"
#   member     = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account[each.value.app_name].email}"
  depends_on = [google_secret_manager_secret.dbuser_secret]
}


resource "google_sql_ssl_cert" "client_cert" {
  project = var.project_id
  common_name = google_sql_database_instance.db1.name
  instance    = google_sql_database_instance.db1.name
}


# PRIVATE KEY STORAGE
resource "google_secret_manager_secret" "private_key" {
  project = var.project_id
  secret_id   = "${google_sql_database_instance.db1.name}-key"
  expire_time = google_sql_ssl_cert.client_cert.expiration_time

  labels = {
    label = "db-private-key"
  }

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "private_key_version" {
  secret      = google_secret_manager_secret.private_key.id
  secret_data = google_sql_ssl_cert.client_cert.private_key
}

resource "google_secret_manager_secret_iam_member" "private_key_access" {
  for_each = {
    for index, cps in var.cloudrun_public_services :
    cps.app_name => cps
  }
  secret_id  = google_secret_manager_secret.private_key.id
  role       = "roles/secretmanager.secretAccessor"
#   member     = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account[each.value.app_name].email}"
  depends_on = [google_secret_manager_secret.private_key]
}

# SERVER CA STORAGE
resource "google_secret_manager_secret" "server_ca_cert" {
  project = var.project_id
  secret_id   = "${google_sql_database_instance.db1.name}-ca"
  expire_time = google_sql_ssl_cert.client_cert.expiration_time


  labels = {
    label = "db-server-ca-cert"
  }

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "server_ca_cert_version" {
  secret      = google_secret_manager_secret.server_ca_cert.id
  secret_data = google_sql_ssl_cert.client_cert.server_ca_cert
}

resource "google_secret_manager_secret_iam_member" "server_ca_cert_access" {
  for_each = {
    for index, cps in var.cloudrun_public_services :
    cps.app_name => cps
  }
  secret_id  = google_secret_manager_secret.server_ca_cert.id
  role       = "roles/secretmanager.secretAccessor"
#   member     = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account[each.value.app_name].email}"
  depends_on = [google_secret_manager_secret.server_ca_cert]
}

# CLIENT CERT STORE
resource "google_secret_manager_secret" "client_cert" {
  project = var.project_id
  secret_id   = "${google_sql_database_instance.db1.name}-cert"
  expire_time = google_sql_ssl_cert.client_cert.expiration_time


  labels = {
    label = "db-client-cert"
  }

  replication {
    user_managed {
      replicas {
        location = "us-central1"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "client_cert_version" {
  secret      = google_secret_manager_secret.client_cert.id
  secret_data = google_sql_ssl_cert.client_cert.cert
}

resource "google_secret_manager_secret_iam_member" "client_cert_access" {
  for_each = {
    for index, cps in var.cloudrun_public_services :
    cps.app_name => cps
  }
  secret_id  = google_secret_manager_secret.client_cert.id
  role       = "roles/secretmanager.secretAccessor"
#   member     = "serviceAccount:${google_service_account.cloudrun_service_account.email}"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account[each.value.app_name].email}"
  depends_on = [google_secret_manager_secret.client_cert]
}
---------------

# //////////////////////////////////////////////
# Variables added for creating cloud sql service
# //////////////////////////////////////////////
variable "app_name_db" {
  type = string
  description = "Application name used by your db instance"
}


variable "database_version" {
  type        = string
  default     = "POSTGRES_17"
  description = "type of database"
}

variable "db_tier" {
  type        = string
  default     = "db-f1-micro"
  description = "tier of database"
}

variable "sql_public_ip" {
  type        = bool
  default     = false
  description = "enable public ip on cloud sql"
}

variable "domain" {
  type        = string
  description = "custom domain name"
  default     = "<app_name>.<customer-folder-n>.caf.mccapp.com"
}

variable "enable_ssl" {
  type        = bool
  default     = true
  description = "enable ssl?"
}

variable "int_lb_sts_cidr" {
  type        = string
  description = "IP CIDR space for the internal LB service to service"
  default     = "10.8.132.0/28"
}

variable "int_lb_proxy_cidr" {
  type        = string
  description = "IP CIDR space for the internal LB proxy"
  default     = "10.8.128.0/24"
}

variable "db_availability_type" {
  type        = string
  default     = "ZONAL" # or REGIONAL
  description = "availability type of database"
}

variable "db_primary_zone" {
  type        = string
  default     = "us-central1-f"
  description = "primary region for database"
}

variable "db_secondary_zone" {
  type        = string
  default     = "us-central1-a"
  description = "secondary region for database"
}
---

###### Cloud SQL IAM binding #########
resource "google_project_iam_member" "cr_sa_sql_binding" {
  for_each = {
    for index, cps in var.cloudrun_public_services :
    cps.app_name => cps
  }
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloudrun_service_account[each.value.app_name].email}"
}

------------

######### Cloud SQL changes #########
app_name_db="us-central1-s-cloudsql"
db_tier="db-perf-optimized-N-2"
sql_public_ip = true
