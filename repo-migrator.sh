#!/bin/bash
#
# Usage: project-migrator.sh <version> <repository-name>
#

source "$DIR/project-migrator.sh"
source "$DIR/maven-migrator.sh"
source "$DIR/workflow-migrator.sh"

repo_url="https://github.com/axonivy-market/${repo_name}"
clone_url="git@github.com:axonivy-market/${repo_name}.git"
DEPRECATION_MESSAGE="*Note that this Market Extension is marked for deprecation. We recommend using the successor instead. **No new features** will be added to this extension; **only bug and security fixes** will be provided.*"

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
}

commitChanges() {
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

checkReadmeFilesForKeyword() {
  local repo_name
  local repo_path="${gitDir}/${repo_name}"
  echo "Checking README files in ${repo_path} for deprecation message"
  if [ ! -d "$repo_path" ]; then
    echo "Product folder not found: ${repo_path}" >&2
    return 1
  fi

  while IFS= read -r readme_file; do
    if grep -qiF "$DEPRECATION_MESSAGE" "$readme_file"; then
      echo "Found deprecation message in $readme_file" >&2
      return 0
    fi
  done < <(find "$repo_path" -type f \( -iname "README" -o -iname "README.*" \))

  return 1
}


checkRepoExists
downloadEngine
cloneRepo

if checkReadmeFilesForKeyword "${repo}"; then
  echo "Skipping migration for ${repo} because README contains deprecation keyword"
else
  cd ${repo}
  if [ -n "$releaseBranch" ]; then
    createReleaseBranch
  fi
  if [ -n "$migrationBranch" ]; then
    branch="$migrationBranch"
  else
    branch="migrate-to-${convert_to_version}"
  fi
  git switch -c $branch

  updateMavenVersion
  raiseProject
  commitChanges
  updateActions
  push
  cd ..
fi
