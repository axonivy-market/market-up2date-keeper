#!/bin/bash
#
# Usage: project-migrator.sh <version> <repository-name>
#

source "$DIR/project-migrator.sh"
source "$DIR/maven-migrator.sh"
source "$DIR/workflow-migrator.sh"

repo_url="https://github.com/axonivy-market/${repo_name}"
clone_url="git@github.com:axonivy-market/${repo_name}.git"

checkRepoExists() {
  exists=$(curl -s -o /dev/null -w "%{http_code}" "${repo_url}")
  if [ $exists -ne 200 ]; then
    echo "Repo ${repo_url} does not exist"
    exit 1
  fi
}

cloneRepo() {
  if ! [ -d "${repo}" ]; then
    gh repo clone "${repo_url}"
  fi
}

updateMavenVersion() {
  artifactVersion $convert_to_version

  # commit changes
  git add .
  git commit -m "Update maven version to ${convert_to_version}"
}

updateActions() {
  tag="v6"
  updateWorkflows "${tag}"
  git add .
  git commit -m "Update workflow actions to ${tag}"
}

if [ -z "$releaseBranch" ]; then
  releaseBranch="release/12.0"
fi

createReleaseBranch() {
  echo "Create release branch ${releaseBranch}"
  if git ls-remote --heads origin "${releaseBranch}" | grep -q "${releaseBranch}"; then
    echo "Branch ${releaseBranch} already exists in ${repo_name}"
  else
    git checkout -b "${releaseBranch}"
    git push --set-upstream origin ${releaseBranch}
  fi
}

push() {
  has_unpushed_commits=$(git log --branches --not --remotes)
  if [ -z "$has_unpushed_commits" ]; then
    echo "No changes to push for ${repo_name}"
  else
    echo "Pushing changes of ${repo_name}"
    git push --set-upstream origin $branch
    gh pr create --title "Migrate to ${convert_to_version} :camel:" --assignee "$GITHUB_ACTOR" --body "A friendly conversion provided by market-up2date-keeper :robot: :handshake: "
    echo "${repo_url}" >> ${workDir}/migrated-repos.txt
  fi
}


checkRepoExists
downloadEngine
cloneRepo

cd ${repo}
createReleaseBranch
branch="raise-to-${convert_to_version}"
git switch -c $branch

raiseProject
updateMavenVersion
updateActions
push
cd ..
