#!/bin/bash
#
# Usage: raise-all-market-products.sh <version>
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

# Additional repos to skip during migration due to not a legacy ivy project, deprecated, or need manual migration.
ignored_migration_repos=()

# Utility lib for Axon Ivy projects/engine
ignored_migration_repos+=("iis-proxy")
ignored_migration_repos+=("amazon-aws4-authenticator")
ignored_migration_repos+=("process-miner-viewer")
ignored_migration_repos+=("axonivy-docs-common")
ignored_migration_repos+=("e2e-test-utils")

# Maintained by team Wawa
ignored_migration_repos+=("mobileapp")
ignored_migration_repos+=("portal")
ignored_migration_repos+=("ai-assistant")
ignored_migration_repos+=("axonivy-express")

# Built from highly customized environments from customers
ignored_migration_repos+=("successfactors-connector")
ignored_migration_repos+=("talentLink-connector")

if [ -z "$workDir" ]; then
  workDir=$(mktemp -d -t projectConvertXXX)
fi

if [ -z "$gitDir" ]; then
  gitDir="$DIR/repos"
  echo $(mkdir -v -p $DIR/repos)
fi

convert_to_version=$1
if [ -z "$convert_to_version" ]; then
  echo "Missing target version parameter e.g 14.0.0-SNAPSHOT"
  exit 1
fi

if [[ ! $convert_to_version == *-SNAPSHOT ]]; then
  echo "Version must be SNAPSHOT e.g 14.0.0-SNAPSHOT"
  exit 1
fi


showMigratedRepos() {
  log="${workDir}/migrated-repos.txt"
  if [ -f $log ]; then
    echo "Migrated repos:"
    cat $log
  fi
}

migrateListOfRepos() {
  collectRepos |
  while read repo_name; do
    migrateRepo $repo_name
  done
  showMigratedRepos
}

migrateRepo() {
  cd ${gitDir}
  repo=$1
  # Skip repos listed in either `ignored_repos` or `ignored_migration_repos`
  if [[ " ${ignored_repos[@]} " =~ " ${repo} " ]] || [[ " ${ignored_migration_repos[@]} " =~ " ${repo} " ]]; then
    echo "Ignoring repo ${repo}"
  else
    echo "Migrating $repo to $convert_to_version"
    source "$DIR/repo-migrator.sh"
  fi
  cd $DIR
}

repo_name=$2
if [ -z "$repo_name" ]; then
  migrateListOfRepos
else
  migrateRepo $repo_name
fi

