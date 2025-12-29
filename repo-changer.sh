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

pushAndCreatePR() {
  has_unpushed_commits=$(git log --branches --not --remotes)
  if [ -z "$has_unpushed_commits" ]; then
    echo "No changes to push for ${repo_name} on ${base_branch}"
  else
    echo "Pushing changes of ${repo_name} on branch ${feature_branch}"
    git push --set-upstream origin "$feature_branch"
    gh pr create\
      --title "$pr_title"\
      --assignee "$GITHUB_ACTOR"\
      --body "$BODY"\
      --base "$base_branch"\
      --head "$feature_branch"
    migrated_repos+=("${repo_name}@${base_branch}")
  fi
}

cleanup_repo() {
  cd ..
  rm -rf "${repo_name}"
}

process_branch() {
  git fetch origin "$base_branch"
  git checkout -b "$feature_branch" "origin/$base_branch"

  "$changeAction" "$repo_name"

  git add .
  git commit -m "$pr_title" || true

  pushAndCreatePR
}

changeRepos() {
  changeAction="$1"
  RELEASE_MODE="$2"

  echo RELEASE_MODE is "${RELEASE_MODE}"
  if [ -z "$changeAction" ]; then
    echo "changeRepos was called without a parameter to define the 'change' function name"
    exit 125
  fi
  collectRepos | while read -r repo_name; do
    changeSingleRepo "$repo_name" "$changeAction"
  done
  echo "migrated: ${migrated_repos[@]}"
}

changeSingleRepo() {
  local repo_name="$1"

  repo_name=$(echo "$repo_name" | sed 's/\r//g')
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  echo "Cloning repo ${repo_name}"
  gh repo clone "git@github.com:${org}/${repo_name}.git"
  cd "${repo_name}"

  if [[ "$RELEASE_MODE" -eq 1 ]]; then
    release_branches=$(git ls-remote --heads origin "refs/heads/release/*" | sed 's|.*refs/heads/||')
    if [ -z "$release_branches" ]; then
      echo "❌ No release/* branch found for ${repo_name}, skipping"
      cleanup_repo
      return
    fi

    for base_branch in $release_branches; do
      echo "➡️ Working on branch $base_branch"
      feature_branch="${BRANCH}-${base_branch//\//-}"
      pr_title="${TITLE} (${base_branch})"
      process_branch
    done
  else
    base_branch="master"
    feature_branch="$BRANCH"
    pr_title="$TITLE"
    process_branch
  fi

  cleanup_repo
}