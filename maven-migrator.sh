updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true -DprocessAllModules
}

artifactVersion() {
  newVersion="$1"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    mvn -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false -DprocessAllModules=true
    mvn -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  fi
}
