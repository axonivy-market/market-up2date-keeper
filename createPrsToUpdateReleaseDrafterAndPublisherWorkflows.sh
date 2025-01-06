#!/bin/bash

# Release Drafter Workflow Modifier CLI
# ===================================
# This script creates pull requests to update a Release Drafter workflow to each repository
# in the axonivy-market GitHub Organization.
# Using https://cli.github.com/

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

create_label_if_not_exists() {
  repo_name=$1
  label_name="skip-changelog"
  label_color="e11d21"

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

  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  echo "Processing repository $repo_name"
  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')
  branch_name="feature/MARP-1053-Update-release-drafter-and-publisher-workflows"
  pr_title="MARP-1053 Update release-drafter and release-publisher workflows"
  workflow_path_release_drafter=".github/workflows/release-drafter.yml"
  workflow_path_publish_release_drafter=".github/workflows/publish-release-drafter.yml"
  workflow_content_release_drafter=$(fetch_raw_file "$org" "market-product" "$workflow_path_release_drafter")
  workflow_content_publish_release_drafter=$(fetch_raw_file "$org" "market-product" "$workflow_path_publish_release_drafter")

  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "Branch $branch_name already exists in $repo_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name"
  fi

  # Always override the existing workflow file with new content
  mkdir -p .github/workflows
  echo "$workflow_content_release_drafter" > "$workflow_path_release_drafter"
  git add "$workflow_path_release_drafter"
  
  echo "$workflow_content_publish_release_drafter" > "$workflow_path_publish_release_drafter"
  git add "$workflow_path_publish_release_drafter"

  # Delete old workflow file if it exists
  old_workflow_path_publish_release=".github/workflows/publish-release.yml"
  if [ -f "$old_workflow_path_publish_release" ]; then
    rm "$old_workflow_path_publish_release"
    git add "$old_workflow_path_publish_release"
  fi

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

fetch_raw_file() {
  local owner="$1"
  local repo="$2"
  local file_path="$3"

  gh api repos/$org/$repo/contents/$file_path?ref=feature/MARP-1053-Update-publish-release-template \
    -H "Accept: application/vnd.github.v3.raw"
}

main() {
  echo "====== Starting script ======"
  collectRepos | while read -r repo_name; do
    create_label_if_not_exists "$repo_name"
    create_pr "$repo_name"
  done
  echo "====== End script ======"
}

main