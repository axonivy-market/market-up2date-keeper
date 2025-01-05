#!/bin/bash

# Release Drafter Workflow Creator CLI
# ===================================
# This script creates pull requests to add a Release Drafter workflow to each repository
# in the axonivy-market GitHub Organization.
# Using https://cli.github.com/

org="axonivy-market"

ignored_repos=(
  "market-up2date-keeper"
  "market.axonivy.com"
  "market-monitor"
  "market"
  "demo-projects"
)

workflow_file_release_drafter=".github/workflows/release-drafter.yml"
workflow_content_release_drafter="name: Release Drafter

on:
  push:
    branches:
      - master
      - release/*
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  release_drafter:
    uses: axonivy-market/github-workflows/.github/workflows/release-drafter.yml@v5"

workflow_file_publish_release=".github/workflows/publish-release-drafter.yml"
workflow_content_publish_release="name: Publish Release Drafter

on:
  workflow_run:
    workflows: ["Release-Build"]
    types:
      - completed

jobs:
  publish_release_drafter:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    uses: axonivy-market/github-workflows/.github/workflows/publish-release-drafter.yml@v5
    # The following input parameters are available:
    #
    # - tag: (optional) Specifies the release tag (e.g., 'v10.0.0').
    #        If not provided, the most recent tag in the repository will be used by default.
    #        This ensures the workflow runs without requiring explicit tag input.
    #
    # - commitish: (optional) Indicates the branch name for the release.
    #              If not provided, it defaults to 'master'. For versioned releases, 
    #              the workflow automatically checks for a corresponding branch 
    #              (e.g., 'release/10.0' for version 10.0) and uses it if available.
    #              This allows the workflow to execute with default branch behavior.
    #
    # - publish: (optional) Controls whether the release is published automatically.
    #            Defaults to 'true'. Set to 'false' to create a draft release 
    #            without immediate publication.
    #
    # Note: Both 'tag' and 'commitish' are configured to run with sensible defaults,
    #       so manual input is not required unless custom values are needed.
    #
    # Uncomment and modify the inputs as needed:
    # with:
    #   tag: v10.0.0
    #   commitish: release/10.0
    #   publish: false"

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

create_label_if_not_exists() {
  repo_name=$1
  label_name="skip-changelog"
  label_color="e11d21"  # Optional: You can choose a color for the label

  # Check if the label exists
  label_exists=$(gh api repos/${org}/${repo_name}/labels --jq '.[] | select(.name == "'"$label_name"'") | .name')

  if [ -z "$label_exists" ]; then
    echo "Creating label '$label_name' in repository $repo_name"
    gh api repos/${org}/${repo_name}/labels -X POST -f name="$label_name" -f color="$label_color"
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

  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')

  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  # Define branch and PR variables
  branch_name="feature/MARP-1053-Update-release-drafter-and-publisher-workflows"
  pr_title="MARP-1053 Add release-drafter and release-publisher workflows"

  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "Branch $branch_name already exists in $repo_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name"
  fi

  # Always override the existing workflow file with new content
  mkdir -p .github/workflows
  echo "$workflow_content_release_drafter" > "$workflow_file_release_drafter"
  git add "$workflow_file_release_drafter"

  # Delete old workflow file if it exists
  old_workflow_file_publish_release=".github/workflows/publish-release.yml"
  if [ -f "$old_workflow_file_publish_release" ]; then
    rm "$old_workflow_file_publish_release"
    git add "$old_workflow_file_publish_release"
  fi
  
  echo "$workflow_content_publish_release" > "$workflow_file_publish_release"
  git add "$workflow_file_publish_release"
  git commit -m "Updaate publish-release-drafter and release-drafter workflows"

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