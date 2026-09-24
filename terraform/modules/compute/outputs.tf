output "instance_public_ips" {
  description = "Public IP addresses of application instances"
  value       = aws_instance.app[*].public_ip
}

output "key_name" {
  description = "EC2 key pair name, shared with the monitoring host"
  value       = aws_key_pair.node_app.key_name
}
