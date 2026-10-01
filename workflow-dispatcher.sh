#!/bin/bash
#
# Dispatches a workflow of the market products on their release branches.
# GitHub only runs "schedule" triggers on the default branch, so nightly builds
# of dev/14.0 and friends are dispatched from here.
#
#   workflow-dispatcher.sh dev.yml "" "dev/14.0"
#   workflow-dispatcher.sh release-dev.yml alfresco-connector all dryRun=false
#
# Env extraIgnoredRepoList: name of a repo list of repo-collector.sh to skip on top
# of ignored_repos (e.g. release_dev_ignored_repos)
#
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

usage='Usage: workflow-dispatcher.sh <workflow> <product|""> <"branch ..."|all> [key=value ...]'
allBranches="all"
releaseBranchPattern='^(master|dev/[0-9]+\.[0-9]+|release/(10|12)\.0)$'
secondsBelowSecondaryRateLimit=1

releasableProductsQuery='
  query($org: String!, $endCursor: String) {
    organization(login: $org) {
      repositories(first: 50, after: $endCursor, isArchived: false) {
        pageInfo { hasNextPage endCursor }
        nodes {
          name
          isTemplate
          primaryLanguage { name }
          defaultBranchRef { name }
          refs(refPrefix: "refs/heads/", first: 100) { nodes { name } }
        }
      }
    }
  }'

workflow="${1:?${usage}}"
onlyProduct="${2?${usage}}"
onlyBranches="${3:?${usage}}"
workflowInputs=("${@:4}")

if [ -n "${extraIgnoredRepoList:-}" ]; then
  declare -n extraIgnoredRepos="${extraIgnoredRepoList}"
  ignored_repos+=("${extraIgnoredRepos[@]:?unknown repo list ${extraIgnoredRepoList} in repo-collector.sh}")
fi

stepSummary="${GITHUB_STEP_SUMMARY:-/dev/null}"

releasableProductsWithBranches() {
  gh api graphql --paginate -F org="${org}" -f query="${releasableProductsQuery}" |
    jq -s --argjson ignoredRepos "$(printf '%s\n' "${ignored_repos[@]}" | jq -Rs 'split("\n")[:-1]')" '
      [.[].data.organization.repositories.nodes[]] |
      map(select(.isTemplate == false)) |
      map(select(.defaultBranchRef.name == "master")) |
      map(select(.primaryLanguage != null)) |
      map(select(.name | IN($ignoredRepos[]) | not)) |
      map({ name, branches: [.refs.nodes[].name] })'
}

collectTargets() {
  releasableProductsWithBranches |
    jq -r --arg releaseBranch "${releaseBranchPattern}" \
      '.[] | .name as $product |
       .branches[] | select(test($releaseBranch)) | "\($product) \(.)"'
}

selectTargets() {
  collectTargets |
    awk -v product="${onlyProduct}" -v branches="${onlyBranches}" -v all="${allBranches}" \
      'function wanted(branch) { return branches == all || index(" " branches " ", " " branch " ") }
       (product == "" || $1 == product) && wanted($2)'
}

keyValuesToJson() {
  jq -n '$ARGS.positional | map(capture("^(?<key>[^=]+)=(?<value>.*)$")) | from_entries' --args "$@"
}

dispatchInputs=$(keyValuesToJson "${workflowInputs[@]}")

dispatchPayload() {
  jq -n --arg ref "$1" --argjson inputs "${dispatchInputs}" \
    '{ ref: $ref } + if $inputs == {} then {} else { inputs: $inputs } end'
}

dispatchStatus() {
  product=$1
  branch=$2

  if error=$(dispatchPayload "${branch}" |
      gh api --method POST "repos/${org}/${product}/actions/workflows/${workflow}/dispatches" --input - 2>&1 > /dev/null); then
    echo "ok"
  else
    echo "${error}" >&2
    echo "failed"
  fi
}

summaryRow() {
  printf '| %s | %s | %s |\n' "$1" "$2" "$3" >> "${stepSummary}"
}

summaryHeader() {
  echo "### ${workflow} ${workflowInputs[*]}" >> "${stepSummary}"
  echo "| product | branch | dispatch |" >> "${stepSummary}"
  echo "| --- | --- | --- |" >> "${stepSummary}"
}

main() {
  targets=$(selectTargets)
  if [ -z "${targets}" ]; then
    echo "No release branch matched product '${onlyProduct}' branches '${onlyBranches}'"
    exit 1
  fi

  summaryHeader
  failedTargets=""

  while read -r product branch; do
    status=$(dispatchStatus "${product}" "${branch}")
    echo "${status} ${product} ${branch}"
    if [ "${status}" = "failed" ]; then
      summaryRow "${product}" "${branch}" "**failed**"
      failedTargets="${failedTargets}${product} ${branch}"$'\n'
    else
      summaryRow "${product}" "${branch}" "${status}"
    fi
    sleep "${secondsBelowSecondaryRateLimit}"
  done <<< "${targets}"

  if [ -n "${failedTargets}" ]; then
    echo "Could not dispatch ${workflow} for:"
    echo "${failedTargets}"
    exit 1
  fi
}

main
