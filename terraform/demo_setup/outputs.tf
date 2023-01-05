output "boundary_worker_ip_public" {
  description = "The public IP of the Boundary worker."
  value = aws_instance.boundary_worker.public_ip
}

output "boundary_worker_dns_public" {
  description = "The public DNS of the Boundary worker."
  value = aws_instance.boundary_worker.public_dns
}
