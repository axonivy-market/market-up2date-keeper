updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true -DprocessAllModules
}
removeMvnProperty() {
  name="$1"

  # Remove from root pom.xml
  if [ -f "pom.xml" ]; then
    echo "Removing property '$name' from root pom.xml"
    sed -i "/<${name}>.*<\/${name}>/d" pom.xml
  fi

  # Remove from all child pom.xml files
  for d in */ ; do
    if [ -f "${d}pom.xml" ]; then
      echo "Removing property '$name' from ${d}pom.xml"
      sed -i "/<${name}>.*<\/${name}>/d" "${d}pom.xml"
    fi
  done
}

artifactVersion() {
  newVersion="$1"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    removeMvnProperty "project.build.plugin.versions"
    removeMvnProperty "tester.version"
    mvn -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false -DprocessAllModules=true
    mvn -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  fi
  # update version in pom.xml
  # loop through all folders
  for d in */ ; do
    echo "Updating $d"
    mvn -f $d -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false -DprocessAllModules=true
    mvn -f $d -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  done
}
