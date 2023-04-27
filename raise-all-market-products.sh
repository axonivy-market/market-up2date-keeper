#!/bin/bash
#
# Usage: raise-all-market-products.sh <version>
#

# repos that are under heavy maintenance by LTS driven projects
lts_repos=(
  "persistence-utils"
  "docuware-connector"
  "successfactors-connector"
  "talentLink-connector"
)

ignored_repos=(
  "market-up2date-keeper"
  "market"
  "demo-projects"
)

if [ -z "$workDir" ]; then
  workDir=$(mktemp -d -t projectConvertXXX)
fi

convert_to_version=$1
if [ -z "$convert_to_version" ]; then
  echo "Missing target version parameter e.g 9.4.0-SNAPSHOT"
  exit 1
fi

if [[ ! $convert_to_version == *-SNAPSHOT ]]; then
  echo "Version must be SNAPSHOT e.g 9.4.0-SNAPSHOT"
  exit 1
fi


collectRepos() {
  # get repos that are not archived, templates and language is not null
  curl https://api.github.com/orgs/axonivy-market/repos?per_page=100 | 
  jq -r '.[] | 
    select(.archived == false) | 
    select(.is_template == false) | 
    select(.default_branch == "master") | 
    select(.language != null) | 
    .name'
}

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
  repo=$1
  if [[ " ${ignored_repos[@]} " =~ " ${repo} " || " ${lts_repos[@]} " =~ " ${repo} " ]]; then
    echo "Ignoring repo ${repo}"
  else
    echo "Migrating $repo to $convert_to_version"
    source ./repo-migrator.sh
  fi
}

repo_name=$2
if [ -z "$repo_name" ]; then
  migrateListOfRepos
else
  migrateRepo $repo_name
fi

