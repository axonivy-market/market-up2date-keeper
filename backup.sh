#!/bin/bash
set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${DIR}/repo-collector.sh"

backupDir="${DIR}/target/backup/${org}"
mkdir -p "${backupDir}"
cd "${backupDir}"

ignore=(
  "ivyai-knowledge-pipeline"
)

backup() {
  local repo_name="${1}"
	local repo_url="https://github.com/${org}/${repo_name}.git"
	local mirror_dir="${repo_name}.git"

	if [ -d "${mirror_dir}" ]; then
		echo "Updating mirror ${org}/${repo_name}"
		git -C "${mirror_dir}" remote update --prune
	else
		echo "Cloning mirror ${org}/${repo_name}"
		git clone --mirror "${repo_url}"
	fi
}

collectAllRepos | while read -r repo_name; do
	if [[ " ${ignore[*]} " =~ " ${repo_name} " ]]; then
		echo "Ignoring repo ${repo_name}"
		continue
	fi
  backup "${repo_name}"
done
