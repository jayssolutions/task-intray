variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "task-intray"
}

variable "vpc_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "instance_count" {
  description = "Number of application EC2 instances"
  type        = number
  default     = 2
}

variable "admin_cidr" {
  description = "CIDR allowed to SSH for Ansible"
  type        = string
  default     = "127.0.0.1/32"
}

variable "enable_monitoring" {
  description = "Create a Prometheus EC2 instance that scrapes the app instances"
  type        = bool
  default     = true
}

variable "prometheus_instance_type" {
  type    = string
  default = "t3.small"
}

variable "monitoring_cidrs" {
  description = "Extra CIDRs (e.g. an external Prometheus) allowed to scrape the app on port 3000"
  type        = list(string)
  default     = []
}

variable "public_key" {
  description = "SSH public key content"
  type        = string
  sensitive   = true
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
