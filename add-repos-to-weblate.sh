#!/bin/bash

INPUT_REPO_NAME="${INPUT_REPO_NAME:-}"
WEBLATE_PROJECT="${WEBLATE_PROJECT:-axonivy-marketplace}"
WEBLATE_URL="${WEBLATE_URL:-https://hosted.weblate.org}"
WEBLATE_TOKEN="${WEBLATE_TOKEN:-}"

echo "Starting to add repositories to Weblate project: $WEBLATE_PROJECT"
echo "Using Weblate URL: $WEBLATE_URL"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/repo-collector.sh"
source "${DIR}/weblate-functions.sh"
source "${DIR}/github-webhook-functions.sh"

isIgnored() {
  local repo=$1
  for ignored in "${ignored_repos[@]}"; do
    if [[ "$repo" == "$ignored" ]]; then
      return 0
    fi
  done
  return 1
}

githubReposC | jq -c '.[] | 
  select(.archived == false) | 
  select(.is_template == false) | 
  select(.default_branch == "master") | 
  select(.language != null) | 
  {name: .name, url: .html_url}' | while IFS= read -r REPO_DATA; do
  
  REPO_NAME=$(echo "$REPO_DATA" | jq -r '.name')
  REPO_URL=$(echo "$REPO_DATA" | jq -r '.url')

  if isIgnored "$REPO_NAME"; then
    continue
  fi

  if [[ -n "$INPUT_REPO_NAME" && "$REPO_NAME" != "$INPUT_REPO_NAME" ]]; then
    continue
  fi
  echo "Adding repo $REPO_NAME as component..."
  addWeblateComponent "$REPO_NAME" "$REPO_URL" "$WEBLATE_URL" "$WEBLATE_TOKEN" "$WEBLATE_PROJECT"

  addGithubWebhook "$org" "$REPO_NAME" "$WEBLATE_URL"

  if [[ -n "$INPUT_REPO_NAME" ]]; then
    break
  fi
done