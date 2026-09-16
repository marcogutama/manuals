# <nombre-del-microservicio>

Microservicio Quarkus reactivo. Java 25 · Mutiny · MicroProfile · despliegue en OpenShift.

## Comandos

```bash
JAVA_HOME=/home/marco/Applications/graalvm-jdk-25.0.3+9.1 ./mvnw quarkus:dev   # dev, puerto <XXXXX>
JAVA_HOME=/home/marco/Applications/graalvm-jdk-25.0.3+9.1 ./mvnw verify        # tests + jacoco:check
JAVA_HOME=/home/marco/Applications/graalvm-jdk-25.0.3+9.1 ./mvnw quarkus:build
```

`verify` incluye el gate de cobertura y falla si baja de 90% líneas / 80% ramas. Ejecutarlo antes de cerrar
cualquier cambio.

## Estándar aplicable

La norma completa está en `~/Documents/manuals/microservices-ai-rules.md`. **No la cargues entera**: usa las
skills, que contienen las reglas accionables por dominio.

| Tema del trabajo | Skill a cargar |
|---|---|
| Logs, MDC, correlationId, auditoría, datos sensibles | `quarkus-logging-audit` |
| Endpoints, DTOs, OpenAPI, codRespuesta, ExceptionMapper | `quarkus-rest-contract` |
| Clientes externos, @Retry, @CircuitBreaker, colas, event loop | `quarkus-resilience` |
| Tests, cobertura, JaCoCo, mocks | `quarkus-testing` |
| Crear un microservicio nuevo o validar su estructura | `quarkus-microservice-scaffold` |

Antes de abrir el PR: `@quarkus-reviewer` revisa el cambio contra el estándar.

Documentos de consulta obligatoria:

- `~/Documents/manuals/RESPONSE_CODES.md` — catálogo de `codRespuesta`. No inventar códigos.
- `~/Documents/manuals/PORT_MANAGEMENT.md` — inventario de puertos. Actualizar en el mismo PR que asigna uno.

## Reglas no negociables

Estas aplican a todo cambio en este repositorio.

**Reactivo**
- Todo retorna `Uni<T>`/`Multi<T>`. Prohibido `await()` en producción.
- Nada bloqueante (JDBC, `File`, HTTP síncrono, `Thread.sleep`) dentro de una cadena reactiva sin `@Blocking`
  o `runSubscriptionOn`. Bloquear el event loop degrada el pod completo, no un request.

**Logging (requisito del departamento de seguridad)**
- Formato: `[fecha/hora] [tipo de evento] [sesión - IP - usuario] descripción, resultado`.
- El MDC se siembra **solo en el borde** (`CorrelationFilter` o consumidor de cola), nunca en negocio.
- `clear()` del MDC siempre en `finally`: el hilo se reutiliza y un MDC sucio atribuye acciones al usuario
  equivocado.
- Todo endpoint que lee o modifica datos de cliente emite un evento de auditoría con `user` y `outcome`.
- **Prohibido** en logs: PAN completo, CVV, PIN, track, contraseñas, tokens, JWT. En cualquier nivel y perfil.
- **Prohibido** loguear un DTO de request completo.
- La categoría `audit` va con `min-level=INFO` (es build-time; por debajo, la auditoría desaparece en silencio).

**Código**
- Inyección por constructor. Prohibido `@Inject` en campos.
- Recursos JAX-RS **sin** scope CDI (rompe `@Valid`).
- `record` para DTOs; si contienen datos sensibles, sobrescribir `toString()`.
- Nombres de clase en inglés; Javadoc y mensajes al usuario en español.
- Javadoc en clases y métodos; **nunca** en campos de DTO (eso es `@Schema`).
- `enum` para valores de dominio, nunca strings mágicos.
- `ResponseCode` como única fuente de `codRespuesta`; prohibidos los literales.

**Configuración**
- Secretos **sin default global**: `${DB_PASSWORD}`. El valor de conveniencia va con prefijo `%dev`.
- `rest-client.logging.scope=none` en `%qa` y `%prod`.
- Access log sin `%r` ni `%q` (incluyen query string).

**Resiliencia**
- `@Retry` con `retryOn` explícito, `@CircuitBreaker` con `skipOn`. Sin ellos se reintentan los 4xx.
- Operación con efecto externo no reversible → clave de idempotencia.
- Consumidor de cola → DLQ, límite de reintentos, deduplicación.

**Tests**
- 90% líneas y 80% ramas, aplicado con `jacoco:check`.
- `@QuarkusTest` solo cuando se necesita el contenedor CDI; lo demás, JUnit plano.
- Prohibido `await().indefinitely()`; usar `atMost()` o `UniAssertSubscriber`.
- Cliente REST externo → WireMock, no mock de Mockito.
- Cada rama de error del flujo reactivo necesita su test.

## Arquitectura de este servicio

<!-- Completar: capas u hexagonal, y por qué. Dependencias externas y su propósito. -->

## Presupuesto de tiempo

<!-- Completar por cada llamada externa:
peor_caso = (read-timeout × (maxRetries + 1)) + (delay × maxRetries)
Verificar compatibilidad con el SLA de la vía de entrada. -->
