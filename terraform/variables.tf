variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "machine_type" {
  type    = string
  default = "e2-standard-2"
}

variable "boot_disk_gb" {
  type    = number
  default = 50
}

variable "image_name" {
  type    = string
  default = "windows-server-2025-dc-v20250913"
}

variable "image_project" {
  type    = string
  default = "windows-cloud"
}
