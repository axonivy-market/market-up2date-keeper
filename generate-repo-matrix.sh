#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${DIR}/repo-collector.sh"

if [ -n "$1" ]; then
  REPOS=$(jq -R 'split(",")' <<< "$1")
else
  REPOS=$(collectRepos | jq -Rs 'split("\n")[:-1]')
  echo "📦 Found repos: $REPOS"
fi

# Build matrix JSON object
MATRIX_JSON=$(jq -n --argjson repos "$REPOS" '{ include: $repos }')
echo "matrix<<EOF" >> $GITHUB_OUTPUT
echo "$MATRIX_JSON" >> $GITHUB_OUTPUT
echo "EOF" >> $GITHUB_OUTPUT