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
      <groupId>com.axonivy.ivy.api.extension</groupId>
      <artifactId>ivy-rest-jersey-extension-api</artifactId>
    </dependency>
```
Also the `FeatureConfig` utility namespace + factory method has changed: successor is `ch.ivyteam.ivy.rest.client.feature.FeatureConfig.of(Configuration, Class<?>)`

Reference commit: https://github.com/axonivy-market/snowflake-connector/pull/43/changes/920784435880c80985d5139119cedf6b699327ea

##### Program Extension API

**New Artifact**:
The artifact `com.axonivy.ivy.spi:ivy-process-extension-spi` is deprecated and should be replaced.
The successor is `com.axonivy.ivy.api.extension:ivy-process-extension-api`.

Reference commits: 
- https://github.com/axonivy-market/azure-servicebus-connector/pull/22/changes/fe90251522c46a34e6cf291eea801d0e4368b954
- https://github.com/axonivy/doc/commit/5fea93a27118aa3bc89f5c5d6fd8c63ae7edb759

**Runtime classpath**:
Extension bean implementations are not accessible at test-runtime from other projects.
This seems to be a shortcoming of the current project-build-plugin.
As workaround, set the dependency to scope 'compile' in order to wrap it with the main project.

Reference commit:
- https://github.com/axonivy-market/azure-servicebus-connector/pull/22/changes/46024dc900e41bc56f34cadf9ced5662172d75e1

##### DataCache API
The `IDataCache.of(app)` takes no longer `IApplication` as input, but `ch.ivyteam.ivy.application.app.Application` instead.

Reference commit: https://github.com/axonivy-market/kafka-connector/pull/81/changes/4ff0deeb43e66fa0bc887d77fef39a06f7b2c710

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
Check all `.ivyproject` files, especially modules that the automatic migration skipped, and update the project version to the current 14.0 migration level. Skipped projects have a version lower than 140022.

Fix: run the project conversion in vscode. Using the command: `ivyProjects.convertProject`

Reference commits: 
- https://github.com/axonivy-market/deepl-connector/commit/b98ce8c0fa88f26b22439cbdb555f8524748cb90
- https://github.com/axonivy-market/a-trust-connector/pull/113/changes/45a13167833d33a4bf231739450fc719e2268c75

##### XHTML validation warnings

The `xhtml` validator checks every `.xhtml` file under `webContent` and `dialog`. It runs by default. A project can turn it off in its `pom.xml`:

```xml
<excludeValidators>
  <validator>xhtml</validator>
</excludeValidators>
```

To run it anyway for a single build, clear that list:

```
mvnd -pl <module> -am verify -DskipTests -Divy.validation.excludeValidators=
```

Findings are reported as `[WARNING] webContent/…/view.xhtml:[line,column] <message>`. A validator can be silenced for the next element, or for the whole file, by naming it (`el-validator` is the one that checks expressions):

```xml
<!-- disable validator next-line: el-validator -->
<p:inputText value="#{bean.name}" />
```

For the whole file, put `<!-- disable validator: el-validator -->` as a top-level comment, before `<html>`. Keep the scope as narrow as possible.

These are static checks: the validator reads the files, it does not run the page. A warning therefore does not automatically mean the page is broken. Some findings concern code that works at runtime (a variable that only exists at runtime, for example), and some are only about correctness, e.g. an attribute that JSF ignores, where the page behaves the same before and after. Others do point at real problems, so read each finding instead of suppressing it by default.

The list below is not exhaustive; it only contains the warnings we hit in our own projects.

###### `Attribute 'x' is not allowed to appear in element 'y'.`

That attribute does not exist on the JSF component, or its name has the wrong case (JSF attribute names are case-sensitive).

- `escape="false"` on `h:inputTextarea`: `h:inputTextarea` has no `escape` attribute, remove it.
- `onPostBack="false"` on `f:viewAction`: the attribute is named `onPostback`.

Fix by using the component's real attribute name. Do not suppress this warning.

Reference: [remove `escape`](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-4ff6821011205542dfba10b8b48d3aa987844c6fe8eddc8585751d795b408d79R144) · [fix the `onPostback` casing](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-e5daef65e01422aa9a6ba7fbec73b9f785067d674509505a2ed8828fe7238baeR9)

###### `Must have type 'jakarta.el.MethodExpression' but has type 'java.lang.String'`

The attribute expects a method, but the expression resolves to a `String`. Example: `globalFilterFunction="#{threadBean.filter}"` on a bean that has both a `filter` property (getter) and a `filter(…)` method, where the property was used instead of the method.

Rename the method so no property uses its name, e.g. `filter(…)` to `globalFilterFunction(…)`, and reference `#{threadBean.globalFilterFunction}`.

Reference: [rename the method](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-5f636daa442f6d4f25fe09a98d44f2485a018f9e55a58a745a80aa2ef23fd4a9R116) · [use the new name in the view](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-99f1c583a39d58a6330aece58404e849950d70233c19b988e0b32a4c94e269c0R43)

###### `Must have type 'java.lang.Object' but has type 'void'`

An untyped composite component attribute is treated as a value attribute. Passing a `void` method invocation to it is therefore invalid. Do not suppress this warning.

If the callback is part of the composite component's contract, declare it as a method attribute and bind it to the server-side component action or behavior that must invoke it:

```xml
<cc:attribute name="callback" method-signature="void callback()" required="true" />

<p:commandButton action="#{cc.attrs.callback}" />
```

Pass the method expression without invoking it:

```xml
<cc:Example callback="#{bean.callback}" />
```

If the method belongs to the caller's own action instead, invoke it directly from that action and remove the composite callback attribute. Do not add a callback or bind it to a different lifecycle event merely to silence the validator.

Do not interpolate a callback into client-side JavaScript such as `onclick="#{cc.attrs.callback}"`. That evaluates the expression while rendering the page instead of wiring a server-side callback to the browser event.

###### `Attribute or method 'x' not found`

- The expression is evaluated against a supertype that does not declare the member. Example: a table bound to `AbstractPermission` reads `#{permission.permissionHolder}`, but `getPermissionHolder()` was only declared on `Permission`. Declare it on the base type (`public abstract String getPermissionHolder();`) and implement it in every subclass.
- If the member intentionally exists only on specific runtime implementations, expose it as a separate typed composite attribute and pass it explicitly from the applicable callers. Do not access a subtype-only member through an attribute declared as the broader type.
- A `Map` is iterated directly and its entries are read as `.key` / `.value`. Iterate the entry set instead, so each row is a `Map.Entry`: `value="#{bean.additionalProperties.entrySet()}"`.

Reference: [declare `getPermissionHolder()` on the base type](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-5fa0c26ca2d76149144865c1d71706de2cef3507397e79eb28cf95b636fbaf9fR139) · [pass a subtype-only property explicitly](https://github.com/axonivy/engine-cockpit/commit/1587c950c6d0f2d1f9aa764e89096c746c11f426) · [iterate `entrySet()`](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-07f899719637b3ba36753b23ef0a16d027716c3f632d61e4cf807a81036856f6R131)

###### `Managed bean or local variable 'x' not found`

The variable is provided by a surrounding composite component, for example the `app` variable of `cc:ApplicationTabs`. The validator does not know such variables and reports them as missing. Suppress just those expressions:

```xml
<!-- disable validator next-line: el-validator -->
<p:dataTable widgetVar="table_#{app.id()}">
```

Reference: [databases.xhtml](https://github.com/axonivy/engine-cockpit/pull/2088/files#diff-7e80a35e4837908aa78315132c922544de978180c70ba5886fb53f50f1fdfb20R31) · [webservices.xhtml](https://github.com/axonivy/engine-cockpit/pull/2088/files#diff-37b9edc97d23882192ce20c3ea62a90174d31682d1e8ba6c57281e8f54a2d9e8R27) · [restclients.xhtml](https://github.com/axonivy/engine-cockpit/pull/2093/files#diff-152eb7b9495e2a7ec81c9b5f90484d65baa3463406fc75308ca7384e9bd14858R27)

###### Known validator limitations

The XHTML validator is being actively improved. Re-run the validator with the current product version before relying on this list: an entry may already be fixed by the time you read it. The remaining warnings below come from the validator, not from the project. Keep them visible until the validator is fixed; do not change or suppress valid XHTML solely to silence them.

- Java keywords used with dot access, such as `#{cc.attrs.for}`. Axon Ivy deliberately sets `org.apache.el.parser.SKIP_IDENTIFIER_CHECK=true` at runtime to support identifiers such as `case`. The static validator does not currently mirror that runtime configuration and reports a parse warning for expressions that work in the product.
- `rendered` on composite components (`cc:*`). Workaround that was applied: [ui:fragment wrapper](https://github.com/axonivy/engine-cockpit/pull/2129/files#diff-faf381b4fc21927728336ba13fe091fbcc30d5c41862491d448b3aa243bc1aeeR87)
- `empty` / `not empty` applied to a value whose type is not a `String`, array, `Map`, or `Collection`. The validator rejects this, but the [Jakarta EL specification](https://jakarta.ee/specifications/expression-language/6.0/jakarta-expression-language-spec-6.0#empty-operator-empty-a) defines `empty` as `true` for `null` and `false` for every other value of such a type. Therefore, `not empty date` works as a null check. No correctness fix is required; `date ne null` is an equivalent, clearer expression. Example: [use an explicit null check](https://github.com/axonivy/engine-cockpit/commit/628e3d632a557ff269f54715b135e30aa7655f49)
- Conditional operator branches with different static types. The validator requires both branches of `condition ? valueIfTrue : valueIfFalse` to have the same type, but the [Jakarta EL specification](https://jakarta.ee/specifications/expression-language/6.0/jakarta-expression-language-spec-6.0#conditional-operator-a-b-c) evaluates and returns only the selected branch without this restriction. If the receiving attribute accepts both types, the expression is valid. Example: [a `String` or `Object` passed to `h:outputText`](https://github.com/axonivy/engine-cockpit/commit/ea268bc629c3c075813b09aed85bb2ae7da58d80)
