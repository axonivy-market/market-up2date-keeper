updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true -DprocessAllModules
}

artifactVersion() {
  newVersion="$1"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    echo "Updating artifact version to ${newVersion}"
    mvn -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false -DprocessAllModules=true
    echo "Updating dependencies to latest versions"
    mvn -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  fi
}
