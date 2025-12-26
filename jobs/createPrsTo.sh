#!/bin/bash

BRANCH="feature/marp-3513-vscode-marketplace-readiness"
TITLE="MARP-3513 Product readiness for VScode Marketplace"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../repo-changer.sh"

# new snapshots of the project-build-plugin and web-tester are only published under the new Central Portal URI:
updatePomWithRepoName() {
  local REPO_NAME="$1"
  echo "Hardcoding project.name in pom.xml for repo: $REPO_NAME"
  find . -name "pom.xml" -type f | while read -r POM; do
    sed -i -E "
      s|\$\{project\.name\}-openapi|${REPO_NAME}-openapi|g
      s|\$\{project\.name\}-demo|${REPO_NAME}-demo|g
      s|\$\{project\.name\}-test|${REPO_NAME}-test|g
      s|\$\{project\.name\}-product|${REPO_NAME}-product|g
      s|\$\{project\.name\}|${REPO_NAME}|g
    " "$POM"
  done
}

changeRepos 'updatePomWithRepoName'
