#!/bin/bash

addWeblateComponent() {
  local REPO_NAME=$1
  local REPO_URL=$2
  local WEBLATE_URL=$3
  local WEBLATE_TOKEN=$4
  local WEBLATE_PROJECT=$5

  curl -s -X POST "${WEBLATE_URL%/}/api/projects/${WEBLATE_PROJECT}/components/" \
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
        \"language_code_style\": \"\",
        \"merge_style\": \"merge\",
        \"source_language\": {
            \"code\": \"en\"
        },
        \"language_regex\": \"^[A-Z]{2}$\"
    }"
}