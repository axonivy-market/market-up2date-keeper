#!/bin/bash
#
# Prints a CSV formatted list of the latest release versions
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
branch="${1:-master}"
repoToCheck="${2:-}"

. "${DIR}/repo-collector.sh"

reposToCheck() {
  if [ -n "$repoToCheck" ]; then
    echo "$repoToCheck"
  else
    collectRepos
  fi
}

latestReposCSV() {
  echo "Repo;Latest_Tag;Latest_Release;ProjectVersion;CODE_OWNERS;Package Latest;LICENSE;SECURITY;CODE_OF_CONDUCT"
  reposToCheck |
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

showProjectVersion() {
  repo="$1"
  encodedBranch="${branch//\//%2F}"
  projectPath=$(gh api --method GET "repos/${org}/${repo}/git/trees/${encodedBranch}" -f recursive=1 2> /dev/null |
    jq -r '[.tree[]? | select(.path == ".ivyproject" or (.path | endswith("/.ivyproject")))][0].path // empty')
  if [ -z "$projectPath" ]; then
    echo "MISSING"
    return
  fi

  projectContent=$(gh api --method GET "repos/${org}/${repo}/contents/${projectPath}" -f "ref=${branch}" 2> /dev/null |
    jq -r '.content // "missing"')
  if [ "$projectContent" = "missing" ]; then
    echo "MISSING"
    return
  fi

  version=$(echo "$projectContent" | base64 --decode |
    sed -n -E 's/^version[[:space:]]*=[[:space:]]*(.*)$/\1/p' |
    head -n1)
  echo "${version:-MISSING}"
}

showPackageLatest() {
  repo="$1"
  gh api "orgs/${org}/packages/maven/${repo}-product/versions" 2> /dev/null |
    jq -r 'if type == "array" then .[0].name // "MISSING" else "MISSING" end'
}

checkFileStatus() {
  repo="$1"
  readContent="$2"
  shift 2
  filePaths=("$@")
  for path in "${filePaths[@]}"; do
    fileStatus=$(gh api "repos/${org}/${repo}/contents/${path}" 2> /dev/null | jq -r '.content // "missing"')
    if [ "$fileStatus" != "missing" ]; then
      if [ "$readContent" = "true" ]; then
        echo "$fileStatus" | base64 --decode | tr '\n' ' '
        return
      fi
      echo "[x]$path"
      return
    fi
  done
  echo "MISSING $path"
}

checkRequiredFiles() {
  repo="$1"
  codeowners=$(checkFileStatus "$repo" "true" ".github/CODEOWNERS" "CODEOWNERS" "docs/CODEOWNERS")
  packageLatest=$(showPackageLatest "$repo")
  # Check other files
  licenseStatus=$(checkFileStatus "$repo" "false" "LICENSE")
  securityStatus=$(checkFileStatus "$repo" "false" "SECURITY.md")
  codeOfConductStatus=$(checkFileStatus "$repo" "false" "CODE_OF_CONDUCT.md")
  echo "$codeowners;$packageLatest;$licenseStatus;$securityStatus;$codeOfConductStatus"
}

showLatestReleaseAndRequiredFileStatus() {
  repo="$1"
  latestReleaseData=$(showLatestRelease "$repo")
  projectVersion=$(showProjectVersion "$repo")
  fileStatuses=$(checkRequiredFiles "$repo")
  echo "$repo;$latestReleaseData;$projectVersion;$fileStatuses"
}

latestReposCSV() {
  echo "Repo;Latest_Tag;Latest_Release;ProjectVersion;CODE_OWNERS;Package Latest;LICENSE;SECURITY;CODE_OF_CONDUCT"
  reposToCheck |
  while read repo_name; do
    showLatestReleaseAndRequiredFileStatus "$repo_name"
  done
}

latestReposCSV