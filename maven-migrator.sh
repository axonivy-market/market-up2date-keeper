updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true
}

updateBuildPluginVersion() {
  pluginVersion="$1"
   if [ -n "$pluginVersion" ]; then
    echo "Updating build plugin version to ${pluginVersion}"
    updateMvnProperty "project.build.plugin.version" $pluginVersion
  fi
}

updateTesterVersion() {
  testerVersion="$1"
   if [ -n "$testerVersion" ]; then
    echo "Updating tester version to ${testerVersion}"
    updateMvnProperty "tester.version" $testerVersion
  fi
}

artifactVersion() {
  newVersion="$1"
  buildPluginVersion="$2"
  testerVersion="$3"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    updateBuildPluginVersion $buildPluginVersion
    updateTesterVersion $testerVersion
    mvn -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false
    mvn -B versions:use-latest-versions -DgenerateBackupPoms=false
  fi
  # update version in pom.xml
  # loop through all folders
  for d in */ ; do
    echo "Updating $d"
    updateBuildPluginVersion $buildPluginVersion
    updateTesterVersion $testerVersion
    mvn -f $d -B versions:set -DnewVersion=${newVersion} -DgenerateBackupPoms=false
    mvn -f $d -B versions:use-latest-versions -DgenerateBackupPoms=false
  done
}
