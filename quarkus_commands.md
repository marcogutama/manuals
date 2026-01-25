# Quarkus CLI & Maven Cheatsheet

Quarkus command-line interface (CLI) and Maven commands provide essential tools for project generation, development, building, and running applications.

---

## 1. Project Setup and Management

| Function | Maven Command (using `./mvnw`) | Quarkus CLI Command |
| --- | --- | --- |
| **Generate a new project** | `./mvnw io.quarkus:quarkus-maven-plugin:create` | `quarkus create app org.acme:getting-started` |
| **Add an extension** | `./mvnw quarkus:add-extension -Dextensions="[extension-name]"` | `quarkus ext add [extension-name]` |
| **Remove an extension** | `./mvnw quarkus:remove-extension -Dextensions="[extension-name]"` | `quarkus ext rm [extension-name]` |
| **List all extensions** | `./mvnw quarkus:list-extensions` | `quarkus ext list` |
| **Update Quarkus version** | `./mvnw quarkus:update` | `quarkus update` |

---

## 2. Development and Running Applications

| Function | Maven Command | Quarkus CLI Command |
| --- | --- | --- |
| **Run in development mode** | `./mvnw quarkus:dev` | `quarkus dev` |
| **Run in continuous testing** | `./mvnw quarkus:test` | `quarkus test` |
| **Enable remote dev mode** | `./mvnw quarkus:remote-dev` | `quarkus remote-dev` |
| **Run the packaged app** | `java -jar target/*-runner.jar` | `java -jar target/*-runner.jar` |

---

## 3. Building and Packaging

| Function | Maven Command | Quarkus CLI Command |
| --- | --- | --- |
| **Build the application** | `./mvnw clean package` | `quarkus build` |
| **Build a native executable** | `./mvnw clean package -Pnative` | `quarkus build --native` |
| **Build native via container** | `./mvnw clean package -Pnative -Dquarkus.native.container-build=true` | `quarkus build --native -Dquarkus.native.container-build=true` |

---

> For more detailed guides and documentation, refer to the official [Quarkus website](https://quarkus.io).