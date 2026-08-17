#!/bin/bash

# Release Dev Workflow Creator CLI
# ================================
# This script creates pull requests to add a Release-Build-Dev workflow to each
# repository in the axonivy-market GitHub Organization, targeting each repo's
# master branch, every "dev/*" branch, release/10.0 and release/12.0 (whichever
# of those exist for that repo).
# The release-dev workflow runs a Maven build from the repo root, so a base
# branch is only touched if it has a pom.xml at its root; otherwise it's
# recorded in $skipped_report_file and left alone.
# Using https://cli.github.com/

org="axonivy-market"

ignored_repos=(
  "market-up2date-keeper"
  "market.axonivy.com"
  "market-monitor"
  "market"
  "demo-projects"
  "portal"
)

ticket="MARP-4636"
pr_title="${ticket} Add release-dev workflow"

# Absolute path, captured before any "cd" so it stays valid from any function.
skipped_report_file="$(pwd)/release-dev-workflow-skipped-no-pom.log"

workflow_file_release_dev=".github/workflows/release-dev.yml"

# Java version used to build each base branch.
java_version_for_base_branch() {
  case "$1" in
    dev/14.0) echo "25" ;;
    release/10.0|dev/10.0) echo "17" ;;
    *) echo "21" ;;
  esac
}

workflow_content_for_base_branch() {
  base_branch=$1
  java_version=$(java_version_for_base_branch "$base_branch")

  echo "name: Release-Build-Dev

on:
  schedule:
    - cron: '21 21 * * *'
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
      dryRun: \${{ fromJSON(github.event_name == 'schedule' && 'false' || github.event_name == 'workflow_dispatch' && github.event.inputs.dryRun || 'true') }}
      javaVersion: ${java_version}
    secrets: inherit"
}

githubRepos() {
  ghApi="orgs/${org}/repos?per_page=100"
  gh api "${ghApi}"
}

collectRepos() {
  githubRepos |
    jq -r '.[] |
    select(.archived == false) |
    select(.is_template == false) |
    select(.default_branch == "master") |
    select(.language != null) |
      .name' | sed 's/\r//g'
}

collectTargetBaseBranches() {
  # Static targets, skipped later if they don't exist on the remote.
  echo "master"
  echo "release/10.0"
  echo "release/12.0"

  # All branches under dev/*
  git ls-remote --heads origin 'refs/heads/dev/*' | sed 's#.*refs/heads/##'
}

create_pr_for_base_branch() {
  base_branch=$1
  repo_name=$2

  if ! git ls-remote --heads origin "$base_branch" | grep -q "$base_branch"; then
    echo "Base branch '$base_branch' does not exist in $repo_name, skipping"
    return
  fi

  git fetch origin "$base_branch"

  if ! git cat-file -e "origin/${base_branch}:pom.xml" 2>/dev/null; then
    echo "No pom.xml at the root of $repo_name on $base_branch, skipping"
    echo "${repo_name}  ${base_branch}" >> "$skipped_report_file"
    return
  fi

  branch_name="feature/${ticket}-add-release-dev-workflow-$(echo "$base_branch" | tr '/' '-')"

  echo "Processing $repo_name base branch $base_branch (head branch $branch_name)"

  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "Branch $branch_name already exists, checking it out"
    git fetch origin "$branch_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name" "origin/$base_branch"
  fi

  mkdir -p .github/workflows
  workflow_content_for_base_branch "$base_branch" > "$workflow_file_release_dev"
  git add "$workflow_file_release_dev"
  git commit -m "$pr_title"

  git push origin "$branch_name"

  pr_id=$(gh pr list --head "$branch_name" --base "$base_branch" --json number --jq '.[0].number')

  if [ -z "$pr_id" ]; then
    echo "Creating a pull request into $base_branch"
    gh pr create --title "$pr_title" --body "This PR adds the Release-Build-Dev workflow to the repository." --base "$base_branch" --head "$branch_name"
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

  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')

  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  collectTargetBaseBranches | while read -r base_branch; do
    create_pr_for_base_branch "$base_branch" "$repo_name"
  done

  cd ..
  rm -rf "${repo_name}"
}

main() {
  : > "$skipped_report_file"

  echo "Repositories found:"
  collectRepos | while read -r repo_name; do
    create_prs_for_repo "$repo_name"
  done

  echo ""
  echo "Matched branches skipped because no pom.xml was found at the repo root:"
  if [ -s "$skipped_report_file" ]; then
    cat "$skipped_report_file"
  else
    echo "(none)"
  fi
}

main
