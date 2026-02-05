DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Define branch and PR details
BRANCH="feature/MARP-3642-How-to-handle-spelling-errors"
TITLE="MARP-3642 Add cspell configuration and update CI workflow"
BODY="MARP-3642 This PR adds cspell.json to the repository root and updates CI-Build to use the internal github-workflows with cspell support."

# Source shared functions AFTER defining required variables
source "$DIR/repo-changer.sh"

WORKFLOW_FILE=".github/workflows/ci.yml"

# Change action function
addCspellConfiguration() {
  local repo_name="$1"
  
  # Skip if workflow file does not exist
  if [ ! -f "$WORKFLOW_FILE" ]; then
    echo "CI workflow not found → skip repo"
    return
  fi


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

  # Inject `with:` block after uses
  sed -i.bak '/uses: axonivy-market\/github-workflows\/.github\/workflows\/ci.yml@v6/a\
    with:\
      cspellConfig: cspell.json' "$WORKFLOW_FILE"

  rm -f "$WORKFLOW_FILE.bak"
}

# Execute the change on all repos
changeRepos "addCspellConfiguration"

echo "✅ All PRs created successfully"
