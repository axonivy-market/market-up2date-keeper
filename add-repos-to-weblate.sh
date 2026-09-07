#!/bin/bash

INPUT_REPO_NAME="${INPUT_REPO_NAME:-}"
WEBLATE_PROJECT="${WEBLATE_PROJECT:-axonivy-marketplace}"
WEBLATE_URL="${WEBLATE_URL:-https://hosted.weblate.org}"
WEBLATE_TOKEN="${WEBLATE_TOKEN:-}"

echo "Starting to add repositories to Weblate project: $WEBLATE_PROJECT"
echo "Using Weblate URL: $WEBLATE_URL"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/repo-collector.sh"

isIgnored() {
  local repo=$1
  for ignored in "${ignored_repos[@]}"; do
    if [[ "$repo" == "$ignored" ]]; then
      return 0
    fi
  done
  return 1
}


addWeblateComponent() {
  local REPO_NAME=$1
  local REPO_URL=$2
  local WEBLATE_URL=$3
  local WEBLATE_TOKEN=$4
  local WEBLATE_PROJECT=$5

  curl --fail-with-body -sS -X POST "${WEBLATE_URL%/}/api/projects/${WEBLATE_PROJECT}/components/" \
    -H "Authorization: Token $WEBLATE_TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary "{
        \"name\": \"$REPO_NAME\",
        \"slug\": \"$REPO_NAME\",
        \"vcs\": \"github\",
        \"repo\": \"$REPO_URL\",
        \"branch\": \"master\",
        \"push\": \"$REPO_URL\",
        \"file_format\": \"markdown\",
        \"filemask\": \"$REPO_NAME-product/README_*.md\",
        \"new_base\": \"\",
        \"new_lang\": \"none\",
        \"template\": \"$REPO_NAME-product/README.md\",
        \"edit_template\": \"false\",
        \"id_auto_lock_error\": \"false\",
        \"license\": \"Apache-2.0\",
        \"commit_pending_age\": \"1\",
        \"language_code_style\": \"\",
        \"merge_style\": \"merge\",
        \"source_language\": {
            \"code\": \"en\"
        },
        \"language_regex\": \"^[A-Z]{2}$\"
    }"
}

addGithubWebhook() {
  local ORG=$1
  local REPO_NAME=$2
  local WEBLATE_URL=$3

  local WEBHOOK_URL="${WEBLATE_URL%/}/hooks/github/"
  
  MSYS_NO_PATHCONV=1 gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$ORG/$REPO_NAME/hooks" \
    -f name='web' \
    -F active=true \
    -F config[url]="$WEBHOOK_URL" \
    -F config[content_type]='application/x-www-form-urlencoded' \
    -F config[insecure_ssl]='0' \
    -f events[]='push' 2>&1 || return $?
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