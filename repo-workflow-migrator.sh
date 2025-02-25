org="axonivy-market"
repo_url="https://github.com/axonivy-market/${repo_name}"
clone_url="git@github.com:axonivy-market/${repo_name}.git"
workflow_version="v6"
reviewer_name="nameofreviewer"
ignored_repos=(
  "market-up2date-keeper"
  "market.axonivy.com"
  "market-monitor"
  "market"
  "demo-projects"
  "portal"
  "marketplace"
  "api-proxy"
  "bpmn-assistant"
  "market-product"
  "msgraph-connector"
  "portal-ai"
  "mobileapp"
  "amazon-aws4-authenticator"
  ".github"
  "github-workflows"
  "jira-cloud-connector"
  "hubspot-connector"
  "doc-factory"
  "successfactors-connector"
  "ui-path-connector"
  "talentLink-connector"
)

# Function to collect repositories based on filters
collectRepos() {
  githubRepos | 
    jq -r '.[] | 
    select(.archived == false) | 
    select(.is_template == false) | 
    select(.default_branch == "master") | 
    select(.language != null) | 
      .name' | sed 's/\r//g'
}

# Function to retrieve repositories from the GitHub API
githubRepos() {
  ghApi="orgs/${org}/repos?per_page=100"
  gh api "${ghApi}"
}

cloneRepo() {
  if ! [ -d "${repo_name}" ]; then
    gh repo clone "${repo_url}"
  fi
}

updateActions() {
  for workflow in .github/workflows/*.yml ; do
    echo "updating $workflow"
    sed -i -r "s|(uses: axonivy-market/github-workflows/.github/workflows/.*\.yml)@(v[0-9]+)|\1@${workflow_version}|g" $workflow
  done
  git add .
  git commit -m "Update workflow actions to ${workflow_version}"
}

push() {
  has_unpushed_commits=$(git log --branches --not --remotes)
  if [ -z "$has_unpushed_commits" ]; then
    echo "No changes to push for ${repo_name}"
  else
    echo "Pushing changes of ${repo_name}"
    git push --set-upstream origin $branch
    gh pr create --title "Update workflow actions to ${workflow_version}" --body "Update all workflow actions to new version ${workflow_version}" --base master --head "$branch" --reviewer "$reviewer_name"
  fi
}

echo "Repositories found:"
collectRepos | while read -r repo_name; do
  echo "Checking repo: $repo_name"
  # Ensure repo name has no carriage return characters
  repo_name=$(echo "$repo_name" | sed 's/\r//g')

  # Pass ignored repositories  
  if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
    echo "Ignoring repo ${repo_name}"
    return
  fi

  #Cloning repository to local
  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"
  branch="update-workflow-to-${workflow_version}"
  git switch -c $branch

  updateActions
  push
  cd ..
done


