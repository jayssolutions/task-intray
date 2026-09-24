output "application_url" {
  value = "http://${module.alb.alb_dns_name}"
}

output "instance_public_ips" {
  value = module.compute.instance_public_ips
}

output "prometheus_url" {
  description = "Prometheus UI (reachable from admin_cidr only)"
  value       = var.enable_monitoring ? "http://${module.monitoring[0].public_ip}:9090" : null
}

output "monitoring_public_ip" {
  value = var.enable_monitoring ? module.monitoring[0].public_ip : null
}
