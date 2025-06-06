project_id                = "apigee-test-0002-demo"
virtual_repository_id     = "virtual-to-dev-artifact-repository"

upstream_project_names    = "apigee-test-0002-demo"
upstream_repository_names = "client-dev-artifact-reporsitory"

service_account_name        = "dev-ar-reader"
service_account_display_name = "Dev Artifact Registry Reader"

upstream_policy = "dev-upstream-policy"

-----

variable "project_id" {
  description = "GCP project where the virtual repository and service account will be created"
  type        = string
  default = "apigee-test-0002-demo"
}

variable "location" {
  description = "GCP project location"
  type        = string
  default     = "us-central1"
}

variable "virtual_repository_id" {
  description = "ID for the virtual Docker repository"
  type        = string
}

variable "upstream_project_names" {
  description = "List of upstream project names"
  type        = string
}

variable "upstream_repository_names" {
  description = "List of upstream repository names"
  type        = string
}

variable "service_account_name" {
  description = "Service account ID to be created (without domain)"
  type        = string
}

variable "service_account_display_name" {
  description = "Display name for the service account"
  type        = string
}
variable "upstream_policy" {
  type        = string
  description = "ID of the upstream policy"
}
-----

resource "google_artifact_registry_repository" "upstream_repository" {
  project       = var.upstream_project_names
  location      = var.location
  repository_id = var.upstream_repository_names
  format        = "DOCKER"
  description   = "Upstream Docker repository"
}

resource "google_artifact_registry_repository" "virtual_artifact_repository" {
  project       = var.project_id
  location      = var.location
  repository_id = var.virtual_repository_id
  description   = "Virtual Docker repository"
  format        = "DOCKER"
  mode          = "VIRTUAL_REPOSITORY"

  labels = {
    goog-terraform-provisioned = "true"
  }

  virtual_repository_config {
    upstream_policies {
      id         = "${var.upstream_policy}"
      repository = "projects/${var.upstream_project_names}/locations/${var.location}/repositories/${var.upstream_repository_names}"
      priority   = 20
    }
  }

  depends_on = [google_artifact_registry_repository.upstream_repository]
}

----

resource "google_service_account" "ar_service_account" {
  project      = var.project_id
  account_id   = var.service_account_name
  display_name = var.service_account_display_name
}

resource "google_project_iam_member" "artifact_registry_reader_binding" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.ar_service_account.email}"
}
