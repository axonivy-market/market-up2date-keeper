updateMvnProperty() {
  name="$1"
  value="$2"
  mvn -B versions:set-property versions:commit "-Dproperty=${name}" "-DnewVersion=${value}" -DallowSnapshots=true -DprocessAllModules
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

currentVersion() {
  local pomDir="${1:-.}"
  mvn -f "$pomDir" -q -DforceStdout -Dexpression=project.version --non-recursive help:evaluate 2>/dev/null
}

artifactVersion() {
  newVersion="$1"
  buildPluginVersion="$2"
  testerVersion="$3"
  # if root pom.xml exists
  if [ -f "pom.xml" ]; then
    updateBuildPluginVersion $buildPluginVersion
    oldVersion=$(currentVersion .)
    mvn -B versions:set "-DnewVersion=${newVersion}" "-DoldVersion=${oldVersion}" -DgenerateBackupPoms=false -DprocessAllModules=true
    mvn -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  fi
  # update version in pom.xml
  # loop through all folders
  for d in */ ; do
    echo "Updating $d"
    updateBuildPluginVersion $buildPluginVersion
    updateTesterVersion $testerVersion
    oldVersion=$(currentVersion "$d")
    mvn -f "$d" -B versions:set "-DnewVersion=${newVersion}" "-DoldVersion=${oldVersion}" -DgenerateBackupPoms=false -DprocessAllModules=true
    mvn -f "$d" -B versions:use-latest-versions -DgenerateBackupPoms=false -DprocessAllModules
  done
}
