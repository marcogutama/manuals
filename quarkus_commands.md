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

Ejemplo: `quarkus create app ec.fin.baustro:servicing-appsecuritymgmt --extension quarkus-rest --no-code`

### ⚠️ Convención de nombres para el artifactId

Según la convención oficial de Maven, el `artifactId` debe seguir estas reglas:

| Regla | Correcto ✅ | Incorrecto ❌ |
| --- | --- | --- |
| Solo minúsculas | `whatsapp-delivery-consumer` | `WhatsAppDeliveryConsumer` |
| Palabras separadas por guiones (`-`) | `user-management-service` | `userManagementService` |
| Sin guiones bajos | `payment-gateway` | `payment_gateway` |
| Sin versiones en el nombre | `report-generator` | `report-generator-v2` |

> **Nota:** El `artifactId` se convierte en el nombre del JAR generado y del directorio del proyecto.
> El nombre en PascalCase/camelCase se reserva para las **clases Java** dentro del proyecto.
>
> ```bash
> # ❌ Evitar
> quarkus create app ec.fin.baustro:WhatsAppDeliveryConsumer --extension quarkus-rest --no-code
>
> # ✅ Correcto
> quarkus create app ec.fin.baustro:whatsapp-delivery-consumer --extension quarkus-rest --no-code
> ```

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

### 4. Generar Uber-JAR (todo en uno)
Genera un único JAR en target/ con todo incluido.
```
./mvnw package -Dquarkus.package.jar.type=uber-jar
```

> For more detailed guides and documentation, refer to the official [Quarkus website](https://quarkus.io).