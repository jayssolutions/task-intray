variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "key_name" { type = string }
variable "admin_cidr" { type = string }
variable "instance_type" { type = string }

variable "volume_size" {
  description = "Root volume size in GiB (holds the Prometheus TSDB)"
  type        = number
  default     = 20
}
