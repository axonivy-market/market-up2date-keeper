# Migrating to 14.0.0-m33

Migrating market products on dev/14.0.0 to the latest milestone 14.0.0-m33-SNAPSHOT.

## Automated
Most migration steps are done automatically, but running the raise-all-market-products.sh pipeline. 

> ⚠️ Please do not run project conversion by other means. Automatic changes are easier to review and to be trusted.

## Manual changes

Some steps have to be applied manually. Here we collect prominent changes for Market maintainers and AI agents.

### Reference PRs

- https://github.com/axonivy-market/case-mail-component-utils/pull/47
- https://github.com/axonivy-market/doc-factory/pull/410
- https://github.com/axonivy-market/deepl-connector/pull/114
- https://github.com/axonivy-market/kafka-connector/pull/81
- https://github.com/axonivy-market/persistence-utils/pull/151
- https://github.com/axonivy-market/db-utils/pull/71
- https://github.com/axonivy-market/snowflake-connector/pull/42
- https://github.com/axonivy-market/coffee-machine-connector/pull/28
- https://github.com/axonivy-market/msgraph-connector/pull/176
- https://github.com/axonivy-market/portal/pull/3604

### What to change

#### Libraries

##### BeanUtils2
Replace `commons-beanutils:commons-beanutils` with `org.apache.commons:commons-beanutils2` in pom.xml and update imports from `org.apache.commons.beanutils.*` to `org.apache.commons.beanutils2.*`..

Reference commit: https://github.com/axonivy-market/persistence-utils/commit/0592d9c6bae75ef13f0795519e8c38f3618294e0

##### Collections4
Replace old Commons Collections imports like `org.apache.commons.collections.CollectionUtils` with the Commons Collections 4 package `org.apache.commons.collections4.CollectionUtils`.

Reference commit: https://github.com/axonivy-market/case-mail-component-utils/commit/a595d1b723ceab938c629b39586a25000ff2661a


##### Jackson3
Migrate Jackson usages from `com.fasterxml.jackson.*` to the Jackson 3 packages, for example `tools.jackson.databind.JsonNode`, and update API calls such as `asText()` to `asString()` where needed.

Reference commit: https://github.com/axonivy-market/msgraph-connector/commit/6a95fb7a382995be9530f0e8077ecd03cd651c9c

##### Jakarta REST types
Replace remaining `javax.ws.rs.*` types in process data, generated REST client metadata, and Java sources with the corresponding `jakarta.ws.rs.*` types.

Reference commit: https://github.com/axonivy-market/deepl-connector/commit/9015867dcea6d82240814b2d87bf1a8bc2e06510

##### JacksonJsonProvider
Migrate `com.fasterxml.jackson.jakarta.rs.json.JacksonJsonProvider`, to fix errors like:
```
The method configure(tools.jackson.jakarta.rs.json.JacksonJsonProvider, jakarta.ws.rs.core.Configuration) in the type ch.ivyteam.ivy.rest.client.mapper.JsonFeature is not applicable for the arguments (com.fasterxml.jackson.jakarta.rs.json.JacksonJsonProvider, jakarta.ws.rs.core.Configuration)
```

Reference commit: https://github.com/axonivy-market/a-trust-connector/pull/113/changes/3bd51b9b6dd996cc91101ea9f3a934182f0cdfae

#### High Priority

##### Request API
`ch.ivyteam.ivy.request.IProcessModelVersionRequest` was renamed to `ch.ivyteam.ivy.request.ProjectRequest`

Reference commit: https://github.com/axonivy-market/portal/commit/49372388fd9feb34f52b931b5f2e0e2b2fda6109

##### OAuth2 Dependency
All rest-client connectors that implement an OAuth2 Flow need an additonal dependency in the pom.xml:

```xml
    <dependency>
      <groupId>com.axonivy.ivy.spi</groupId>
      <artifactId>ivy-rest-jersey-spi</artifactId>
    </dependency>
```

Reference commit: https://github.com/axonivy-market/S4HANA-connector/pull/33/changes/f9f8c666896a802452b8c065a087c72854f38c0a

##### REST client test config
Do not override REST clients in tests through `IApplication`, `RestClients.of(app)`, or `RestClient.toBuilder()`. Configure the test REST client through `AppFixture.config(...)`, including URL, features, and authentication properties.

Reference commit: https://github.com/axonivy-market/deepl-connector/commit/27295f83fa1743d03b569731a79f4ea912675003

##### Build plugin properties
Remove obsolete `project.build.plugin.version` properties from module POMs. Also drop stale tester/build plugin version properties when the parent now manages them.

Reference commit: https://github.com/axonivy-market/deepl-connector/commit/66b295bc7179f12d9516ce798b45a3c02289c28f

##### Generated REST sources
Remove custom `build-helper-maven-plugin` executions that add `src_generated/rest/...` as a source folder. Generated REST sources are now handled by the project build plugin.

Reference commit: https://github.com/axonivy-market/deepl-connector/commit/7039b6ff9553c4c27a108ee8c78fbcf5bc9bc5d5


#### Low Priority

##### Java warnings
Fix warnings that fail the pipeline: remove unused imports, inline Javadoc-only imports, and replace unused lambda parameters with `_` where the current Java level allows it.

Reference commit: https://github.com/axonivy-market/msgraph-connector/commit/7c533c7c10d1ac5cc2ba07895adf8d8d244c5f5f

##### Ivy project version
Check all `.ivyproject` files, especially modules that the automatic migration skipped, and update the project version to the current 14.0 migration level.

Reference commit: https://github.com/axonivy-market/deepl-connector/commit/b98ce8c0fa88f26b22439cbdb555f8524748cb90
