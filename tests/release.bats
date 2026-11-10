#!/usr/bin/env bats
# Each test builds a throwaway Git repository with a local bare "origin".

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../release.sh"
  WORK="$(mktemp -d)"

  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
  export TAG_PREFIX=v INITIAL_VERSION=0.0.0
  export GITHUB_OUTPUT="${WORK}/output" RUNNER_TEMP="${WORK}"

  git init -q --bare "${WORK}/origin.git"
  git init -q -b main "${WORK}/repo"
  cd "${WORK}/repo"
  git remote add origin "${WORK}/origin.git"
  commit "chore: first commit"
}

teardown() {
  rm -rf "${WORK}"
}

commit() { # commit <subject> [body]
  git commit -q --allow-empty -m "$1" ${2:+-m "$2"}
}

output_has() {
  grep -qx "$1" "${GITHUB_OUTPUT}"
}

@test "fix bumps the patch version" {
  commit "fix: handle empty input"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "tag=v0.0.1"
}

@test "feat bumps the minor version" {
  commit "fix: handle empty input"
  commit "feat: add login"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "tag=v0.1.0"
}

@test "a bang bumps the major version" {
  commit "feat!: drop the v1 API"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "tag=v1.0.0"
}

@test "a BREAKING CHANGE footer bumps the major version" {
  commit "fix: rename the flag" "BREAKING CHANGE: --old is now --new"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "version=1.0.0"
}

@test "the next version starts from the last tag" {
  git tag v1.4.2
  commit "feat(api): add pagination"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "tag=v1.5.0"
}

@test "commits that are not feat or fix release nothing" {
  commit "docs: fix a typo"
  commit "not a conventional commit"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "released=false"
  [ -z "$(git tag)" ]
}

@test "running twice does not create a second tag" {
  commit "feat: add login"
  bash "${SCRIPT}"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  [ "$(git tag | wc -l)" -eq 1 ]
}

@test "the tag is pushed to origin with the changelog as its message" {
  commit "feat(api): add pagination"
  commit "fix: handle empty input"
  bash "${SCRIPT}"
  git ls-remote --tags origin | grep -q "refs/tags/v0.1.0"
  message="$(git tag -l --format='%(contents)' v0.1.0)"
  [[ "${message}" == *"## v0.1.0"* ]]
  [[ "${message}" == *"### Features"* ]]
  [[ "${message}" == *"- **api:** add pagination"* ]]
  [[ "${message}" == *"### Bug fixes"* ]]
}

@test "the prefix and the initial version are configurable" {
  export TAG_PREFIX="release-" INITIAL_VERSION="2.0.0"
  commit "fix: handle empty input"
  run bash "${SCRIPT}"
  [ "${status}" -eq 0 ]
  output_has "tag=release-2.0.1"
}

@test "an initial version that is not semver fails" {
  export INITIAL_VERSION="1.0"
  commit "fix: handle empty input"
  run bash "${SCRIPT}"
  [ "${status}" -eq 1 ]
  [[ "${output}" == *"not a MAJOR.MINOR.PATCH version"* ]]
}
