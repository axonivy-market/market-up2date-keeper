#!/usr/bin/env bash

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
    -f events[]='push' 2>&1
}