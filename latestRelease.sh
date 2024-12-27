#!/bin/bash
#
# Prints a CSV formatted list of the latest release versions
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

. "${DIR}/repo-collector.sh"

latestReposCSV() {
  echo "Repo;Latest_Tag;Latest_Release;CODE_OWNERS;LICENSE;SECURITY;CODE_OF_CONDUCT"
  collectRepos |
  while read repo_name; do
    showLatestReleaseAndRequiredFileStatus "$repo_name"
  done
}

showLatestRelease() {
  repo="$1"
  releases="repos/${org}/${repo}/releases/latest"
  tags="repos/${org}/${repo}/tags"
  latestTag=$(gh api "${tags}" 2> /dev/null | jq -r 'first.name // "None"')
  latestRelease=$(gh api "${releases}" 2> /dev/null | jq -r 'select(.draft == false).name // "None"')
  echo "$latestTag;$latestRelease"
}

checkFileStatus() {
  repo="$1"
  shift
  filePaths=("$@")
  for path in "${filePaths[@]}"; do
    fileStatus=$(gh api "repos/${org}/${repo}/contents/${path}" 2> /dev/null | jq -r '.content // "missing"')
    if [ "$fileStatus" != "missing" ]; then
      echo "Present(source $path)"
      return
    fi
  done
  echo "MISSING"
}

checkRequiredFiles() {
  repo="$1"
  # Check CODEOWNERS in multiple locations
  codeownersLocation=$(checkFileStatus "$repo" ".github/CODEOWNERS" "CODEOWNERS" "docs/CODEOWNERS")
  # Check other files
  licenseStatus=$(checkFileStatus "$repo" "LICENSE")
  securityStatus=$(checkFileStatus "$repo" "SECURITY.md")
  codeOfConductStatus=$(checkFileStatus "$repo" "CODE_OF_CONDUCT.md")
  echo "$codeownersLocation;$licenseStatus;$securityStatus;$codeOfConductStatus"
}

showLatestReleaseAndRequiredFileStatus() {
  repo="$1"
  latestReleaseData=$(showLatestRelease "$repo")
  fileStatuses=$(checkRequiredFiles "$repo")
  echo "$repo;$latestReleaseData;$fileStatuses"
}

latestReposCSV() {
  echo "Repo;Latest_Tag;Latest_Release;CODE_OWNERS;LICENSE;SECURITY;CODE_OF_CONDUCT"
  collectRepos |
  while read repo_name; do
    showLatestReleaseAndRequiredFileStatus "$repo_name"
  done
}

latestReposCSV