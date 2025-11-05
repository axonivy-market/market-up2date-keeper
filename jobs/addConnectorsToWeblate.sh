#!/bin/bash

WEBLATE_PROJECT="axonivy-marketplace"
WEBLATE_URL="https://hosted.weblate.org"
WEBLATE_TOKEN=""

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../repo-collector.sh"
source "${DIR}/../weblate-functions.sh"
source "${DIR}/../github-webhook-functions.sh"

# Check if repo should be ignored
isIgnored() {
  local repo=$1
  for ignored in "${ignored_repos[@]}"; do
    if [[ "$repo" == "$ignored" ]]; then
      return 0
    fi
  done
  return 1
}

# Process each repository
echo "Collecting repositories from $org..."
githubReposC | jq -c '.[] | 
  select(.archived == false) | 
  select(.is_template == false) | 
  select(.default_branch == "master") | 
  select(.language != null) | 
  {name: .name, url: .html_url}' | while IFS= read -r REPO_DATA; do
  
  REPO_NAME=$(echo "$REPO_DATA" | jq -r '.name')
  REPO_URL=$(echo "$REPO_DATA" | jq -r '.url')

  # Skip if repo is in ignored list
  if isIgnored "$REPO_NAME"; then
    continue
  fi

  echo "Adding repo $REPO_NAME as component..."

  addWeblateComponent "$REPO_NAME" "$REPO_URL" "$WEBLATE_URL" "$WEBLATE_TOKEN" "$WEBLATE_PROJECT"

  addGithubWebhook "$org" "$REPO_NAME" "$WEBLATE_URL"
done

echo "Done."