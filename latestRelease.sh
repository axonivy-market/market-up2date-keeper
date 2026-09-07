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
  echo "Repo;Latest_Tag;Latest_Release;Package Latest;Package Date;ProjectVersion;CODE_OWNERS;LICENSE;SECURITY;CODE_OF_CONDUCT"
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
  packageData=$(showPackageLatest "$repo")
  echo "$latestTag;$latestRelease;$packageData"
}

showProjectVersion() {
  repo="$1"
  projectPath=$(gh api --method GET "repos/${org}/${repo}/git/trees/${branch}" -f recursive=1 2> /dev/null |
    jq -r '[.tree[] | select(.path == ".ivyproject" or (.path | endswith("/.ivyproject")))][0].path // empty')
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
  gh api graphql \
    -F "owner=${org}" \
    -F "name=${repo}" \
    -f 'query=query($owner:String!, $name:String!) { repository(owner:$owner, name:$name) { packages(first:30, packageType:MAVEN) { nodes { name versions(first:100) { nodes { version files(first:30) { nodes { updatedAt } } } } } } } }' 2> /dev/null |
    jq -r '
      [
        .data.repository.packages.nodes[]?
        | select(.name | endswith("-product"))
        | .versions.nodes[]
        | {version, date: ([.files.nodes[]?.updatedAt] | max // ""), versionKey: (.version | split("-")[0] | split(".") | map(tonumber))}
        | select(.date != "")
      ]
      | if length == 0 then "MISSING;MISSING" else max_by(.versionKey + [.date]) | [.version, .date] | join(";") end'
}

checkFileStatus() {
  repo="$1"
  readContent="$2"
  shift 2
  filePaths=("$@")
  for path in "${filePaths[@]}"; do
    fileStatus=$(gh api --method GET "repos/${org}/${repo}/contents/${path}" -f "ref=${branch}" 2> /dev/null | jq -r '.content // "missing"')
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
  # Check other files
  licenseStatus=$(checkFileStatus "$repo" "false" "LICENSE")
  securityStatus=$(checkFileStatus "$repo" "false" "SECURITY.md")
  codeOfConductStatus=$(checkFileStatus "$repo" "false" "CODE_OF_CONDUCT.md")
  echo "$codeowners;$licenseStatus;$securityStatus;$codeOfConductStatus"
}

showLatestReleaseAndRequiredFileStatus() {
  repo="$1"
  latestReleaseData=$(showLatestRelease "$repo")
  projectVersion=$(showProjectVersion "$repo")
  fileStatuses=$(checkRequiredFiles "$repo")
  echo "$repo;$latestReleaseData;$projectVersion;$fileStatuses"
}

latestReposCSV() {
  echo "Repo;Latest_Tag;Latest_Release;Package Latest;Package Date;ProjectVersion;CODE_OWNERS;LICENSE;SECURITY;CODE_OF_CONDUCT"
  reposToCheck |
  while read repo_name; do
    showLatestReleaseAndRequiredFileStatus "$repo_name"
  done
}

latestReposCSV