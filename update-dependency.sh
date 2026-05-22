#!/bin/bash
#
# Usage: update-dependency.sh [products] <branch> <module> <groupId> <artifactId> <version>
#
# Parameters:
#   products   - Single product name, comma-separated list, or empty to use all repos
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

if [ $# -lt 6 ]; then
  echo "Usage: $0 [products] <branch> <module> <groupId> <artifactId> [version]"
  echo "Example: $0 'idp-connector,market-core' master module com.axonivy.market lib 2.0.0"
  echo "Example (no version): $0 'idp-connector,market-core' master module com.axonivy.market lib"
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
  
  if [ ! -d "${project}" ]; then
    echo "  ❌ Module not found: ${project}"
    echo "  Available dirs: $(ls -d */ 2>/dev/null | tr '\n' ' ')"
    return 1
  fi
  
  cd "${project}"
  echo "  Running Maven in: $(pwd)"
  if [ -z "$version" ]; then
    echo "  Adding dependency: ${groupId}:${artifactId} (no version tag)"
    # Check if dependency already exists
    if grep -q "<groupId>${groupId}</groupId>" pom.xml && grep -q "<artifactId>${artifactId}</artifactId>" pom.xml; then
      # Exists: remove version tag if present
      sed -i "/<groupId>${groupId}<\/groupId>/,/<\/dependency>/{ /<version>.*<\/version>/d; }" pom.xml
    else
      # Doesn't exist: add new dependency block without version
      sed -i "/<\/dependencies>/i\\    <dependency>\\n      <groupId>${groupId}</groupId>\\n      <artifactId>${artifactId}</artifactId>\\n    </dependency>" pom.xml
    fi
  else
    echo "  Updating to: ${groupId}:${artifactId}:${version}"
    if ! grep -q "<artifactId>${artifactId}</artifactId>" pom.xml; then
      # Dependency does not exist yet — add it directly with version via sed
      echo "  Dependency not in pom.xml yet, adding new block..."
      sed -i "/<\/dependencies>/i\\    <dependency>\\n      <groupId>${groupId}</groupId>\\n      <artifactId>${artifactId}</artifactId>\\n      <version>${version}</version>\\n    </dependency>" pom.xml
    else
      # Dependency exists — use Maven to update the version
      mvn -B versions:use-dep-version \
        -Dincludes="${groupId}:${artifactId}" \
        -DdepVersion="${version}" \
        -DforceVersion=true
      if [ $? -ne 0 ]; then
        echo "  ❌ Update failed"
        return 1
      fi
    fi
  fi
  
  cd "${WORK_DIR}/${product}"
  echo "  Checking for changes in: $(pwd)"
  if git diff --quiet; then
    echo "  ℹ No changes detected"
    git status --short
    return 0
  fi
  
  echo "  Found changes:"
  git diff --name-only
  echo "  Staging and committing..."

  git add .
  git commit -m "Add ${groupId}:${artifactId}${version:+ version $version}"
  echo "  Commit: $(git log -1 --oneline)"
  
  if ! git push origin "HEAD:${branch}" 2>/dev/null; then
    echo "  ❌ Push failed"
    return 1
  fi
  
  echo "  ✓ Added and pushed"
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