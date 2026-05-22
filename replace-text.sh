#!/bin/bash
#
# Usage: replace-text.sh [products] <branch> <oldText> <newText> [fileExtension]
#
# Parameters:
#   products      - (Optional) Single product name, comma-separated list, or empty to use all repos
#   branch        - Branch name (e.g. master, release/12.0)
#   oldText       - Text/string to replace in matched source files
#                   (e.g. org.apache.commons.lang.StringUtils)
#   newText       - Replacement text/string
#                   (e.g. org.apache.commons.lang3.StringUtils)
#   fileExtension - (Optional) File extension to search/replace (e.g. java, xml, classpath). Default: java
#
# Examples:
#   replace-text.sh alfresco-connector master \
#       "org.apache.commons.lang.StringUtils" \
#       "org.apache.commons.lang3.StringUtils"
#
#   replace-text.sh "" master \
#       "org.apache.commons.lang.StringUtils" \
#       "org.apache.commons.lang3.StringUtils"
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

if [ $# -lt 5 ]; then
  echo "Usage: $0 [products] <branch> <oldText> <newText> [fileExtension] "
  echo "Example: $0 'alfresco-connector' master 'org.apache.commons.lang.StringUtils' 'org.apache.commons.lang3.StringUtils'"
  echo "Example (all repos): $0 '' master 'org.apache.commons.lang.StringUtils' 'org.apache.commons.lang3.StringUtils'"
  exit 1
fi

products=$1
branch=$2
oldText=$3
newText=$4
fileExtension=${5:-java}

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

  # Count files containing the old text before replacement
  local match_count
  match_count=$(grep -rl --include="*.${fileExtension}" "${oldText}" . 2>/dev/null | wc -l)

  if [ "${match_count}" -eq 0 ]; then
    echo "  ℹ No occurrences of '${oldText}' found — skipping"
    return 0
  fi

  echo "  Found '${oldText}' in ${match_count} file(s) — replacing..."

  # Replace all occurrences in matched file type
  find . -name "*.${fileExtension}" -exec sed -i "s|${oldText}|${newText}|g" {} +

  echo "  Checking for changes in: $(pwd)"
  if git diff --quiet; then
    echo "  ℹ No changes detected after replacement"
    return 0
  fi

  echo "  Changed files:"
  git diff --name-only

  git add .
  git commit -m "Replace text: ${oldText} -> ${newText}"
  echo "  Commit: $(git log -1 --oneline)"

  if ! git push origin "HEAD:${branch}" 2>/dev/null; then
    echo "  ❌ Push failed"
    return 1
  fi

  echo "  ✓ Replaced and pushed"
}

echo "Replacing: '${oldText}'"
echo "With:      '${newText}'"
echo "Branch:    ${branch}"
echo ""

IFS=',' read -ra product_list <<< "$products"
for product in "${product_list[@]}"; do
  product=$(echo "$product" | xargs)
  [ -z "$product" ] && continue
  replaceInProduct "$product" || true
done
