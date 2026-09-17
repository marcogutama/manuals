# Cómo trabajar con IA en microservicios Quarkus

Guía de referencia del sistema de documentación y automatización que soporta el desarrollo de microservicios
con asistentes de IA. Explica qué archivo hace qué, cuándo se carga cada uno y cómo arrancar en un repositorio
nuevo.

Contexto: los desarrollos se realizan mayoritariamente con IA. El estándar completo tiene más de 3000 líneas,
y cargarlo entero en cada sesión degrada el cumplimiento — las reglas del medio de un documento largo se
atienden menos que las del inicio. De ahí la estructura en capas que se describe abajo.

---

## 1. El flujo completo

```
AGENTS.md del repo (~100 líneas, SIEMPRE en contexto)
        │
        │  apunta a
        ▼
Skills (carga automática según el tema, 150-250 líneas cada una)
        │
        │  derivadas de
        ▼
microservices-ai-rules.md (norma canónica, ~3200 líneas, NO se carga entera)
        │
        │  complementado por
        ▼
RESPONSE_CODES.md  +  PORT_MANAGEMENT.md
        │
        │  verificado por
        ▼
@quarkus-reviewer (antes del PR)  +  CI (jacoco:check, ArchUnit, SpotBugs, check-log-leaks.sh)
```

La idea central: **cada capa carga solo lo que necesita**. El `AGENTS.md` garantiza que la IA sepa que las
reglas existen; las skills entregan el detalle del tema en el que se está trabajando; la norma canónica queda
como referencia consultable; y lo que puede automatizarse se mueve al CI, donde se cumple el 100% de las veces
sin depender de que nadie lo recuerde.

---

## 2. Las cuatro capas

### Capa 1 — `AGENTS.md` del repositorio

**Qué es:** archivo en la raíz de cada repositorio de microservicio. OpenCode lo carga automáticamente en
cada sesión.

**Contenido:** comandos de build y test con el `JAVA_HOME` correcto, la tabla de qué skill cargar según el
tema, y las reglas no negociables condensadas. Unas 100 líneas.

**Por qué existe:** es lo único que está garantizado en contexto. Sin él, la IA no sabe que hay un estándar
que cumplir.

**Cómo se crea:** copiar `AGENTS-microservicio-template.md` (ver sección 4).

### Capa 2 — Skills

**Qué son:** instrucciones especializadas que la IA carga bajo demanda cuando la tarea coincide con su
descripción. Viven en `~/.config/opencode/skills/<nombre>/SKILL.md`.

| Skill | Se activa cuando el trabajo involucra |
|---|---|
| `quarkus-microservice-scaffold` | crear un microservicio nuevo, scaffolding, validar estructura |
| `quarkus-logging-audit` | logs, MDC, correlationId, auditoría, datos sensibles / PII / PCI |
| `quarkus-rest-contract` | endpoints, DTOs, OpenAPI, `codRespuesta`, `ExceptionMapper` |
| `quarkus-resilience` | clientes REST externos, `@Retry`, `@CircuitBreaker`, colas, event loop |
| `quarkus-testing` | tests, cobertura, JaCoCo, mocks |

**Cómo se activan:** automáticamente. La IA ve la lista de skills disponibles con su descripción y carga la
que corresponde. También se puede pedir explícitamente: *"carga la skill de logging y revisa esto"*.

**Contenido:** solo reglas accionables, sin la prosa explicativa de la norma. 150-250 líneas cada una.

### Capa 3 — Norma canónica y catálogos

| Documento | Rol |
|---|---|
| `microservices-ai-rules.md` | Norma completa. Referencia consultable, **no** se carga entera en una sesión de implementación |
| `RESPONSE_CODES.md` | Catálogo maestro versionado de `codRespuesta`. Fuente de verdad; consulta obligatoria antes de crear un código |
| `PORT_MANAGEMENT.md` | Inventario de puertos para desarrollo local. Consulta obligatoria al crear un servicio, y **actualización en el mismo PR** |

### Capa 4 — Verificación

**`@quarkus-reviewer`** — subagente de solo lectura que revisa un cambio contra el estándar. Corre en su
propio contexto, así que puede leer la norma completa sin consumir el contexto de la sesión donde estás
implementando. Ver sección 3.

**CI** — sección 27 de la norma. Las reglas que un linter, ArchUnit o `jacoco:check` pueden verificar se
mueven ahí. Una regla ejecutable se cumple siempre; una regla en Markdown se cumple cuando alguien la
recuerda.

---

## 3. Uso del subagente `quarkus-reviewer`

**Cuándo:** antes de abrir cualquier PR.

**Cómo:**

```
@quarkus-reviewer revisa el cambio de esta rama
@quarkus-reviewer revisa src/main/java/.../NotificationService.java
```

**Qué hace:** lee el código, la norma y los catálogos, y emite un informe con los hallazgos priorizados en
cuatro niveles. No modifica archivos: permisos `edit: deny`, y bash limitado a `git diff`, `git log`,
`git status` y comandos maven.

**Prioridad de los hallazgos.** Los nueve bloqueantes son los que tienen impacto material:

1. Fuga de datos sensibles en logs (PAN, CVV, PIN, track, contraseñas, tokens)
2. Logs sin identidad de usuario — incumple la trazabilidad exigida
3. Formato de log distinto del estándar de seguridad
4. `min-level` que silencia la auditoría (incumplimiento invisible: no produce ningún error)
5. Bloqueo del event loop (degrada el pod completo, no un request)
6. Secreto con default global (arranca producción con credencial del repo)
7. `livenessProbe` que verifica dependencias externas (reinicio en cascada)
8. Falta de idempotencia con `@Retry` o colas at-least-once (duplicados visibles al cliente)
9. Consumidor de cola sin DLQ ni límite de reintentos (poison message)

Debajo: altos (defecto funcional o de contrato), medios (desvío del estándar) y bajos (estilo).

El informe incluye dos secciones que conviene leer siempre: **"Verificado sin hallazgos"**, que delimita el
alcance real de la revisión, y **"No pude verificar"**, que lista lo que requiere ejecutar el servicio o
acceso al clúster.

---

## 4. Crear un microservicio nuevo

### 4.1 Cómo encuentra la IA los documentos

Los documentos de estándar viven **fuera** del repositorio del microservicio, en `~/Documents/manuals/`. Las
skills los referencian con **ruta absoluta** (`/home/marco/Documents/manuals/PORT_MANAGEMENT.md`), así que la
IA sabe dónde buscarlos sin necesidad de copiarlos al proyecto.

**No los copies al repositorio del microservicio.** `PORT_MANAGEMENT.md` y `RESPONSE_CODES.md` son inventarios
compartidos: una copia local deriva del original en cuanto alguien añade un puerto o un código en el otro
lugar, y entonces hay dos verdades.

Consecuencia práctica: leer fuera del directorio del proyecto puede pedir confirmación de permiso
(`external_directory` en OpenCode). Es esperable; concédela. Si se deniega, la skill está instruida para
preguntar el puerto en lugar de inventarlo, y para avisar que `PORT_MANAGEMENT.md` queda sin actualizar.

### 4.2 Comando de creación

```bash
quarkus create app ec.fin.baustro:<artifact-id> --extension quarkus-rest --no-code
```

- **`--no-code` obligatorio.** El código de ejemplo (`GreetingResource`) incumple el estándar y hay que
  borrarlo; mejor no generarlo.
- **`quarkus-rest`**, que es RESTEasy Reactive. No `quarkus-resteasy` (clásico, bloqueante): rompe el
  requisito reactivo.
- Ejecutar **en el directorio padre**: crea una carpeta con el nombre del `artifactId`.

Extensiones que conviene añadir de entrada, según lo que el servicio vaya a hacer:

```bash
# Base de todo servicio REST
--extension quarkus-rest,quarkus-rest-jackson,quarkus-smallrye-health,quarkus-smallrye-openapi,quarkus-hibernate-validator

# Si consume o publica en colas
--extension quarkus-smallrye-reactive-messaging-amqp

# Si llama a otros servicios
--extension quarkus-rest-client,quarkus-rest-client-jackson,quarkus-smallrye-fault-tolerance

# Si requiere JWT
--extension quarkus-smallrye-jwt,quarkus-security
```

### 4.3 Convención del `artifactId`

El `artifactId` se convierte en el nombre del JAR y del directorio del proyecto.

| Regla | Correcto | Incorrecto |
|---|---|---|
| Solo minúsculas | `whatsapp-delivery-consumer` | `WhatsAppDeliveryConsumer` |
| Palabras separadas por guiones | `user-management-service` | `userManagementService` |
| Sin guiones bajos | `payment-gateway` | `payment_gateway` |
| Sin versión en el nombre | `report-generator` | `report-generator-v2` |

PascalCase y camelCase se reservan para las **clases Java** dentro del proyecto. El `groupId` es siempre
`ec.fin.baustro`.

### 4.4 Pasos posteriores

Quarkus genera un proyecto que aún no cumple el estándar:

1. **Java 25** en `maven.compiler.release` del `pom.xml` — el arquetipo suele fijar 17 o 21.
2. **`%dev.quarkus.http.port`** con el puerto tomado de `PORT_MANAGEMENT.md`, y actualizar ese inventario en
   el mismo PR.
3. **Copiar la plantilla como `AGENTS.md`:**
   ```bash
   cp ~/Documents/manuals/AGENTS-microservicio-template.md /ruta/al/microservicio/AGENTS.md
   ```
4. **Completar los marcadores** de la plantilla: nombre y puerto del servicio; `<!-- Completar -->` en
   *Arquitectura de este servicio* (capas u hexagonal, con el criterio de la decisión y las dependencias
   externas); `<!-- Completar -->` en *Presupuesto de tiempo* (peor caso por llamada externa con la fórmula
   `(read-timeout × (maxRetries + 1)) + (delay × maxRetries)`, verificado contra el SLA de entrada).
5. **Commitear el `AGENTS.md`** al repositorio: es documentación compartida del equipo, no configuración
   personal.
6. **Añadir las dependencias de test y el gate de JaCoCo** (skill `quarkus-testing`).
7. **Verificar que arranca:** `./mvnw quarkus:dev` con el `JAVA_HOME` de Java 25.
8. **Confirmar que las skills responden:** pedir algo del dominio de una skill (*"revisa la configuración de
   logging"*) y ver que se carga.

Lo más simple es pedirle a la IA que cargue la skill `quarkus-microservice-scaffold` y le pase el nombre y
propósito del servicio: tiene el comando, las extensiones, la convención y el checklist completo.

---

## 5. Ubicación de los archivos

### Configuración de OpenCode (lo que la herramienta lee)

```
~/.config/opencode/
├── AGENTS.md                              # reglas globales personales (versiones de Java, etc.)
├── opencode.jsonc                          # configuración de OpenCode
├── skills/
│   ├── commit-generator/SKILL.md
│   ├── quarkus-microservice-scaffold/SKILL.md
│   ├── quarkus-logging-audit/SKILL.md
│   ├── quarkus-rest-contract/SKILL.md
│   ├── quarkus-resilience/SKILL.md
│   └── quarkus-testing/SKILL.md
└── agents/
    └── quarkus-reviewer.md
```

### Repositorio `manuals` (copia versionada para compartir)

```
~/Documents/manuals/
├── microservices-ai-rules.md               # norma canónica
├── RESPONSE_CODES.md                       # catálogo de codRespuesta
├── PORT_MANAGEMENT.md                      # inventario de puertos
├── AGENTS-microservicio-template.md        # plantilla de AGENTS.md
├── IA-microservicios-flujo.md              # este documento
├── skills/                                 # copia de las skills
└── agents/                                 # copia del subagente
```

### Sobre la duplicación

Las skills y el subagente existen en dos lugares: `~/.config/opencode/` es lo que OpenCode lee, y
`manuals/skills/` es la copia versionada en git para compartir con el equipo.

**Son archivos independientes.** Al editar uno hay que sincronizar el otro:

```bash
# manuals → config (después de un git pull)
cp -r ~/Documents/manuals/skills/quarkus-* ~/.config/opencode/skills/
cp ~/Documents/manuals/agents/quarkus-reviewer.md ~/.config/opencode/agents/

# config → manuals (después de editar en caliente)
cp -r ~/.config/opencode/skills/quarkus-* ~/Documents/manuals/skills/
cp ~/.config/opencode/agents/quarkus-reviewer.md ~/Documents/manuals/agents/
```

Alternativa: reemplazar las copias de `~/.config/opencode/` por symlinks a `manuals/`. Elimina la
sincronización manual, a cambio de que la configuración dependa de que ese directorio exista.

**Nota sobre ubicación global vs. por proyecto.** Estas skills están en `~/.config/opencode/skills/`, o sea
son globales: funcionan en cualquier directorio. La alternativa es `.opencode/skills/` dentro de cada
repositorio, que las versiona con el equipo y hace que cada quien las tenga al clonar. Si el equipo adopta
este flujo, conviene mover las skills a los repositorios de microservicio, o a un repositorio compartido de
estándares.

---

## 6. Precedencia entre documentos

Cuando dos fuentes se contradicen, este es el orden:

1. **Lo que verifica el build o el CI.** Si el pipeline dice una cosa y el documento otra, el documento está
   desactualizado.
2. **`RESPONSE_CODES.md`** sobre la sección 22.2 de la norma.
3. **`PORT_MANAGEMENT.md`** como única fuente de asignación de puertos.
4. **`AGENTS.md` del repositorio** sobre las reglas generales, cuando el servicio tenga una particularidad
   justificada.
5. **Secciones 17, 18.9 y 18.10 de la norma** — requisitos del departamento de seguridad. No admiten excepción
   por conveniencia técnica ni por plazo de entrega.

---

## 7. Mantenimiento

### Al añadir una regla nueva al estándar

1. **Evaluar primero si es automatizable.** ¿La puede verificar ArchUnit, SpotBugs, un test o un script de CI?
   Si sí, va a la sección 27 de la norma y al pipeline. Ese es el destino preferido: se cumple siempre.
2. Si no es automatizable, añadirla a `microservices-ai-rules.md` con **regla imperativa primero,
   justificación después**. El orden inverso (explicar y luego decir qué hacer) reduce el cumplimiento cuando
   el consumidor es un modelo de lenguaje.
3. Toda regla debe indicar **cómo verificarla**. Una regla sin verificación es una recomendación.
4. Propagar a la skill correspondiente si es accionable en el día a día.
5. Si es no negociable, añadirla también a `AGENTS-microservicio-template.md`.
6. Sincronizar las copias (sección 5).

### Al crear una skill nueva

- Directorio `~/.config/opencode/skills/<nombre>/SKILL.md`, donde `<nombre>` coincide con el del frontmatter.
- Nombre en minúsculas con guiones simples: `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Frontmatter con `name` y `description` obligatorios. La `description` es lo que decide si la skill se
  activa: debe enumerar los temas y las palabras que un usuario usaría al pedir ese trabajo.
- Contenido accionable, no explicativo. Si necesita más de 300 líneas, probablemente son dos skills.

### Señales de que algo no funciona

- **La IA ignora una regla repetidamente** → la regla está enterrada en la norma y no está en la skill ni en
  el `AGENTS.md`. O es candidata a moverse al CI.
- **La skill no se activa** → la `description` no cubre las palabras que usas al pedir el trabajo.
- **El reviewer produce informes largos sin hallazgos críticos** → el equipo va a aprender a ignorarlo.
  Revisar la priorización.

---

## 8. Referencia rápida

| Necesito... | Uso |
|---|---|
| Crear un microservicio nuevo | Skill `quarkus-microservice-scaffold` (trae el comando `quarkus create app`, extensiones y convención de nombres) + copiar la plantilla de `AGENTS.md` |
| Implementar o revisar logging y auditoría | Skill `quarkus-logging-audit` |
| Diseñar un endpoint | Skill `quarkus-rest-contract` + `RESPONSE_CODES.md` |
| Configurar un cliente REST externo | Skill `quarkus-resilience` |
| Escribir tests o arreglar la cobertura | Skill `quarkus-testing` |
| Revisar antes del PR | `@quarkus-reviewer` |
| Asignar un puerto | `PORT_MANAGEMENT.md` (y actualizarlo en el mismo PR) |
| Consultar un `codRespuesta` | `RESPONSE_CODES.md` |
| Entender el *por qué* de una regla | `microservices-ai-rules.md`, sección correspondiente |
| Generar un mensaje de commit | Skill `commit-generator` |
