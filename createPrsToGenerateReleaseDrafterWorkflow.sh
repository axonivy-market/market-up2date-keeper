#!/bin/bash

# Release Drafter Workflow Creator CLI
# ===================================
# This script creates pull requests to add a Release Drafter workflow to each repository
# in the axonivy-market GitHub Organization.
# Using https://cli.github.com/

org="axonivy-market"
user="ndkhanh-axonivy"

ignored_repos=(
  "market-up2date-keeper"
  "market.axonivy.com"
  "market-monitor"
  "market"
  "demo-projects"
)

workflow_file=".github/workflows/release-drafter.yml"
workflow_content="name: Release Drafter

on:
  push:
    branches:
      - master
  pull_request:
    types: [opened, reopened, synchronize]
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version'
        required: true
      prerelease:
        description: 'Is this a prerelease?'
        required: false
        default: false
        type: boolean

permissions:
  contents: write
  pull-requests: write

jobs:
  build:
    uses: axonivy-market/github-workflows/.github/workflows/release-drafter.yml@v4
    with:
      version: \${{ github.event.inputs.version }}
      prerelease: \${{ github.event.inputs.prerelease }}"

githubRepos() {
  # ghApi="orgs/${org}/repos?per_page=100"
  ghApi="users/${user}/repos?per_page=100"
  gh api "${ghApi}"
}

githubReposC(){
  cache="/tmp/gh-${org}.json"
  if [ ! -f "${cache}" ]; then
    githubRepos > "${cache}"
  fi
  cat "${cache}"
}

collectRepos() {
  githubReposC | 
    jq -r '.[] | 
    select(.archived == false) | 
    select(.is_template == false) | 
    select(.default_branch == "master") | 
    select(.language != null) | 
      .name'
}

create_label_if_not_exists() {
  repo_name=$1
  label_name="skip-changelog"
  label_color="e11d21"  # Optional: You can choose a color for the label

  # Check if the label exists
  label_exists=$(gh api repos/${user}/${repo_name}/labels --jq '.[] | select(.name == "'"$label_name"'") | .name')

  if [ -z "$label_exists" ]; then
    echo "Creating label '$label_name' in repository $repo_name"
    gh api repos/${user}/${repo_name}/labels -X POST -f name="$label_name" -f color="$label_color"
  else
    echo "Label '$label_name' already exists in repository $repo_name"
  fi
}

create_pr() {
  repo_name=$1
  echo "Processing repository $repo_name"
  
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  git clone "https://github.com/${user}/${repo_name}.git"
  cd "${repo_name}"

  # Define branch and PR variables
  branch_name="feature/MARP-620-Add-release-drafter-workflow"
  pr_title="MARP-620 Add release-drafter workflow"
  workflow_path=".github/workflows/release-drafter.yml"

  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "Branch $branch_name already exists in $repo_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name"
  fi

  if [ ! -f "$workflow_path" ]; then
    mkdir -p .github/workflows
    echo "$workflow_content" > "$workflow_path"
    git add "$workflow_path"
    git commit -m "Add release-drafter workflow"
  else
    echo "Workflow file already exists in branch $branch_name"
  fi

  git push origin "$branch_name"

  pr_id=$(gh pr list --head "$branch_name" --base master --json number --jq '.[0].number')

  if [ -z "$pr_id" ]; then
    echo "Creating a pull request"
    gh pr create --title "$pr_title" --body "This PR adds the Release Drafter workflow to the repository." --base master --head "$branch_name"
    pr_id=$(gh pr list --head "$branch_name" --base master --json number --jq '.[0].number')
  else
    echo "Pull request already exists for branch $branch_name"
  fi

  if [ -n "$pr_id" ]; then
    pr_labels=$(gh pr view "$pr_id" --json labels --jq '.labels[].name' | grep -w "skip-changelog")
    if [ -z "$pr_labels" ]; then
      echo "Adding label to the pull request"
      gh pr edit "$pr_id" --add-label "skip-changelog"
    else
      echo "Label 'skip-changelog' already present on PR $pr_id"
    fi
  fi

  cd ..
  rm -rf "${repo_name}"
}

main() {
  echo "Repositories found:"
  collectRepos | while read -r repo_name; do
    create_label_if_not_exists "$repo_name"
    create_pr "$repo_name"
  done
}

main