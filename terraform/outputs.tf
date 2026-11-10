output "repository_url" {
  description = "URL of the repository."
  value       = github_repository.this.html_url
}

output "action_reference" {
  description = "What another workflow writes after 'uses:' (add @<tag>)."
  value       = github_repository.this.full_name
}

output "protected_tag_pattern" {
  description = "Tags that cannot be moved or deleted."
  value       = "${var.tag_prefix}*"
}
