variable "pm_api_url" {
  type = string
}
variable "pm_api_token_id" {
  type = string
}
variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}
variable "cloudinit_template_name" {
  type = string
}
variable "proxmox_node" {
  type = string
}
variable "ssh_key" {
  type      = string
  sensitive = true
}
variable "master_count" {
  type = number
}
variable "worker_count" {
  type = number
}
variable "storage_size" {
  type = number
}
variable "storage" {
  type = string
}
variable "bridge" {
  type = string
}
