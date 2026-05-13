#!/bin/bash
#
# Usage: raise-all-market-products.sh <version>
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

if [ -z "$workDir" ]; then
  workDir=$(mktemp -d -t projectConvertXXX)
fi

if [ -z "$gitDir" ]; then
  gitDir="$DIR/repos"
  echo $(mkdir -v -p $DIR/repos)
fi

convert_to_version=$1
if [ -z "$convert_to_version" ]; then
  echo "Missing target version parameter e.g 13.2.0-SNAPSHOT"
  exit 1
fi

if [[ ! $convert_to_version == *-SNAPSHOT ]]; then
  echo "Version must be SNAPSHOT e.g 13.2.0-SNAPSHOT"
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
  printf "%s\n" \
  "adobe-acrobat-sign-connector" \
  "google-translate-connector" \
  "stateful-datatable" \
  "intellix-connector" \
  "email-encryption" \
  "express-importer" \
  "cronjob" \
  "kafka-connector" \
  "master-detail" \
  "sbb-connector" \
  "srf-weather-connector" \
  "metaproc-connector" \
  "docker-connector" \
  "graphql-demo" \
  "threema-connector" \
  "excel-importer" \
  "salesforce-connector" \
  "ups-connector" \
  "open-weather-connector" \
  "process-inspector" \
  "mattermost-connector" \
  "rtf-factory" \
  "jsf-formarchive-util" \
  "process-miner-viewer" \
  "ai-assistant" \
  "skribble-connector" \
  "vertexai-google" \
  "S4HANA-connector" \
  "asana-connector" \
  "gdpr-utils" \
  "snowflake-connector" \
  "keycloak-connector" \
  "coffee-machine-connector" \
  "case-mail-component-connector" |
  while read repo_name; do
  migrateRepo "$repo_name"
  done
  showMigratedRepos
}

migrateRepo() {
  cd ${gitDir}
  repo=$1
  if [[ " ${ignored_repos[@]} " =~ " ${repo} " ]]; then
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

