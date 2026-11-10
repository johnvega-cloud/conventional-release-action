# Build guide

What is built first and why.

## Order

1. **`release.sh` and its tests.** The logic (commits → version → changelog →
   tag) is plain Bash and Git, so it is written and tested locally before any
   GitHub piece exists.
2. **`action.yml`.** A thin wrapper: it declares inputs and outputs and passes
   the inputs to the script as environment variables.
3. **`terraform/`.** Creates the repository, the two Actions variables and the
   tag ruleset. It goes before the first push because the workflow reads the
   variables on its first run.
4. **Workflows.** `ci.yml` checks the script and the Terraform code;
   `release.yml` uses the action on the default branch.

## Design decisions

- **Composite action, not a JavaScript or Docker action.** No build step and no
  image to pull; the runner already has Bash and Git.
- **The changelog is the tag message.** The version history lives in Git itself
  and the action never has to push a commit to a protected branch.
- **Inputs reach the script through `env`.** An input is never pasted into the
  script text, so its content cannot run as a command.
- **No value is written twice.** The tag prefix is one Terraform variable; it
  becomes the `TAG_PREFIX` Actions variable (read by the workflow) and the
  pattern of the tag ruleset. The default branch name comes from
  `github.event.repository.default_branch`.

## Provision

Requirements: Terraform >= 1.9 and a GitHub token that can create repositories.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then edit the values
export GITHUB_TOKEN="$(gh auth token)"
terraform init
terraform plan
terraform apply
```

Then push the code to the new repository. The first push to the default branch
runs `release.yml`.

## Check that it works

```bash
git commit --allow-empty -m "feat: first feature" && git push
gh run watch                 # release workflow
git fetch --tags && git tag  # v0.1.0
gh release view v0.1.0       # the changelog
git push --delete origin v0.1.0   # rejected by the tag ruleset
```

## Tear down

```bash
cd terraform
terraform destroy   # deletes the repository
```
