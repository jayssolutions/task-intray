output "public_ip" {
  value = aws_instance.prometheus.public_ip
}

output "private_ip" {
  value = aws_instance.prometheus.private_ip
}

output "security_group_id" {
  value = aws_security_group.prometheus.id
}
