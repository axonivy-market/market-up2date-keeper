# re-usable collection of market repos to modify

ignored_repos=(
  "market-up2date-keeper"
  "market"
  "market-monitor"
  "demo-projects"
  "github-repo-manager"
)

# Additional repos to skip during migration due to not a ivy project, deprecated, or need manual migration.
# Add repo names here (one per line) if you want them to be skipped.
ignored_migration_repos=(
  "amazon-aws4-authenticator"
  "portal"
  "successfactors-connector"
  "talentLink-connector"
  "mobileapp"
  "process-miner-viewer"
  "ai-assistant"
  "e2e-test-utils"
  "iis-proxy"
  "axonivy-docs-common"
  "axonivy-express"
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