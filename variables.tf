variable "credentials_file" {
  description = "Path to the GCP service account key JSON file"
  type        = string
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name of the VM instance"
  type        = string
  default     = "my-vm-instance"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-micro"
}
