terraform {
  required_version = ">= 1.9"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# The token is read from the GITHUB_TOKEN environment variable, never from a file.
provider "github" {
  owner = var.github_owner
}
