#!/bin/bash
# Add new rule in CODEOWNERS and create a GitHub Actions workflow to block changes to README_DE.md
# Enable branch protection on the default branch

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. ${DIR}/../repo-collector.sh

# Add additional repos to ignore
ignored_repos+=("msgraph-connector",
  "amazon-aws4-authenticator",
  "intellix-connector",
  "html-dialog-utils",
  "express-importer",
  "mobileapp",
  "dmn-decision-table")

DEFAULT_BRANCH="master"
REVIEWER="Octopus-AxonIvy"
CODEOWNERS_FILE=".github/CODEOWNERS"
CODEOWNERS_RULE="**/README_DE.md  @axonivy-market/team-octopus"
BRANCH_NAME="feature/MARP-3334-disable-README_DE-file"
PR_TITLE="MARP-3334: Add CODEOWNERS to disable README_DE.md"

enableBranchProtection() {
  repo_name=$1
  branch=$2

  echo "Enabling branch protection for $branch in $repo_name..."
  gh api -X PUT "repos/${org}/${repo_name}/branches/${branch}/protection" \
    --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["prevent-modification"]
  },
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "enforce_admins": false,
  "restrictions": null
}
JSON

  if [ $? -eq 0 ]; then
    echo "✓ Branch protection enabled successfully"
  else
    echo "⚠ Failed to enable branch protection (may require admin permissions)"
  fi
}

updateCodeOwnerViaPullRequest() {
  repo_name=$1
  git clone "https://github.com/${org}/${repo_name}.git"
  cd "${repo_name}"

  # Checkout new branch
  if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
    echo "⚠ Branch $BRANCH_NAME already exists in $repo_name"
    git checkout "$BRANCH_NAME"
  else
    git checkout -b "$BRANCH_NAME"
  fi

  changes_made=false
  mkdir -p .github
  if [ -f "${CODEOWNERS_FILE}" ]; then
    if ! grep -q "README_DE.md" "${CODEOWNERS_FILE}"; then
      echo "✓ Adding README_DE.md to existing CODEOWNERS"
      printf "\n${CODEOWNERS_RULE}\n" >> "${CODEOWNERS_FILE}"
      changes_made=true
    else
      echo "⚠ README_DE.md already in CODEOWNERS"
    fi
  else
    echo "✓ Creating new CODEOWNERS file"
    cat > "${CODEOWNERS_FILE}" << EOF
${CODEOWNERS_RULE}
EOF
    changes_made=true
  fi

  # Commit and push changes
  if [ "$changes_made" = true ]; then
    git add "${CODEOWNERS_FILE}"
    
    if git diff --cached --quiet; then
      echo "No changes to commit for $repo_name"
      cd ..
      rm -rf "${repo_name}"
      return
    fi

    git commit -m "Add CODEOWNERS to disable README_DE.md"

    git push origin "$BRANCH_NAME"

    pr_id=$(gh pr list --head "$BRANCH_NAME" --base master --json number --jq '.[0].number')

    if [ -z "$pr_id" ]; then
      echo "Creating pull request"
      pr_body="This PR adds protection to disable README_DE.md"

      gh pr create --title "$PR_TITLE" --body "$pr_body" --base master --head "$BRANCH_NAME" --reviewer "$REVIEWER"
      echo "✓ Pull request created successfully"
    else
      echo "⚠ Pull request already exists for branch $BRANCH_NAME (PR #$pr_id)"
    fi
    
    # Enable branch protection after PR is created
    cd ..
    enableBranchProtection "$repo_name" "$DEFAULT_BRANCH"
    cd "${repo_name}"
  else
    echo "No changes needed for $repo_name"
  fi

  cd ..
  rm -rf "${repo_name}"
}

main() {
  echo "Working Organization: ${org}"
  echo "Ignored repositories: ${ignored_repos[@]}"
  collectRepos | while read -r repo_name; do
    repo_name=$(echo "$repo_name" | sed 's/\r//g')
    if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
      echo "⚠ Ignoring repo: ${repo_name}"
      continue
    fi
    echo "Processing repo: $repo_name"
    updateCodeOwnerViaPullRequest "$repo_name"
  done
  
}

main
