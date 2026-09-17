---
name: quarkus-microservice-scaffold
description: Crea un microservicio Quarkus nuevo desde cero conforme al estándar corporativo, o valida que uno existente tenga la estructura completa. Cubre el comando quarkus create app con sus extensiones, la convención de nombres del artifactId, elección de arquitectura (capas vs hexagonal), estructura de paquetes, clases base obligatorias, asignación de puerto desde el inventario PORT_MANAGEMENT.md, organización de application.properties, y el checklist completo de arranque. Úsalo cuando el usuario pida crear un microservicio nuevo, hacer scaffolding, elegir el nombre de un proyecto Quarkus, o verificar que un proyecto cumple con la estructura estándar.
---

# Scaffolding de Microservicio Quarkus

Stack: Quarkus 3.x · Mutiny · MicroProfile · Jakarta EE · Java 25 · despliegue en OpenShift.

## Ubicación de los documentos de referencia

Los documentos viven **fuera** del repositorio del microservicio, en el directorio de estándares:

```
/home/marco/Documents/manuals/microservicios/
├── microservices-ai-rules.md          # norma canónica
├── PORT_MANAGEMENT.md                 # inventario de puertos — leer y actualizar
├── RESPONSE_CODES.md                  # catálogo de codRespuesta
└── AGENTS.template.md                 # plantilla de AGENTS.md del repo
```

Léelos con rutas absolutas: `/home/marco/Documents/manuals/microservicios/PORT_MANAGEMENT.md`. **No** los
copies al repositorio del microservicio: son inventarios compartidos y una copia local deriva de inmediato.

Leer fuera del proyecto puede pedir confirmación de permiso (`external_directory`). Si se deniega, pregunta al
usuario el puerto a usar en lugar de inventarlo, y avísale que `PORT_MANAGEMENT.md` queda sin actualizar.

## Antes de escribir código

1. **Leer `/home/marco/Documents/manuals/microservicios/PORT_MANAGEMENT.md`** y elegir un puerto libre del rango del tipo de
   servicio (80xx simuladores/workers, 15xxx core/utility, 16xxx dominio, 17xxx agregadores, 18xxx adaptadores,
   28xxx orquestadores L1, 29xxx orquestadores L2/BFF). **Actualizar el inventario en el mismo PR**, no después:
   los conflictos que ya existen en ese archivo son consecuencia de actualizarlo tarde.
2. **Leer `/home/marco/Documents/manuals/microservicios/RESPONSE_CODES.md`** para el enum `ResponseCode`. No inventar códigos.
3. **Decidir el nombre** con la convención de la sección siguiente.
4. **Decidir la arquitectura** con el criterio de abajo. Sobre-arquitecturar un CRUD con hexagonal es tan
   perjudicial como no arquitecturar un dominio complejo.

## Comando de creación

```bash
quarkus create app ec.fin.baustro:<artifact-id> --extension quarkus-rest --no-code
```

- `--no-code` es **obligatorio**: el código de ejemplo que genera Quarkus (`GreetingResource`) incumple el
  estándar y hay que borrarlo. Mejor no generarlo.
- `quarkus-rest` es RESTEasy Reactive, la extensión correcta. **No** usar `quarkus-resteasy` (clásico,
  bloqueante): rompe el requisito reactivo de la sección 1 de la norma.
- Ejecutar el comando **en el directorio padre**: crea una carpeta con el nombre del `artifactId`.

Alternativa con Maven si el CLI de Quarkus no está disponible:

```bash
mvn io.quarkus.platform:quarkus-maven-plugin:create \
  -DprojectGroupId=ec.fin.baustro \
  -DprojectArtifactId=<artifact-id> \
  -Dextensions=quarkus-rest \
  -DnoCode
```

### Extensiones al crear

Añadir de entrada las que el estándar exige, para no tener que agregarlas después:

```bash
# Servicio REST base (siempre)
--extension quarkus-rest,quarkus-rest-jackson,quarkus-smallrye-health,quarkus-smallrye-openapi,quarkus-hibernate-validator

# Si consume o publica en colas
--extension quarkus-smallrye-reactive-messaging-amqp

# Si llama a otros servicios (obliga a fault tolerance, sección 20)
--extension quarkus-rest-client,quarkus-rest-client-jackson,quarkus-smallrye-fault-tolerance

# Si requiere autenticación JWT (sección 17.2)
--extension quarkus-smallrye-jwt,quarkus-security
```

`quarkus-smallrye-health` es obligatorio en todo servicio: la norma prohíbe un `HealthController` manual.

### Convención del `artifactId`

El `artifactId` se convierte en el nombre del JAR y del directorio del proyecto. Reglas de Maven:

| Regla | Correcto | Incorrecto |
|---|---|---|
| Solo minúsculas | `whatsapp-delivery-consumer` | `WhatsAppDeliveryConsumer` |
| Palabras separadas por guiones | `user-management-service` | `userManagementService` |
| Sin guiones bajos | `payment-gateway` | `payment_gateway` |
| Sin versión en el nombre | `report-generator` | `report-generator-v2` |

```bash
# ❌ Evitar
quarkus create app ec.fin.baustro:WhatsAppDeliveryConsumer --extension quarkus-rest --no-code

# ✅ Correcto
quarkus create app ec.fin.baustro:whatsapp-delivery-consumer --extension quarkus-rest --no-code
```

PascalCase y camelCase se reservan para las **clases Java** dentro del proyecto (sección 16 de la norma).

El `groupId` es siempre `ec.fin.baustro`, y el paquete base resultante es `ec.fin.baustro.<dominio>`.

### Después de crear

Quarkus genera un proyecto que aún no cumple el estándar. Ajustes inmediatos:

1. **Java 25** en el `pom.xml` (`maven.compiler.release`): el arquetipo suele fijar 17 o 21.
2. **`%dev.quarkus.http.port`** con el puerto del inventario.
3. **Borrar** `src/main/resources/META-INF/resources/index.html` si se generó.
4. **`.gitignore`** — verificar que incluya `target/`.
5. Añadir las dependencias de test y el `jacoco-maven-plugin` con el gate (skill `quarkus-testing`).
6. Crear el `AGENTS.md` del repositorio desde
   `/home/marco/Documents/manuals/microservicios/AGENTS.template.md`.
7. Verificar que arranca: `./mvnw quarkus:dev` con el `JAVA_HOME` de Java 25.

## Elección de arquitectura

| Característica del servicio | Arquitectura |
|---|---|
| CRUD simple, gateway u orquestador | **Capas (Layered)** — default |
| Reglas de negocio complejas e intercambiables | Hexagonal |
| Equipo grande, features independientes | Clean / Vertical Slices |
| Nuevo sin dominio definido aún | Capas, migrar si crece |

### Capas (recomendada por defecto)

```
ec.fin.baustro.servicio
├── resource     # Controladores REST (JAX-RS)
├── service      # Lógica de negocio y orquestación
├── client       # Clientes REST externos (@RegisterRestClient)
├── dto          # DTOs de entrada y salida + ApiResponse
├── exception    # Excepciones de dominio y ExceptionMappers
├── enums        # Enumeraciones de dominio
├── filter       # CorrelationFilter, CorrelationClientFilter
└── util         # CorrelationContext, LogSanitizer, ResponseCode, StringUtils
```

### Hexagonal

```
├── api            # controller + dto
├── application    # casos de uso
├── domain         # model + port + exception
└── infrastructure # persistence + client
```

`ResponseCode` va en un paquete **neutral** (`util`/`common`), nunca en `resource`: lo consumen dominio,
adaptadores y REST por igual, y ubicarlo en presentación crea una dependencia inversa.

## Clases base obligatorias

| Clase | Propósito | Skill de detalle |
|---|---|---|
| `util/CorrelationContext` | Claves MDC y su ciclo de vida | `quarkus-logging-audit` |
| `util/Outcome` | Enum `SUCCESS`/`FAILURE`/`DENIED` | `quarkus-logging-audit` |
| `util/LogSanitizer` | Enmascarado de PAN + anti log-injection | `quarkus-logging-audit` |
| `util/ResponseCode` | Códigos de negocio del catálogo | `quarkus-rest-contract` |
| `filter/CorrelationFilter` | Siembra el MDC en el borde HTTP | `quarkus-logging-audit` |
| `filter/CorrelationClientFilter` | Propaga `X-Correlation-Id` saliente | `quarkus-logging-audit` |
| `service/AuditLogger` | Eventos de auditoría, categoría `audit` | `quarkus-logging-audit` |
| `dto/ApiResponse<T>` | Único envoltorio de respuesta | `quarkus-rest-contract` |
| `exception/GlobalExceptionMapper` | Mapper genérico sobre `Throwable` | `quarkus-rest-contract` |
| `exception/ValidationExceptionMapper` | Estructura propia de `violations` | `quarkus-rest-contract` |

## Reglas transversales

- **Reactivo end-to-end.** Todo retorna `Uni<T>`/`Multi<T>`. Prohibido `await()` en producción.
- **Recursos JAX-RS sin scope CDI.** `@ApplicationScoped` en un recurso rompe `@Valid`.
- **Inyección por constructor** en todas las clases. Prohibido `@Inject` en campos. Con un único constructor,
  `@Inject` es opcional en Quarkus CDI: se omite.
- **Nombres de clases en inglés.** Javadoc, comentarios y mensajes al usuario en español.
- **Javadoc obligatorio** en clases y métodos (públicos y privados), corto y sin redundar con el nombre.
  **Prohibido** Javadoc en campos de DTO: eso es responsabilidad de `@Schema`.
- **`record` para DTOs** de salida e internos. Clase mutable solo en los dos casos justificados, con Javadoc.
- **`enum` para valores de dominio.** Prohibidos los strings mágicos para ramificar lógica.
- **Health check** solo vía `quarkus-smallrye-health`. Prohibido un `HealthController` manual con
  `{"status":"UP"}` hardcoded.
- **Utilidades** en clases dedicadas del paquete `util`. Prohibidos métodos `static` utilitarios en mappers o
  servicios.
- **`@ConfigMapping`** cuando haya tres o más propiedades con el mismo prefijo.

## `application.properties`

Orden de bloques: APPLICATION → HTTP (límites y proxy) → REST CLIENTS → AMQP → RESILIENCE → OPENAPI →
LOGGING → SECRETOS.

Una dependencia externa = un bloque (las 3 URLs por perfil, timeouts y su configuración juntos).

Imprescindibles en todo servicio nuevo:

```properties
quarkus.application.name=<nombre>
%dev.quarkus.http.port=<puerto de PORT_MANAGEMENT.md>

# Formato de log exigido por seguridad
quarkus.log.console.format=%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} [%X{eventType}] [%X{sessionId} - %X{clientIp} - %X{user}] %s, outcome=%X{outcome} [cid=%X{correlationId}]%e%n
quarkus.log.console.timezone=America/Guayaquil
quarkus.log.file.enable=false
quarkus.log.category."audit".level=INFO
quarkus.log.category."audit".min-level=INFO

# Límites de request (sin esto, un request agota la memoria del pod)
quarkus.http.limits.max-body-size=1M
quarkus.http.limits.max-header-size=8K

# IP real del cliente detrás del router
quarkus.http.proxy.proxy-address-forwarding=true
quarkus.http.proxy.trusted-proxies=${TRUSTED_PROXY_CIDR:10.0.0.0/8}

# Tramas: solo dev
%qa.quarkus.rest-client.logging.scope=none
%prod.quarkus.rest-client.logging.scope=none

# Access log sin query string
%dev.quarkus.http.access-log.pattern=%m %U %s %b ms=%D
%prod.quarkus.http.access-log.enabled=false

# Detección de bloqueo del event loop
%dev.quarkus.vertx.warning-exception-time=2s
%qa.quarkus.vertx.warning-exception-time=2s

# Shutdown ordenado (terminationGracePeriodSeconds del pod debe ser MAYOR)
quarkus.shutdown.timeout=30S
```

**Secretos sin default global.** `${DB_PASSWORD}` sin fallback: si falta, el pod no arranca, que es el
comportamiento deseado. El valor de conveniencia va con prefijo `%dev`. Un default global significa arrancar en
producción con una credencial publicada en el repo.

## OpenShift

- Puerto interno siempre `8080`; el del inventario aplica solo a `%dev`.
- `readinessProbe` → `/q/health/ready`, verifica dependencias críticas.
- `livenessProbe` → `/q/health/live`, **sin** verificar dependencias externas: si lo hace, una caída del
  proveedor reinicia todos los pods en cascada y convierte una degradación en caída total.
- **Prohibido** exponer `/q/health` o `/q/metrics` en el `Route` público.
- Logs a stdout, nunca a archivo.

## Checklist de arranque

```
[ ] artifactId en minúsculas con guiones, sin versión, groupId ec.fin.baustro
[ ] Proyecto creado con --no-code y quarkus-rest (no quarkus-resteasy)
[ ] maven.compiler.release ajustado a 25
[ ] Puerto elegido del rango correcto y PORT_MANAGEMENT.md actualizado en este PR
[ ] AGENTS.md copiado desde la plantilla y completado
[ ] Arquitectura elegida con criterio explícito y estructura de paquetes creada
[ ] CorrelationContext + Outcome + LogSanitizer + CorrelationFilter + CorrelationClientFilter
[ ] AuditLogger con categoría "audit" y min-level=INFO
[ ] ResponseCode conforme a RESPONSE_CODES.md + test que ancla los valores
[ ] ApiResponse<T> en dto
[ ] GlobalExceptionMapper sobre Throwable (no RuntimeException) con log del 500
[ ] ValidationExceptionMapper + test que verifica la estructura propia de violations
[ ] Formato de log de seguridad en application.properties
[ ] Límites HTTP, proxy forwarding con trusted-proxies, shutdown timeout
[ ] Gates de perfil: rest-client scope=none en qa/prod, access log sin %r
[ ] Secretos sin default fuera de %dev
[ ] quarkus-smallrye-health + probes cableadas
[ ] JaCoCo consolidado + jacoco:check con 90% líneas / 80% ramas
[ ] Tests: 3 por endpoint, WireMock por cliente externo, cumplimiento de logging
[ ] Si consume colas: DLQ, límite de reintentos, deduplicación, propagación de originUser
[ ] Si tiene efecto externo no reversible: clave de idempotencia
[ ] README con el presupuesto de tiempo de las llamadas externas
[ ] ArchUnit con las reglas arquitectónicas del estándar
```

## Skills relacionadas

Cargar según la parte en la que se trabaje: `quarkus-logging-audit` (logs, MDC, auditoría, datos sensibles),
`quarkus-rest-contract` (endpoints, DTOs, OpenAPI, códigos, mappers), `quarkus-resilience` (clientes externos,
fault tolerance, colas, event loop), `quarkus-testing` (tests y cobertura).
