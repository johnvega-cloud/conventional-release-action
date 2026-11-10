#!/usr/bin/env bash
# Reads the conventional commits since the last release tag, works out the next
# semantic version, writes the changelog for it and pushes an annotated Git tag.
#
# Configuration comes from the environment (set by action.yml):
#   TAG_PREFIX       text before the version in a tag, e.g. "v" -> v1.2.3
#   INITIAL_VERSION  version to start from when the repository has no release tag
set -euo pipefail

: "${TAG_PREFIX?TAG_PREFIX is not set}"
: "${INITIAL_VERSION:?INITIAL_VERSION is not set or empty}"

output_file="${GITHUB_OUTPUT:-/dev/stdout}"
notes_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"

semver_re='^([0-9]+)\.([0-9]+)\.([0-9]+)$'
# type(scope)!: description   -> scope and "!" are optional
commit_re='^([a-z]+)(\(([^)]+)\))?(!)?: (.+)$'
breaking_re='BREAKING[ -]CHANGE: '

die() {
  echo "error: $*" >&2
  exit 1
}

# A shallow clone (the checkout default) has no tags and one commit: the version
# would be computed from the wrong starting point, so stop instead.
if [[ "$(git rev-parse --is-shallow-repository)" == "true" ]]; then
  die "the clone is shallow: use actions/checkout with fetch-depth: 0"
fi

# 1. Where are we? The last release tag reachable from HEAD, or the initial version.
last_tag="$(git describe --tags --abbrev=0 --match "${TAG_PREFIX}[0-9]*" 2>/dev/null || true)"
if [[ -n "$last_tag" ]]; then
  current="${last_tag#"$TAG_PREFIX"}"
  range="${last_tag}..HEAD"
else
  current="$INITIAL_VERSION"
  range="HEAD"
fi

[[ "$current" =~ $semver_re ]] || die "'$current' is not a MAJOR.MINOR.PATCH version"
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

# 2. Read the commits. The biggest change wins: 3 = major, 2 = minor, 1 = patch.
bump=0
breaking=""
features=""
fixes=""

# Fields are split by the unit separator (1f) and commits by the record separator (1e),
# so a multi-line commit body cannot break the parsing.
while IFS= read -r -d $'\x1e' record; do
  record="${record#$'\n'}"
  sha="${record%%$'\x1f'*}"
  rest="${record#*$'\x1f'}"
  subject="${rest%%$'\x1f'*}"
  body="${rest#*$'\x1f'}"

  [[ "$subject" =~ $commit_re ]] || continue
  type="${BASH_REMATCH[1]}"
  scope="${BASH_REMATCH[3]}"
  bang="${BASH_REMATCH[4]}"
  line="- ${scope:+**${scope}:** }${BASH_REMATCH[5]} (${sha:0:7})"

  if [[ -n "$bang" || "$body" =~ $breaking_re ]]; then
    level=3
    breaking+="${line}"$'\n'
  elif [[ "$type" == "feat" ]]; then
    level=2
    features+="${line}"$'\n'
  elif [[ "$type" == "fix" ]]; then
    level=1
    fixes+="${line}"$'\n'
  else
    continue # docs, chore, ci, test... do not release anything
  fi

  if ((level > bump)); then
    bump=$level
  fi
done < <(git log --format='%H%x1f%s%x1f%b%x1e' "$range" 2>/dev/null)

if ((bump == 0)); then
  echo "No feat, fix or breaking commits since ${last_tag:-the first commit}: nothing to release."
  echo "released=false" >>"$output_file"
  exit 0
fi

# 3. Next version.
case "$bump" in
  3) next="$((major + 1)).0.0" ;;
  2) next="${major}.$((minor + 1)).0" ;;
  1) next="${major}.${minor}.$((patch + 1))" ;;
esac
tag="${TAG_PREFIX}${next}"

# 4. Changelog for this version.
notes="${notes_dir}/changelog-${tag}.md"

section() { # section <title> <lines>
  if [[ -n "$2" ]]; then
    printf '\n### %s\n\n%s' "$1" "$2"
  fi
}

{
  echo "## ${tag} ($(date -u +%Y-%m-%d))"
  section "Breaking changes" "$breaking"
  section "Features" "$features"
  section "Bug fixes" "$fixes"
} >"$notes"

# 5. Tag and push. The changelog is the tag message, so it lives in Git itself.
# --cleanup=whitespace keeps the "#" heading lines (the default would drop them).
git tag --annotate "$tag" --file "$notes" --cleanup=whitespace
git push origin "refs/tags/${tag}"

echo "Released ${tag} (was ${last_tag:-none})"
{
  echo "released=true"
  echo "version=${next}"
  echo "tag=${tag}"
  echo "changelog-file=${notes}"
} >>"$output_file"
