#!/bin/bash
set -euo pipefail

mkdir -p gitleaks-reports
OUTPUT_CSV="gitleaks-reports/combined-report.csv"

# CSV header
echo "org,repo,rule,file,line,commit,author,date,secret" > "$OUTPUT_CSV"

# Get a list of repositories for a given org
get_repositories_for_org() {
  local org="$1"
  local -n repo_array_ref="$2"

  if [ -n "$REPOS" ]; then
    IFS=',' read -ra repo_array_ref <<< "$REPOS"
  else
    mapfile -t repo_array_ref < <(gh repo list "$org" --limit 1000 --json name -q '.[].name')
  fi
}

# Run Gitleaks scan on a specific repository
scan_repository() {
  local org="$1"
  local repo="$2"

  echo "🚨 Scanning $org/$repo ..."
  rm -rf "$repo"
  if ! git clone "https://x-access-token:${GH_TOKEN}@github.com/$org/$repo.git"; then
    echo "❌ Failed to clone $org/$repo. Skipping..."
    return
  fi

  cd "$repo"
  local temp_json="../gitleaks-reports/tmp-${org}__${repo}.json"

  gitleaks detect --source="." --report-path="$temp_json" \
    --report-format=json --redact || true

  if [ -s "$temp_json" ] && [ "$(jq length "$temp_json")" -gt 0 ]; then
    echo "✅ Secrets found in $org/$repo"
    append_scan_results_to_csv "$org" "$repo" "$temp_json"
  else
    echo "ℹ️ No secrets found in $org/$repo"
  fi

  cd ..
  rm -rf "$repo"
}

# Convert a Gitleaks JSON report into a CSV row and append to output
append_scan_results_to_csv() {
  local org="$1"
  local repo="$2"
  local json_file="$3"

  jq -r --arg org "$org" --arg repo "$repo" '
    .[] | [
      $org,
      $repo,
      .rule,
      .file,
      (.line // 0),
      .commit,
      (.author // "unknown"),
      (.date // ""),
      (.secret // "REDACTED")
    ] | @csv' "$json_file" >> "$OUTPUT_CSV"
}

# Entry point
run_gitleaks_scan() {
  IFS=',' read -ra orgs <<< "$ORGS"

  for org in "${orgs[@]}"; do
    echo "🔍 Fetching repositories for org: $org"
    local repos=()
    get_repositories_for_org "$org" repos
    echo "📦 Found ${#repos[@]} repositories in $org"

    for repo in "${repos[@]}"; do
      scan_repository "$org" "$repo"
    done
  done

  echo "✅ Secret scanning complete! Results saved to $OUTPUT_CSV"
}

run_gitleaks_scan
