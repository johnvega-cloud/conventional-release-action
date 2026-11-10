resource "github_repository" "this" {
  name        = var.repository_name
  description = var.repository_description
  visibility  = var.repository_visibility
  topics      = var.repository_topics
}

# The release workflow reads these as vars.TAG_PREFIX and vars.INITIAL_VERSION,
# so the values live in one place (the Terraform variables) and not in the YAML.
resource "github_actions_variable" "release" {
  for_each = {
    TAG_PREFIX      = var.tag_prefix
    INITIAL_VERSION = var.initial_version
  }

  repository    = github_repository.this.name
  variable_name = each.key
  value         = each.value
}

# A release tag is created once and then never moved or deleted.
# Creating tags stays allowed, otherwise the action could not release.
resource "github_repository_ruleset" "release_tags" {
  name        = "release-tags"
  repository  = github_repository.this.name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/${var.tag_prefix}*"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    update           = true
    non_fast_forward = true
  }
}
