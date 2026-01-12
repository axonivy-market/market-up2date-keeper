# re-usable collection of market repos to modify

ignored_repos=(
  "github-repo-manager",
  "market-up2date-keeper"
  "market"
  "market-monitor"
  "demo-projects"
)

# GitHub organization to work on
# For testing, please use a personal org
org=axonivy-market

githubRepos() {
  ghApi="orgs/${org}/repos?per_page=100"
  curl https://api.github.com/${ghApi}
}

githubReposC(){
  cache="/tmp/gh-${org}.json"
  if [ ! -f "${cache}" ]; then
    githubRepos > "${cache}"
  fi
  cat "${cache}"
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
