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
#   version    - Version of the dependency (e.g. 1.0.0); leave blank to remove <version> element, which allows Maven to use the version from parent pom or dependencyManagement
#   scope      - Dependency scope (e.g. compile, test, runtime); leave blank to omit <scope>, which Maven treats as compile
#
# Examples:
#   update-dependency.sh idp-connector master idp-connector-demo com.axonivy.market market-core 1.0.0 provided
#   update-dependency.sh "idp-connector,market-core" master module-name com.axonivy.market market-lib 2.0.0 runtime
#   update-dependency.sh "" master module-name com.axonivy.market market-lib 2.0.0  (all repos)
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

if [ $# -lt 7 ]; then
  echo "Usage: $0 [products] <branch> <module> <groupId> <artifactId> [version] [scope]"
  echo "Example: $0 'idp-connector,market-core' master module com.axonivy.market lib 2.0.0 provided"
  echo "Example (no version, no scope): $0 'idp-connector,market-core' master module com.axonivy.market lib '' ''"
  exit 1
fi

products=$1
branch=$2
project=$3
groupId=$4
artifactId=$5
version=$6
scope=$7

# Auto-collect repos if empty
if [ -z "$products" ]; then
  products=$(collectRepos | tr '\n' ',' | sed 's/,$//')
fi

ORG="axonivy-market"
WORK_DIR=$(mktemp -d -t update-dep-XXXXXX)
trap "rm -rf ${WORK_DIR}" EXIT

# Remove <version> element from a matching dependency in pom.xml
deleteVersionIfPresent() {
  local groupId="$1"; local artifactId="$2"
  if command -v xmlstarlet >/dev/null 2>&1; then
    xmlstarlet ed -P -L -d "/project/dependencies/dependency[groupId='${groupId}' and artifactId='${artifactId}']/version" pom.xml
  else
    perl -0777 -pe 's{(<dependency>.*?<groupId>'"${groupId}"'</groupId>.*?<artifactId>'"${artifactId}"'</artifactId>.*?)(<version>.*?</version>[ \t\r\n]*)}{\1}gs' -i pom.xml
  fi
}

updateVersionWithMaven() {
  local groupId="$1"; local artifactId="$2"; local version="$3"
  mvn -B versions:use-dep-version -DgenerateBackupPoms=false  -Dincludes="${groupId}:${artifactId}" \
    -DdepVersion="${version}" -DforceVersion=true
}

# Return 0 if a dependency with given groupId+artifactId exists inside <dependencies> in pom.xml
dependencyExists() {
  local groupId="$1"; local artifactId="$2"
  if command -v xmlstarlet >/dev/null 2>&1; then
    local cnt
    cnt=$(xmlstarlet sel -t -v "count(/project/dependencies/dependency[groupId='${groupId}' and artifactId='${artifactId}'])" pom.xml 2>/dev/null || echo 0)
    if [ "${cnt}" -gt 0 ]; then
      return 0
    else
      return 1
    fi
  else
    # Fallback: check with perl for a <dependency> block inside <dependencies>
    perl -0777 -ne 'exit 0 if /<dependencies>.*?<dependency>.*?<groupId>\Q'"${groupId}"'\E<\/groupId>.*?<artifactId>\Q'"${artifactId}"'\E<\/artifactId>.*?<\/dependency>/s; exit 1' pom.xml
  fi
}

insertDependencyBlock() {
  local groupId="$1"; local artifactId="$2"; local version="$3"; local scope="$4"
  local versionLine=""
  local scopeLine=""

  if [ -n "$version" ]; then
    versionLine="      <version>${version}</version>\\n"
  fi

  if [ -n "$scope" ]; then
    scopeLine="      <scope>${scope}</scope>\\n"
  fi

  sed -i "/<\\/dependencies>/i\\    <dependency>\\n      <groupId>${groupId}</groupId>\\n      <artifactId>${artifactId}</artifactId>\\n${versionLine}${scopeLine}    </dependency>" pom.xml
}

updateOrInsertDependency() {
  local groupId="$1"; local artifactId="$2"; local version="$3"; local scope="$4"
  [ -n "$scope" ] && echo "  Scope: ${scope}"

  if dependencyExists "${groupId}" "${artifactId}"; then
    if [ -n "$version" ]; then
      echo "  Updating version: ${groupId}:${artifactId}:${version}"
      if ! updateVersionWithMaven "${groupId}" "${artifactId}" "${version}"; then
        echo "  ❌ Update failed"
        return 1
      fi
    else
      echo "  Removing version from: ${groupId}:${artifactId}"
      deleteVersionIfPresent "${groupId}" "${artifactId}"
    fi
  else
    echo "  Adding new dependency: ${groupId}:${artifactId}${version:+:${version}}"
    insertDependencyBlock "${groupId}" "${artifactId}" "${version}" "${scope}"
  fi
}

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
  
  if [ ! -d "${project}" ]; then
    echo "  ❌ project not found: ${project}"
    return 1
  fi
  
  cd "${project}"
  echo "  Running Maven in: $(pwd)"
  if ! updateOrInsertDependency "${groupId}" "${artifactId}" "${version}" "${scope}"; then
    return 1
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

echo "Updating: ${groupId}:${artifactId}${version:+ to $version}${scope:+ with scope $scope}"
echo "Branch: ${branch} | Module: ${project}"
echo ""

IFS=',' read -ra product_list <<< "$products"
for product in "${product_list[@]}"; do
  product=$(echo "$product" | xargs)
  [ -z "$product" ] && continue
  updateProduct "$product" || true
done