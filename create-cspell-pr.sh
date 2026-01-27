#!/bin/bash
set -e

ORG="tvtphuc-axonivy"
BASE_DIR="$(pwd)/repos"
BRANCH_NAME="feature/MARP-3642-How-to-handle-spelling-errors"
COMMIT_MSG="Add cspell configuration and update CI workflow"
PR_TITLE="MARP-3642 Add cspell configuration and update CI workflow"
PR_BODY="This PR adds cspell.json to the repository root and updates CI-Build to use the internal github-workflows with cspell support."

WORKFLOW_FILE=".github/workflows/ci.yml"

mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

echo "Fetching repositories from org: $ORG"

repos=$(gh repo list "$ORG" --limit 200 --json name -q '.[].name')

for repo in $repos; do
  echo "===================================="
  echo "Processing repo: $repo"

  if [ ! -d "$repo" ]; then
    gh repo clone "$ORG/$repo"
  fi

  cd "$repo"

  DEFAULT_BRANCH="master"
  git checkout "$DEFAULT_BRANCH"
  git pull origin "$DEFAULT_BRANCH"

  # Skip if workflow file does not exist
  if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "CI workflow not found → skip repo"
    cd ..
    continue
  fi

  # --------------------------------
  # Skip if branch already exists on remote
  # --------------------------------
  if git ls-remote --exit-code --heads origin "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Branch '$BRANCH_NAME' already exists → skip repo"
    cd ..
    continue
  fi

  git checkout -B "$BRANCH_NAME"

  # -------------------------
  # Create cspell.json (root)
  # -------------------------
  if [ ! -f "cspell.json" ]; then
    cat > cspell.json << 'EOF'
{
  "version": "0.2",
  "files": [
    "**/*.md",
    "**/*_en.yaml",
    "**/variables.yaml",
    "**/*.xhtml"
  ],
  "ignorePaths": [
    "**/*_de.md",
    "**/*_DE.md",
    "**/webContent/layouts/frame*.xhtml",
    "**/webContent/layouts/basic*.xhtml",
    "**/webContent/layouts/includes/*.xhtml"
  ],
  "words": [
    "AxonIvy", "axonactive", "ivy", "ivyteam", "wawa", "Up2date",
    "e2e", "panelgrid", "toggleable", "orderlist", "tablewrapper",
    "hoverable", "gridlines", "formgrid", "maxdate", "mindate",
    "chkbox", "confirmdialog", "maximizable", "outputlabel",
    "webcontent", "Unsorting", "nogutter", "navicon", "HANA",
    "Recordset", "Recordsets", "fileref", "newkey", "keyout", "inkey",
    "primeflex", "primefaces", "dynaForm", "dyna",
    "Startable", "caseprocessviewer", "EMLX", "webservice", "apikey",
    "Successfactors", "statefuldatatable", "datatable", "Keypair",
    "azureopenai", "rebex", "sshkey", "Keyphrase", "sshpassphrase",
    "chartjs", "datalabels", "masterdetail", "Weblate", "XOAUTH", "sasl",
    "imap", "imaps", "clazz", "daemonless", "npipe", "glassfish", "HSQL",
    "hsqldb", "chatbots", "SOQL"
  ]
}
EOF
  fi

  # --------------------------------
  # Update CI-Build workflow
  # --------------------------------
  sed -i.bak \
    's|uses: axonivy-market/github-workflows/.github/workflows/ci.yml@.*|uses: tvtphuc-axonivy/github-workflows/.github/workflows/ci.yml@feature\/MARP-3642-How-to-handle-spelling-errors|' \
    "$WORKFLOW_FILE"

  # Inject `with:` block after uses
  sed -i.bak '/uses: tvtphuc-axonivy\/github-workflows\/.github\/workflows\/ci.yml@feature\/MARP-3642-How-to-handle-spelling-errors/a\
    with:\
      cspellConfig: cspell.json' "$WORKFLOW_FILE"

  rm -f "$WORKFLOW_FILE.bak"

  git add cspell.json "$WORKFLOW_FILE"
  git commit -m "$COMMIT_MSG"
  git push -u origin "$BRANCH_NAME"

  gh pr create \
    --repo "$ORG/$repo" \
    --title "$PR_TITLE" \
    --body "$PR_BODY" \
    --base "$DEFAULT_BRANCH" \
    --head "$BRANCH_NAME"

  cd ..
done

echo "✅ All PRs created successfully"
