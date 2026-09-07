#!/bin/bash

set -o pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
. "${DIR}/../repo-collector.sh"

target_branch="${TARGET_BRANCH:-dev/14.0}"
workflow_file="${WORKFLOW_FILE:-release-dev.yml}"
dry_run="${DRY_RUN:-false}"
log_dir="${LOG_DIR:-${DIR}/../target}"

mkdir -p "${log_dir}"
log_file="${log_dir}/release-dev-dev-14-dispatch-$(date +%Y%m%d-%H%M%S).log"

log() {
	printf '%s\n' "$1" | tee -a "${log_file}"
}

repo_has_branch() {
	gh api --silent "repos/${org}/$1/git/ref/heads/${target_branch}" >/dev/null 2>&1
}

repo_has_workflow() {
	gh api --method GET "repos/${org}/$1/contents/.github/workflows/${workflow_file}" -f "ref=${target_branch}" >/dev/null 2>&1
}

dispatch_workflow() {
	gh workflow run "${workflow_file}" -R "${org}/$1" --ref "${target_branch}" -f "dryRun=${dry_run}" >>"${log_file}" 2>&1
}

process_repo() {
	repo_name=$(echo "$1" | sed 's/\r//g')

	if [[ -z "${repo_name}" ]]; then
		return
	fi
	if [[ " ${ignored_repos[@]} " =~ " ${repo_name} " ]]; then
		log "SKIP ignored ${repo_name}"
		return
	fi
	if ! repo_has_branch "${repo_name}"; then
		log "SKIP no-branch ${repo_name}"
		return
	fi
	if ! repo_has_workflow "${repo_name}"; then
		log "SKIP no-workflow ${repo_name}"
		return
	fi
	if dispatch_workflow "${repo_name}"; then
		log "TRIGGERED ${repo_name}"
	else
		log "FAILED ${repo_name}"
	fi
}

print_summary() {
	printf '\nSummary from log:\n'
	awk '
		/^TRIGGERED / {triggered++}
		/^FAILED / {failed++}
		/^SKIP ignored / {ignored++}
		/^SKIP no-branch / {nobranch++}
		/^SKIP no-workflow / {noworkflow++}
		END {
			printf "triggered=%d\nfailed=%d\nskipped_ignored=%d\nskipped_no_branch=%d\nskipped_no_workflow=%d\n", triggered, failed, ignored, nobranch, noworkflow
		}
	' "${log_file}"
	printf 'Log written to %s\n' "${log_file}"
}

main() {
	log "Dispatching ${workflow_file} on ${target_branch} with dryRun=${dry_run}"
	log "Log: ${log_file}"

	collectRepos | while read -r repo_name; do
		process_repo "${repo_name}"
	done

	print_summary
}

main "$@"
