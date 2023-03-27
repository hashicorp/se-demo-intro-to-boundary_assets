output "boundary_worker_ip_public" {
  description = "The public IP of the Boundary worker."
  value = aws_instance.boundary_worker.public_ip
}

output "boundary_worker_dns_public" {
  description = "The public DNS of the Boundary worker."
  value = aws_instance.boundary_worker.public_dns
}

output "aws_ssh_keypair_boundary_infra" {
  description = "The name of the Boundary worker AWS SSH keypair."
  value = aws_key_pair.boundary_infra.key_name
}

output "boundary_infra_ssh_privkey" {
  description = "The raw content of the Boundary worker SSH private key."
  value = tls_private_key.boundary_instance_worker_ssh_key.private_key_openssh
}