#!/bin/bash

BRANCH="feature/marp-3513-vscode-marketplace-readiness"
TITLE="MARP-3513 Product readiness for VScode Marketplace"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../repo-changer.sh"

updatePomWithRepoName() {
  local REPO_NAME="$1"
  echo "Hardcoding project.name in root pom.xml for repo: $REPO_NAME"
  if [ -f pom.xml ]; then
    sed -i "s/\${project.name}/${REPO_NAME}/g" pom.xml
  else
    echo "⚠️ No root pom.xml found, skipping"
  fi
}

changeRepos 'updatePomWithRepoName' 1 // use 0 for master branch processing, 1 for release/* branches
