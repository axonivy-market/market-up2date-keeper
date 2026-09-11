#!/bin/bash
#
# Prints a JSON formatted list of the latest release versions
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

showLatestRelease() {
  repo="$1"
  releases="repos/${org}/${repo}/releases/latest"
  tags="repos/${org}/${repo}/tags"
  latestTag=$(gh api "${tags}" 2> /dev/null | jq -r 'first.name // "None"')
  latestRelease=$(gh api "${releases}" 2> /dev/null | jq -r 'select(.draft == false).name // "None"')
  packageData=$(showPackageLatest "$repo")
  latestTag=${latestTag:-None}
  latestRelease=${latestRelease:-None}
  packageData=${packageData:-'{"version":"MISSING","date":"MISSING"}'}
  jq -c -n \
    --arg latestTag "$latestTag" \
    --arg latestRelease "$latestRelease" \
    --argjson packageData "$packageData" \
    '{"Latest_Tag": $latestTag, "Latest_Release": $latestRelease, "Package Latest": $packageData.version, "Package Date": $packageData.date}'
}

showProjectVersion() {
  repo="$1"
  projectPath=$(gh api --method GET "repos/${org}/${repo}/git/trees/${branch}" -f recursive=1 2> /dev/null |
    jq -r '[(.tree // [])[] | select(.path == ".ivyproject" or (.path | endswith("/.ivyproject")))][0].path // empty')
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
        | select((.name // "") | endswith("-product"))
        | (.versions.nodes // [])[]
        | {version, date: ([.files.nodes[]?.updatedAt] | max // ""), versionKey: ((.version // "") | split("-")[0] | split(".") | map(try tonumber catch 0))}
        | select(.date != "")
      ]
      | if length == 0 then {version: "MISSING", date: "MISSING"} else max_by(.versionKey + [.date]) | {version, date} end'
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
  jq -c -n \
    --arg codeowners "$codeowners" \
    --arg licenseStatus "$licenseStatus" \
    --arg securityStatus "$securityStatus" \
    --arg codeOfConductStatus "$codeOfConductStatus" \
    '{"CODE_OWNERS": $codeowners, "LICENSE": $licenseStatus, "SECURITY": $securityStatus, "CODE_OF_CONDUCT": $codeOfConductStatus}'
}

showLatestReleaseAndRequiredFileStatus() {
  repo="$1"
  latestReleaseData=$(showLatestRelease "$repo")
  projectVersion=$(showProjectVersion "$repo")
  fileStatuses=$(checkRequiredFiles "$repo")
  jq -c -n \
    --arg repo "$repo" \
    --arg projectVersion "$projectVersion" \
    --argjson latestReleaseData "$latestReleaseData" \
    --argjson fileStatuses "$fileStatuses" \
    '{"Repo": $repo} + $latestReleaseData + {"ProjectVersion": $projectVersion} + $fileStatuses'
}

latestReposJSON() {
  printf '[\n'
  first=true
  while read -r repo_name; do
    repo_json=$(showLatestReleaseAndRequiredFileStatus "$repo_name")
    if [ "$first" = true ]; then
      first=false
    else
      printf ',\n'
    fi
    printf '%s' "$repo_json"
  done < <(reposToCheck)
  printf '\n]\n'
}

latestReposJSON