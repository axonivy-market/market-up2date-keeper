source "./workflow-migrator.sh"
source "./repo-collector.sh"

workflow_tag_version="v6"

updateActions() {
  updateWorkflows "${workflow_tag_version}"
  git add .
  git commit -m "Update workflow actions to ${workflow_tag_version}"
}

pushAndCreatePR() {
  has_unpushed_commits=$(git log --branches --not --remotes)
  if [ -z "$has_unpushed_commits" ]; then
    echo "No changes to push for ${repo_name}"
  else
    echo "Pushing changes of ${repo_name}"
    git push --set-upstream origin $branch
    gh pr create --title "Update workflow actions to ${workflow_tag_version}" --body "Update all workflow actions to new version ${workflow_tag_version}" --base master --head "$branch"
  fi
}

echo "Repositories found:"
collectRepos | while read -r repo_name; do
  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')

  # Pass ignored repositories  
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  # Cloning repository to local
  echo "Clone repo ${repo_name}"
  gh repo clone "https://github.com/${org}/${repo_name}"

  # Create new branch
  cd "${repo_name}"
  branch="update-workflow-to-${workflow_tag_version}"
  git switch -c $branch

  updateActions
  pushAndCreatePR
  cd ..
done
