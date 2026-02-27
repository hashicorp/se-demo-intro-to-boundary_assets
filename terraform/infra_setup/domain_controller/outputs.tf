output "dns" {
  description = "The DNS name of the Kubernetes server."
  value       = var.create_domain_controller == true ? aws_instance.domain_controller[0].private_dns : ""
}

output "ip_private" {
  description = "The private IP of the Kubernetes cluster server."
  value       = var.create_domain_controller == true ? aws_instance.domain_controller[0].private_ip : ""
}