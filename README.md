# This Terraform configuration creates a Google Artifact Registry repository with a virtual repository configuration.
artifact-repositories.tf

resource "google_artifact_registry_repository" "virtual_artifact_repository" {
    location        = "us-central1"
    project         = var.project_id
    repository_id   = "${var.virtual_repository_id}"
    description     = "Virtual Docker repository"
    format          = "DOCKER"
    mode            = "VIRTUAL_REPOSITORY"
    virtual_repository_config {
      upstream_policies {
        id = "gcf-artifacts"
        repository = "projects/${var.upstream_project_name}/locations/us-central1/repositories/${var.upstream_repository_name}"
        priority   = 20
      }
    }
}
sa.tf

----------
# Grant ARTIFACT_REGISTRY_READER role to the service account
# This is required for the service account to access the artifact registry
# https://cloud.google.com/artifact-registry/docs/access-control#service-account

resource "google_project_iam_member" "artifact_registry_reader_binding" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${var.test_env_ar_service_account}"
}
-----------------
/vars/test.tfvars

variable "upstream_project_name" {
  type        = string
  default     = ""
  description = "upstream project name"
}

variable "upstream_repository_name" {
  type        = string
  default     = ""
  description = "upstream repository name"
}

variable "virtual_repository_id" {
  type        = string
  default     = ""
  description = "virtual repository id"
}

variable "test_env_ar_service_account" {
  type        = string
  default     = ""
  description = "service account that gets AR reader access"
}

variable "upstream_project_name2" {
  type        = string
  default     = ""
  description = "upstream project name"
}

variable "upstream_repository_name2" {
  type        = string
  default     = ""
  description = "upstream repository name"
}

variable "virtual_repository_id2" {
  type        = string
  default     = ""
  description = "virtual repository id"
}
-----------------
vars/test.tfvars

######### Virtual repositories config parameters #########
upstream_project_name = "projecttemplate-d" # This is the name of the upstream project
upstream_repository_name = "gcf-artifacts" # This is the name of the upstream repository
virtual_repository_id= "virtual-to-dev-gcf-artifacts" # This is the name of the virtual repository
## upstream_repository_url = "https://artifactregistry.googleapis.com/v1/projects/${upstream_project_name}/locations/us-central1/repositories/${upstream_repository_name}" # This is the URL of the upstream repository
## upstream_repository_id = "projects/${upstream_project_name}/locations/us-central1/repositories/${upstream_repository_name}" # This is the ID of the upstream repository
##### virtual repository -2  config parameters #####
upstream_project_name2 = "projecttemplate-d" # This is the name of the upstream project
upstream_repository_name2 = "artifact-repository" # This is the name of the upstream repository
virtual_repository_id2= "vr-dev-artifact-repository" # This is the name of the virtual repository
