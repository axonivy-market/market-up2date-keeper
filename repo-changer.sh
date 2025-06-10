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
    echo "No changes to push for ${repo_name}"
  else
    echo "Pushing changes of ${repo_name}"
    git push --set-upstream origin $BRANCH
    gh pr create\
      --title "$TITLE"\
      --assignee "$GITHUB_ACTOR"\
      --body "$BODY"
    migrated_repos+=("$repo_url")
  fi
}

changeRepos() {
  changeAction="$1"
  if [ -z "$changeAction" ]; then
    echo "changeRepos was called without a parameter to define the 'change' function name"
    exit 125
  fi
  collectRepos | while read -r repo_name; do
    changeSingleRepo "$repo_name"
  done
  echo "migrated: ${migrated_repos[@]}"
}

changeSingleRepo() {
  repo_name="$1"
  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  echo "Clone repo ${repo_name}"
  gh repo clone "git@github.com:${org}/${repo_name}.git"

  cd "${repo_name}"
  git switch -c $BRANCH

  # run
  "${changeAction}"

  git add .
  git commit -m "$TITLE"

  pushAndCreatePR
  cd ..
}
