output "registry_id" {
  description = "The account ID of the registry holding the repository."
  value       = aws_ecr_repository.app.registry_id
}

output "repository_uri" {
  description = "The URI of the repository."
  value       = aws_ecr_repository.app.repository_url
}

