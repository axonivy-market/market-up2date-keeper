#!/bin/bash

BRANCH="central-sonatype-migration"
TITLE="Migrate to new central.sonatype Portal URI :camel:"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../repo-changer.sh"

# new snapshots of the project-build-plugin and web-tester are only published under the new Central Portal URI:
updateSnapshotSource() {
  echo "updating ${repo_name}"
  where="**/pom.xml"
  oldRepo="https://oss.sonatype.org/content/repositories/snapshots"
  newRepo="https://central.sonatype.com/repository/maven-snapshots"
  sed -i -E "s|<url>${oldRepo}</url>|<url>${newRepo}</url>|g" $where
}

changeRepos 'updateSnapshotSource' 0
