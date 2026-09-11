# re-usable collection of market repos to modify

ignored_repos=(
  "market-up2date-keeper"
  "market"
  "market-monitor"
  "demo-projects"
  "github-repo-manager"
)

# GitHub organization to work on
# For testing, please use a personal org
org=axonivy-market

githubRepos() {
  gh api --paginate "orgs/${org}/repos?type=all" | jq -s 'add'
}

githubReposC(){
  cache="/tmp/gh-${org}-repos.json"
  if [ ! -f "${cache}" ]; then
    githubRepos > "${cache}"
  fi
  cat "${cache}"
}

collectAllRepos() {
  githubReposC |
    jq -r '.[] | .name'
}

collectRepos() {
  githubReposC | 
    jq -r '.[] | 
    select(.archived == false) | 
    select(.is_template == false) | 
    select(.default_branch == "master") | 
    select(.language != null) | 
      .name'
}