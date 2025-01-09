#!/bin/bash

# Release Drafter Workflow Modifier CLI
# ===================================
# This script creates pull requests to update a Release Drafter workflow to each repository
# in the axonivy-market GitHub Organization.
# Using https://cli.github.com/

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/repo-collector.sh

create_label_if_not_exists() {
  local repo_name="$1"
  local label_name="skip-changelog"
  local label_color="e11d21"

  local label_exists=$(gh api repos/${org}/${repo_name}/labels --jq '.[] | select(.name == "'"$label_name"'") | .name')

  if [ -z "$label_exists" ]; then
    echo "Creating label '$label_name' in repository $repo_name"
    gh api repos/${org}/${repo_name}/labels -X POST -f name="$label_name" -f color="$label_color"
  else
    echo "Label '$label_name' already exists in repository $repo_name"
  fi
}

delete_files() {
  local files=("$@")
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      echo "Deleting $file"
      git rm "$file"
    else
      echo "$file not found, skipping."
    fi
  done
}

process_branch() {
  local repo_name="$1"
  local branch_name="$2"
  local base_branch="$3"

  echo "Processing branch $branch_name in repository $repo_name"
  git checkout "$base_branch"
  if git ls-remote --heads origin "$branch_name" | grep -q "$branch_name"; then
    echo "Branch $branch_name already exists in $repo_name"
    git checkout "$branch_name"
  else
    git checkout -b "$branch_name"
  fi

  mkdir -p .github/workflows
  echo "$workflow_content_release_drafter" > .github/workflows/release-drafter.yml
  git add .github/workflows/release-drafter.yml

  echo "$workflow_content_publish_release_drafter" > .github/workflows/publish-release-drafter.yml
  git add .github/workflows/publish-release-drafter.yml

  delete_files ".github/workflows/publish-release.yml"

  git commit -m "MARP-1053 Update release drafter workflows for branch $base_branch"
  git push origin "$branch_name"

  local pr_id=$(gh pr list --head "$branch_name" --base "$base_branch" --json number --jq '.[0].number')
  if [ -z "$pr_id" ]; then
    echo "Creating a pull request"
    gh pr create --title "MARP-1053 Update release drafter and publisher workflows for branch $base_branch" --body "" --base "$base_branch" --head "$branch_name"
  else
    echo "Pull request already exists for branch $branch_name"
  fi
}

create_pr() {
  local repo_name="$1"

  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  local branches=$(git branch -r | grep "release/" | sed 's|origin/||g')
  workflow_path_release_drafter=".github/workflows/release-drafter.yml"
  workflow_path_publish_release_drafter=".github/workflows/publish-release-drafter.yml"
  workflow_content_release_drafter=$(fetch_raw_file "$org" "market-product" "$workflow_path_release_drafter")
  workflow_content_publish_release_drafter=$(fetch_raw_file "$org" "market-product" "$workflow_path_publish_release_drafter")

  if [[ ! " $branches " =~ " master " ]]; then
    branches+=" master"
  fi

  for base_branch in $branches; do
    local branch_name=""
    if [[ $base_branch == "master" ]]; then
      branch_name="feature/MARP-1053-Update-release-drafter-and-publisher-workflows"
    else
      local release_version=$(echo "$base_branch" | sed 's|release/||')
      branch_name="feature/${release_version}/MARP-1053-Update-release-drafter-and-publisher-workflows"
    fi

    process_branch "$repo_name" "$branch_name" "$base_branch"
  done

  cd ..
  rm -rf "${repo_name}"
}

fetch_raw_file() {
  local owner="$1"
  local repo="$2"
  local file_path="$3"

  gh api repos/$org/$repo/contents/$file_path \
    -H "Accept: application/vnd.github.v3.raw"
}

main() {
  echo "====== Starting script ======"
  collectRepos | sed '/^$/d' | while read -r repo_name; do
    create_label_if_not_exists "$repo_name"
    create_pr "$repo_name"
  done
  echo "====== End script ======"
}

main