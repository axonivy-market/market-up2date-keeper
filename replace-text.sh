#!/bin/bash
#
# Usage: replace-text.sh [products] <branch> <oldText>|<newText> [<oldText>|<newText> ...]
#
# Parameters:
#   products      - (Optional) Single product name, comma-separated list, or empty to use all repos
#   branch        - Branch name (e.g. master, release/12.0)
#   oldText|newText
#                 - Replacement pair. May be repeated for multiple replacements.
#                   (e.g. org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils)
#   FILE_NAME_PATTERN - POSIX extended regex passed directly to find -regex (e.g. .*\.(java|xml)$). Defaults to .*\.java$.
#
# Examples:
#   replace-text.sh alfresco-connector master \
#       "org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils"
#
#   replace-text.sh "" master \
#       "org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils" \
#       "javax.ws.rs|jakarta.ws.rs"
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

printUsage() {
  echo "Usage: FILE_NAME_PATTERN='.*\\.(java|xml)$' $0 [products] <branch> <oldText>|<newText> [<oldText>|<newText> ...]"
  echo "Example: $0 'alfresco-connector' master 'org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils'"
  echo "Example (all repos): $0 '' master 'org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils' 'javax.ws.rs|jakarta.ws.rs'"
}

if [ $# -lt 3 ]; then
  printUsage
  exit 1
fi

products=$1
branch=$2
shift 2

if [ -z "${branch}" ] || ! git check-ref-format --branch "${branch}" >/dev/null 2>&1; then
  echo "Invalid branch name: ${branch}"
  exit 1
fi

if [ -n "${products}" ]; then
  IFS=',' read -ra requested_products <<< "${products}"
  for requested_product in "${requested_products[@]}"; do
    requested_product=$(echo "${requested_product}" | xargs)
    if [[ ! "${requested_product}" =~ ^[A-Za-z0-9._-]+$ ]]; then
      echo "Invalid product name: ${requested_product}"
      exit 1
    fi
  done
fi

fileNamePattern=${FILE_NAME_PATTERN:-'.*\.java$'}
commitMessage=${COMMIT_MESSAGE:-}
replacements=()
sedExpressions=()

addReplacement() {
  local replacement=$1
  local oldText=${replacement%%|*}
  local newText=${replacement#*|}

  if [ "${replacement}" = "${oldText}" ] || [ -z "${oldText}" ]; then
    echo "Invalid replacement '${replacement}'. Expected <oldText>|<newText>."
    exit 1
  fi

  replacements+=("${oldText} -> ${newText}")
  sedExpressions+=("-e" "s|${oldText}|${newText}|g")
}

while [ $# -gt 0 ]; do
  addReplacement "$1"
  shift
done

if [ "${#replacements[@]}" -eq 0 ]; then
  printUsage
  exit 1
fi

# Auto-collect repos if empty
if [ -z "$products" ]; then
  products=$(collectRepos | tr '\n' ',' | sed 's/,$//')
fi

ORG="axonivy-market"
prBranch=${PR_BRANCH:-"replace-text/$(date -u +%Y%m%d%H%M%S)-${GITHUB_RUN_ID:-$$}"}
WORK_DIR=$(mktemp -d -t replace-text-XXXXXX)
trap "rm -rf ${WORK_DIR}" EXIT

replaceInProduct() {
  local product=$1
  local repo_url="https://github.com/${ORG}/${product}.git"

  echo "→ ${product}"
  echo "  URL: ${repo_url}"
  echo "  Branch: ${branch}"
  cd "${WORK_DIR}"

  if ! git clone -b "${branch}" "${repo_url}" "${product}" 2>/dev/null; then
    echo "  ❌ Clone failed"
    return 1
  fi

  cd "${product}"
  echo "  Cloned to: $(pwd)"

  local file_count
  file_count=$(find . -regextype posix-extended -type f ! -path './.git/*' -regex "${fileNamePattern}" 2>/dev/null | wc -l)
  if [ "${file_count}" -eq 0 ]; then
    echo "  ℹ No matching files found in $(pwd) — skipping"
    return 0
  fi

  echo "  Replacing ${#replacements[@]} text pair(s)..."
  find . -regextype posix-extended -type f ! -path './.git/*' -regex "${fileNamePattern}" -exec sed -i "${sedExpressions[@]}" {} +

  echo "  Checking for changes in: $(pwd)"
  if git diff --quiet; then
    echo "  ℹ No changes detected after replacement"
    return 0
  fi

  echo "  Changed files:"
  git diff --name-only

  local effectiveCommitMessage=${commitMessage:-"Replace text in selected files"}
  if ! git switch -c "${prBranch}"; then
    echo "  ❌ Branch creation failed"
    return 1
  fi
  git add .
  git commit -m "${effectiveCommitMessage}"
  echo "  Commit: $(git log -1 --oneline)"

  if ! git push origin "HEAD:${prBranch}" 2>/dev/null; then
    echo "  ❌ Push failed"
    return 1
  fi

  if ! gh pr create \
    --repo "${ORG}/${product}" \
    --base "${branch}" \
    --head "${prBranch}" \
    --assignee "${GITHUB_ACTOR}" \
    --title "${effectiveCommitMessage}" \
    --body "Text replacement for ${product}."; then
    echo "  ❌ Pull request creation failed"
    return 1
  fi

  echo "  ✓ Replaced, pushed ${prBranch}, and created pull request"
}

echo "Replacements:"
for replacement in "${replacements[@]}"; do
  echo "  ${replacement}"
done
echo "Branch:    ${branch}"
echo ""

IFS=',' read -ra product_list <<< "$products"
failed_products=()
for product in "${product_list[@]}"; do
  product=$(echo "$product" | xargs)
  [ -z "$product" ] && continue
  if ! replaceInProduct "$product"; then
    failed_products+=("${product}")
  fi
done

if [ "${#failed_products[@]}" -gt 0 ]; then
  echo "❌ Failed products: ${failed_products[*]}"
  exit 1
fi
