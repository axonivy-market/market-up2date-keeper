updateWorkflows() {
  tag="$1"
  for workflow in .github/workflows/*.yml ; do
    echo "updating $workflow"
    sed -i -r "s|(uses: axonivy-market/github-workflows/.github/workflows/.*\.yml)@(v[0-9]+)|\1@${tag}|g" $workflow
  done
}
