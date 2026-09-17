#!/bin/bash

# Release Dev Workflow Creator CLI
# ================================
# This script creates pull requests to add or update the Release-Build-Dev
# workflow on every release branch of each repository in the axonivy-market
# GitHub Organization. The nightly run itself is dispatched by
# trigger-release-dev.yml of market-up2date-keeper, because GitHub only
# schedules the default branch.
# Using https://cli.github.com/

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/../repo-collector.sh

# keep in sync with release-dev-trigger.sh, it excludes exactly these repos too
ignored_repos+=(
  "portal"
  "mobileapp"
  "process-miner-viewer"
  "octopus-admin-tools"
  "iis-proxy"
  "axon-ivy-dev-skills"
)

ticket="MARP-4636"
pr_title="${ticket} Update release-dev workflow"

workflow_file_release_dev=".github/workflows/release-dev.yml"

java_version_for_base_branch() {
  case "$1" in
    dev/14.0) echo "25" ;;
    release/10.0|dev/10.0) echo "17" ;;
    *) echo "21" ;;
  esac
}

workflow_content_for_base_branch() {
  base_branch=$1

  cat <<WORKFLOW
name: Release-Build-Dev
run-name: Release-Build-Dev \${{ github.ref_name }}\${{ inputs.dryRun && ' (dry run)' || '' }}

on:
  workflow_dispatch:
    inputs:
      dryRun:
        description: Dry run mode for release and cleanup
        type: boolean
        required: false
        default: true

permissions:
  contents: read
  actions: read
  packages: write

jobs:
  release:
    uses: axonivy-market/github-workflows/.github/workflows/release-dev.yml@v6
    with:
      dryRun: \${{ inputs.dryRun }}
      javaVersion: $(java_version_for_base_branch "$base_branch")
    secrets: inherit
WORKFLOW
}

commits_ahead_of_base_branch() {
  git rev-list --count "origin/$1..HEAD"
}

collectTargetBaseBranches() {
  echo "master"
  echo "dev/14.0"
  echo "release/10.0"
  echo "release/12.0"
}

create_pr_for_base_branch() {
  base_branch=$1
  repo_name=$2

  if ! git ls-remote --heads origin "$base_branch" | grep -q "refs/heads/$base_branch$"; then
    echo "Base branch '$base_branch' does not exist in $repo_name, skipping"
    return
  fi

  branch_name="feature/${ticket}-update-release-dev-workflow-$(echo "$base_branch" | tr '/' '-')"

  echo "Processing $repo_name release branch $base_branch (head branch $branch_name)"

  if git ls-remote --heads origin "$branch_name" | grep -q "refs/heads/$branch_name$"; then
    echo "Branch $branch_name already exists, checking it out"
    git fetch origin "$branch_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name" "origin/$base_branch"
  fi

  mkdir -p .github/workflows
  workflow_content_for_base_branch "$base_branch" > "$workflow_file_release_dev"
  git add "$workflow_file_release_dev"

  if ! git diff --cached --quiet; then
    git commit -m "$pr_title"
  fi

  if [ "$(commits_ahead_of_base_branch "$base_branch")" -eq 0 ]; then
    echo "$repo_name $base_branch is already up to date"
    return
  fi

  git push origin "$branch_name"

  pr_id=$(gh pr list --head "$branch_name" --base "$base_branch" --json number --jq '.[0].number')

  if [ -z "$pr_id" ]; then
    echo "Creating a pull request into $base_branch"
    gh pr create --title "$pr_title" --body "This PR updates the Release-Build-Dev workflow of the repository." --base "$base_branch" --head "$branch_name"
  else
    echo "Pull request already exists for branch $branch_name into $base_branch"
  fi
}

create_prs_for_repo() {
  repo_name=$1
  echo "Processing repository $repo_name"

  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  collectTargetBaseBranches | while read -r base_branch; do
    create_pr_for_base_branch "$base_branch" "$repo_name"
  done

  cd ..
  rm -rf "${repo_name}"
}

main() {
  echo "Repositories found:"
  collectRepos | while read -r repo_name; do
    create_prs_for_repo "$repo_name"
  done
}

main
