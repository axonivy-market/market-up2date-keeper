#!/bin/bash
#
# Usage: update-dependency.sh [products] <branch> <module> <groupId> <artifactId> <version>
#
# Parameters:
#   products   - (Optional) Single product name, comma-separated list, or empty to use all repos
#   branch     - Branch name (e.g. master, release/12.0)
#   module     - Module name (e.g. idp-connector-demo)
#   groupId    - Group ID of the dependency (e.g. com.axonivy.market)
#   artifactId - Artifact ID of the dependency (e.g. market-core)
#   version    - Version of the dependency (e.g. 1.0.0)
#
# Examples:
#   update-dependency.sh idp-connector master idp-connector-demo com.axonivy.market market-core 1.0.0
#   update-dependency.sh "idp-connector,market-core" master module-name com.axonivy.market market-lib 2.0.0
#   update-dependency.sh "" master module-name com.axonivy.market market-lib 2.0.0  (all repos)
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

if [ $# -lt 4 ]; then
  echo "Usage: $0 [products] <branch> <module> <groupId> <artifactId> [version]"
  echo "Example: $0 'idp-connector,market-core' master module com.axonivy.market lib 2.0.0"
  echo "Example (latest): $0 'idp-connector,market-core' master module com.axonivy.market lib"
  exit 1
fi

products=$1
branch=$2
project=$3
groupId=$4
artifactId=$5
version=$6

# Auto-collect repos if empty
if [ -z "$products" ]; then
  products=$(collectRepos | tr '\n' ',' | sed 's/,$//')
fi

ORG="axonivy-market"
WORK_DIR=$(mktemp -d -t update-dep-XXXXXX)
trap "rm -rf ${WORK_DIR}" EXIT

updateProduct() {
  local product=$1
  local repo_url="git@github.com:${ORG}/${product}.git"
  
  echo "→ ${product}"
  cd "${WORK_DIR}"
  
  if ! git clone -b "${branch}" "${repo_url}" "${product}" 2>/dev/null; then
    echo "  ❌ Clone failed"
    return 1
  fi
  
  cd "${product}"
  
  if [ ! -d "${project}" ]; then
    echo "  ❌ Module not found"
    return 1
  fi
  
  cd "${project}"
  if [ -z "$version" ]; then
    if ! mvn -B versions:use-dep-version \
      -Dincludes="${groupId}:${artifactId}" \
      -DforceVersion=true > /dev/null 2>&1; then
      echo "  ❌ Update failed"
      return 1
    fi
  else
    if ! mvn -B versions:use-dep-version \
      -Dincludes="${groupId}:${artifactId}" \
      -DdepVersion="${version}" \
      -DforceVersion=true > /dev/null 2>&1; then
      echo "  ❌ Update failed"
      return 1
    fi
  fi
  
  cd "${WORK_DIR}/${product}"
  if git diff --quiet; then
    echo "  ℹ No changes"
    return 0
  fi

  git add .
  git commit -m "Update ${groupId}:${artifactId}${version:+ to $version}"
  
  if ! git push origin "HEAD:${branch}" 2>/dev/null; then
    echo "  ❌ Push failed"
    return 1
  fi
  
  echo "  ✓ Updated"
}

echo "Updating: ${groupId}:${artifactId}${version:+ to $version}"
echo "Branch: ${branch} | Module: ${project}"
echo ""

IFS=',' read -ra product_list <<< "$products"
for product in "${product_list[@]}"; do
  product=$(echo "$product" | xargs)
  [ -z "$product" ] && continue
  updateProduct "$product" || true
done