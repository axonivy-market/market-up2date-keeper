updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true -DprocessAllModules
}

artifactVersion() {
  newVersion="$1"
  oldVersion=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout 2>/dev/null)
  echo "Updating maven version from ${oldVersion} to ${newVersion}"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    mvn -B versions:set -DoldVersion=${oldVersion} -DnewVersion=${newVersion} -DgenerateBackupPoms=false -DprocessAllModules=true
  fi
}
