#!/bin/bash
set -e

ORG="tvtphuc-axonivy"
BASE_DIR="$(pwd)/repos"
BRANCH_NAME="feature/MARP-3642-How-to-handle-spelling-errors"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "Fetching repositories from org: $ORG"

repos=$(gh repo list "$ORG" --limit 200 --json name -q '.[].name')

for repo in $repos; do
  echo "===================================="
  echo "Processing repo: $repo"

  # Clone repo if not exists
  if [ ! -d "$repo" ]; then
    gh repo clone "$ORG/$repo"
  fi

  cd "$repo"

  # Check if branch exists on remote
  if git ls-remote --exit-code --heads origin "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Branch '$BRANCH_NAME' exists → deleting..."

    git push origin --delete "$BRANCH_NAME"

    echo "✅ Branch deleted"
  else
    echo "Branch '$BRANCH_NAME' not found → skip"
  fi

  cd ..
done

echo "✅ Done cleaning branches"