variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
}

variable "repository_name" {
  description = "Name of the repository that holds the action."
  type        = string
}

variable "repository_description" {
  description = "Short description shown on the repository page."
  type        = string
}

variable "repository_visibility" {
  description = "public or private. A workflow in another repository can only use the action if this one is public."
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.repository_visibility)
    error_message = "repository_visibility must be public or private."
  }
}

variable "repository_topics" {
  description = "Topics shown on the repository page."
  type        = set(string)
  default     = []
}

variable "tag_prefix" {
  description = "Text before the version in a release tag (v -> v1.2.3). The workflow reads it and the tag ruleset protects it."
  type        = string
  default     = "v"

  validation {
    condition     = length(var.tag_prefix) > 0
    error_message = "tag_prefix cannot be empty: GitHub does not store empty Actions variables."
  }
}

variable "initial_version" {
  description = "Version to start from while the repository has no release tag."
  type        = string
  default     = "0.0.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.initial_version))
    error_message = "initial_version must be MAJOR.MINOR.PATCH, for example 0.0.0."
  }
}
