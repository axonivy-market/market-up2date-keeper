#!/bin/bash
#
# Usage: replace-text.sh [products] <branch> <oldText>|<newText> [<oldText>|<newText> ...] [fileExtension]
#
# Parameters:
#   products      - (Optional) Single product name, comma-separated list, or empty to use all repos
#   branch        - Branch name (e.g. master, release/12.0)
#   oldText|newText
#                 - Replacement pair. May be repeated for multiple replacements.
#                   (e.g. org.apache.commons.lang.StringUtils|org.apache.commons.lang3.StringUtils)
#   fileExtension - (Optional) File extension to search/replace (e.g. java, xml, classpath). Default: java
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
  echo "Usage: $0 [products] <branch> <oldText>|<newText> [<oldText>|<newText> ...] [fileExtension]"
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

fileExtension=java
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
  if [[ "$1" == *"|"* ]]; then
    addReplacement "$1"
  elif [ $# -eq 1 ]; then
    fileExtension=$1
  else
    echo "Invalid replacement '${1}'. Expected <oldText>|<newText>."
    exit 1
  fi
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

  # Check if any files with the extension exist
  local file_count
  file_count=$(find . -name "*.${fileExtension}" 2>/dev/null | wc -l)
  if [ "${file_count}" -eq 0 ]; then
    echo "  ℹ No *.${fileExtension} files found in $(pwd) — skipping"
    return 0
  fi

  echo "  Replacing ${#replacements[@]} text pair(s)..."
  find . -name "*.${fileExtension}" -exec sed -i "${sedExpressions[@]}" {} +

  echo "  Checking for changes in: $(pwd)"
  if git diff --quiet; then
    echo "  ℹ No changes detected after replacement"
    return 0
  fi

  echo "  Changed files:"
  git diff --name-only

  git add .
  git commit -m "Replace text in *.${fileExtension} files"
  echo "  Commit: $(git log -1 --oneline)"

  if ! git push origin "HEAD:${branch}" 2>/dev/null; then
    echo "  ❌ Push failed"
    return 1
  fi

  echo "  ✓ Replaced and pushed"
}

echo "Replacements:"
for replacement in "${replacements[@]}"; do
  echo "  ${replacement}"
done
echo "Branch:    ${branch}"
echo ""

IFS=',' read -ra product_list <<< "$products"
for product in "${product_list[@]}"; do
  product=$(echo "$product" | xargs)
  [ -z "$product" ] && continue
  replaceInProduct "$product" || true
done
