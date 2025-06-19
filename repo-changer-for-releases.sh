#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "$DIR/repo-collector.sh"

if [ -z "${BRANCH}" ]; then
  echo "no BRANCH variable defined"
  exit 123
fi
if [ -z "${TITLE}" ]; then
  echo "no TITLE variable defined"
  exit 124
fi
if [ -z "${BODY}" ]; then
  BODY=$TITLE
fi

migrated_repos=()

changeReposReleases() {
  changeAction="$1"
  if [ -z "$changeAction" ]; then
    echo "changeReposReleases was called without a parameter to define the 'change' function name"
    exit 125
  fi
  collectRepos | while read -r repo_name; do
    changeForReleaseForSingleRepo "$repo_name"
  done
  echo "migrated: ${migrated_repos[@]}"
}

changeForReleaseForSingleRepo() {
  repo_name="$1"
  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  echo "Clone repo ${repo_name}"
  gh repo clone "https://github.com/${org}/${repo_name}.git"

  cd "${repo_name}"
  # Find all release/* branches
  release_branches=$(git ls-remote --heads origin "refs/heads/release/*" | sed 's|.*refs/heads/||')
  echo release_branches
  if [ -z "$release_branches" ]; then
    echo "❌ No release/* branch found for ${repo_name}, skipping"
    cd ..
    rm -rf "${repo_name}"
    return
  fi

  for release_branch in $release_branches; do
    echo "➡️ Working on branch $release_branch"
    feature_branch="${BRANCH}-${release_branch//\//-}"
    pr_title="${TITLE} (${release_branch})"

    # Clean up any previous state
    git fetch origin "$release_branch"
    git checkout -b "$feature_branch" "origin/$release_branch"

    # Run the actual modification
    "${changeAction}"

    if git diff --quiet; then
      echo "No changes in $release_branch"
      continue
    fi

    git add .
    git commit -m "$pr_title"
    git push --set-upstream origin "$feature_branch"

    gh pr create \
      --base "$release_branch" \
      --head "$feature_branch" \
      --title "$pr_title" \
      --body "$BODY" \
      --assignee "$GITHUB_ACTOR"\

    migrated_repos+=("${repo_name}@$release_branch")
  done

  cd ..
  rm -rf "${repo_name}"
}
