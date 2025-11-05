set -e

WEBLATE_PROJECT="axonivy-marketplace"
WEBLATE_URL="https://hosted.weblate.org"
WEBLATE_TOKEN=""

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../repo-collector.sh"

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
  REPO_BRANCH=$(echo "$REPO_DATA" | jq -r '.branch')

  # Skip if repo is in ignored list
  if isIgnored "$REPO_NAME"; then
    continue
  fi

  echo "Adding repo $REPO_NAME as component..."

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
      \"template\": \"README.md\",
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

  # Add GitHub webhook
  WEBHOOK_URL="${WEBLATE_URL%/}/hooks/github/"
  WEBHOOK_RESPONSE=$(MSYS_NO_PATHCONV=1 gh api \
      --method POST \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "/repos/$org/$REPO_NAME/hooks" \
      -f name='web' \
      -F active=true \
      -F config[url]="$WEBHOOK_URL" \
      -F config[content_type]='application/x-www-form-urlencoded' \
      -F config[insecure_ssl]='0' \
      -f events[]='push' 2>&1)
done

echo "Done."