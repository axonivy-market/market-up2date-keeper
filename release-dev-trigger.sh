#!/bin/bash
#
# Usage: release-dev-trigger.sh [repo] ["branch ..."]
#
# Dispatches the release-dev workflow of every market product on every release
# branch. GitHub only runs "schedule" triggers on the default branch, so the
# nightly snapshot of dev/14.0 and friends has to be dispatched from here.
#
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

ignored_repos+=(
  "market.axonivy.com"
  "portal"
  "mobileapp"
  "process-miner-viewer"
  "octopus-admin-tools"
)

releaseDevWorkflow="release-dev.yml"
releaseBranchPattern='^(master|dev/[0-9]+\.[0-9]+|release/(10|12)\.0)$'

reposWithBranchesQuery='
  query($org: String!, $endCursor: String) {
    organization(login: $org) {
      repositories(first: 50, after: $endCursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          name
          refs(refPrefix: "refs/heads/", first: 100) { nodes { name } }
        }
      }
    }
  }'

onlyRepo="${1:-}"
onlyBranches="${2:-}"
dryRun="${dryRun:-true}"

report="${GITHUB_STEP_SUMMARY:-/dev/null}"

collectProducts() {
  collectRepos | grep -vxF "$(printf '%s\n' "${ignored_repos[@]}")"
}

# every repo of the org together with its branches, in 1 request per 50 repos
githubReposWithBranches() {
  gh api graphql --paginate -F org="${org}" -f query="${reposWithBranchesQuery}" |
    jq -s '[.[].data.organization.repositories.nodes[]] | map({ name, branches: [.refs.nodes[].name] })'
}

collectTargets() {
  githubReposWithBranches |
    jq -r --arg releaseBranch "${releaseBranchPattern}" \
          --argjson products "$(collectProducts | jq -Rs 'split("\n")[:-1]')" \
      '.[] | select(.name | IN($products[])) | .name as $product |
       .branches[] | select(test($releaseBranch)) | "\($product) \(.)"'
}

selectTargets() {
  collectTargets |
    awk -v product="${onlyRepo}" -v branches="${onlyBranches}" \
      'function wanted(branch) { return branches == "" || index(" " branches " ", " " branch " ") }
       (product == "" || $1 == product) && wanted($2)'
}

dispatchReleaseDev() {
  product=$1
  branch=$2

  jq -n --arg ref "${branch}" --arg dryRun "${dryRun}" '{ ref: $ref, inputs: { dryRun: $dryRun } }' |
    gh api --method POST "repos/${org}/${product}/actions/workflows/${releaseDevWorkflow}/dispatches" --input - > /dev/null
}

reportRow() {
  printf '| %s | %s | %s |\n' "$1" "$2" "$3" >> "${report}"
}

reportHeader() {
  echo "### Release-Build-Dev (dryRun: ${dryRun})" >> "${report}"
  echo "| product | branch | dispatch |" >> "${report}"
  echo "| --- | --- | --- |" >> "${report}"
}

main() {
  targets=$(selectTargets)
  if [ -z "${targets}" ]; then
    echo "No release branch matched repo '${onlyRepo}' branches '${onlyBranches}'"
    exit 1
  fi

  reportHeader
  undispatched=""

  while read -r product branch; do
    if dispatchReleaseDev "${product}" "${branch}"; then
      echo "Dispatched ${product} ${branch}"
      reportRow "${product}" "${branch}" "ok"
    else
      echo "Failed to dispatch ${product} ${branch}"
      reportRow "${product}" "${branch}" "**failed**"
      undispatched="${undispatched}${product} ${branch}"$'\n'
    fi
    sleep 1 # stay below the secondary rate limit for bursts of workflow dispatches
  done <<< "${targets}"

  if [ -n "${undispatched}" ]; then
    echo "Products without a dispatchable ${releaseDevWorkflow}:"
    echo "${undispatched}"
    exit 1
  fi
}

main
