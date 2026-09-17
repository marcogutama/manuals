---
name: quarkus-resilience
description: Implementa o revisa resiliencia y comunicación entre microservicios Quarkus según el estándar corporativo. Cubre @Retry, @CircuitBreaker, @Timeout y @Fallback acotados a fallos transitorios, clientes REST tipados, idempotencia, deduplicación de mensajes, dead letter queues y bloqueo del event loop. Úsalo cuando el trabajo involucre clientes REST externos, fault tolerance, reintentos, circuit breakers, colas AMQP/Kafka, o problemas de rendimiento y bloqueo en código reactivo.
---

# Resiliencia y Comunicación — Quarkus

Referencia normativa: `/home/marco/Documents/manuals/microservicios/microservices-ai-rules.md`, secciones 20, 24, 25 (vive
fuera del repositorio; ruta absoluta).

## Bloqueo del event loop (revisar primero)

Es la causa más frecuente de incidentes en Quarkus reactivo y la más grave: **no degrada un request, degrada el
pod completo**.

RESTEasy Reactive atiende en pocos hilos de I/O (`2 × núcleos`). Una operación bloqueante congela ese hilo y
todos los requests que tenía asignados. Con 4 hilos, cuatro llamadas bloqueantes dejan el servicio sin atender
nada — health checks incluidos — y OpenShift reinicia el pod.

Operaciones bloqueantes que se cuelan en cadenas reactivas: JDBC clásico y ORM no reactivo, `File`/`Files`,
`InputStream.read()`, `HttpClient` síncrono, SDKs de terceros sin API reactiva, `Thread.sleep()`,
`Future.get()`, `CountDownLatch.await()`, `synchronized` con contención, y `await()` en cualquier forma.

```java
// ❌ JDBC en el hilo de I/O
return Uni.createFrom().item(() -> jdbcRepository.findAll());

// ✓ (a) @Blocking: Quarkus mueve el método al worker pool
@GET @Blocking
public List<Producto> listar() { return jdbcRepository.findAll(); }

// ✓ (b) aislar solo la parte bloqueante
return Uni.createFrom().item(() -> jdbcRepository.findAll())
        .runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
```

Reglas:

- **Prohibido `await()` en producción.** Solo en tests, con timeout.
- Un método `@Blocking` **no** retorna `Uni`/`Multi`: si es bloqueante, retorna el tipo directo. Mezclar ambos
  indica confusión sobre dónde se ejecuta.
- **Prohibido mezclar `@RunOnVirtualThread` con cadenas Mutiny.** Los hilos virtuales resuelven el bloqueo en
  código imperativo; combinarlos con operadores reactivos añade dos modelos de concurrencia sin beneficio.
  Elegir uno.

Detección obligatoria en dev y qa, donde el problema se descubre gratis:

```properties
%dev.quarkus.vertx.warning-exception-time=2s
%qa.quarkus.vertx.warning-exception-time=2s
```

**Un `Thread blocked` en el log es un defecto, no una advertencia informativa.**

Un test funcional pasa igual con un servicio bloqueante: el bloqueo solo se manifiesta bajo concurrencia.

## Fault Tolerance acotado

**Prohibido** declarar `@Retry` o `@CircuitBreaker` sin clasificación de excepciones. Por defecto MicroProfile
reintenta ante **cualquier** `Exception`, incluidos errores no transitorios (4xx, validación, no encontrado).
Eso desperdicia reintentos, retrasa la respuesta y enmascara bugs reales como fallos de red.

### Regla de oro

- **`@Retry` es lista blanca.** Solo lo listado en `retryOn` se reintenta; todo lo demás aborta
  automáticamente. Declarar `abortOn` con excepciones que ya están fuera de `retryOn` es redundante.
- **`@CircuitBreaker` y `@Fallback` son lista negra.** Evalúan cualquier `Throwable` como fallo. `skipOn` es la
  única forma de excluir un 4xx de contar como fallo de infraestructura. Aquí `skipOn` **no** es opcional.

```java
@CircuitBreaker(skipOn = { ClientErrorException.class })
@Retry(retryOn = {
    ProcessingException.class,   // timeouts y fallos de transporte (Vert.x/Netty)
    ServerErrorException.class   // 5xx del remoto
})
@Fallback(value = MiFallback.class, skipOn = { ClientErrorException.class })
public Uni<Respuesta> llamarServicio(...) { ... }
```

### `ProcessingException`, no `ConnectException` suelto

En `quarkus-rest-client` (RESTEasy Reactive sobre Vert.x/Netty), los fallos de conexión y timeout se propagan
encapsulados en `jakarta.ws.rs.ProcessingException`. La causa anidada puede ser `ConnectException` o
`NoStackTraceTimeoutException`, pero el tipo que evalúa `retryOn` es siempre `ProcessingException`. Listar las
causas anidadas es código muerto: nunca se evalúan.

**No asumirlo de memoria.** El wrapping ha cambiado entre versiones. Verificar contra la versión exacta del
proyecto con un test de integración (WireMock con retraso mayor al `read-timeout`, o conexión rechazada). Un
test unitario con mocks **no** es evidencia: nunca dispara un timeout de socket real.

### No mezclar capas

Una excepción de dominio lanzada en el *consumidor* del `Uni` — no en el método REST-cliente anotado — nunca
debe aparecer en `abortOn`/`skipOn`/`failOn` de ese método. No tiene efecto (el interceptor solo ve las fallas
dentro del método que anota) y sugiere una comprensión incorrecta del límite entre la llamada HTTP y la lógica
que la consume.

Antes de añadir una excepción, preguntar: **¿la lanza el método anotado, o otro bean más adelante en la
cadena?** Solo la primera pertenece ahí.

## Parámetros externalizados

**Prohibido** hardcodear valores en las anotaciones.

```properties
ec.fin.baustro.client.PersistenceClient/getRules/Retry/maxRetries=${PERSISTENCE_RETRY_MAX:3}
ec.fin.baustro.client.PersistenceClient/getRules/Retry/delay=${PERSISTENCE_RETRY_DELAY_MS:1000}
ec.fin.baustro.client.PersistenceClient/getRules/Timeout/value=${PERSISTENCE_TIMEOUT_MS:5000}
```

### Presupuesto de tiempo documentado

Documentar en el README el peor caso real, incluyendo el `delay` (no solo `timeout × intentos`):

```
peor_caso_por_llamada = (read-timeout × (maxRetries + 1)) + (delay × maxRetries)
```

Si el flujo encadena varias llamadas, multiplicar y verificar que sea compatible con el SLA de la vía de
entrada. Si un escenario de fallo queda fuera de cobertura deliberadamente, anotarlo como decisión consciente,
no como omisión.

## Idempotencia (obligatoria)

`@Retry` en todos los clientes + colas *at-least-once* **garantiza** operaciones duplicadas. Escenario real: el
proveedor de SMS recibe el envío, responde, la respuesta se pierde por timeout, `@Retry` reintenta, el cliente
recibe dos SMS. Para un delivery worker es un defecto funcional visible, no un detalle técnico.

### Endpoints con efecto no reversible

Todo `POST` que envíe, cobre o autorice acepta una clave de idempotencia:

```java
@HeaderParam("Idempotency-Key") String idempotencyKey
```

- Misma clave + mismo payload → resultado original, `codRespuesta` `700` (`DUPLICATE_REQUEST`), **sin** repetir
  el efecto.
- Misma clave + payload distinto → `409`.
- Sin clave → se procesa, y se documenta que el reintento puede duplicar.
- Almacenar con TTL (24 h razonable) junto al resultado.

### Consumidores de cola

Idempotente por diseño, no por confianza en el broker: consultar un almacén de deduplicación antes de procesar
y marcar al terminar. Si no hay almacén, la alternativa aceptable es verificar el **estado del recurso** (si ya
está `ENVIADA`, no reenviar), documentada como la estrategia elegida.

### DLQ obligatoria

Sin límite de reintentos, un *poison message* se reencola para siempre, consume capacidad y llena el log con el
mismo error.

```properties
mp.messaging.incoming.whatsapp-in.failure-strategy=dead-letter-queue
mp.messaging.incoming.whatsapp-in.dead-letter-queue.name=whatsapp-dlq
mp.messaging.incoming.whatsapp-in.max-retries=3
```

Requisitos: límite de reintentos con backoff, DLQ definida, log `AMQ_DLQ` a `ERROR` con identificador y causa,
y un **procedimiento documentado de revisión y reproceso**. Una DLQ que nadie revisa es pérdida silenciosa de
datos.

**Distinguir transitorio de permanente:** un `nack` sobre error de validación reintenta algo que nunca va a
funcionar. Eso va directo a la DLQ; solo se reintenta lo transitorio, con el mismo criterio del Fault
Tolerance.

### Persistir y publicar

Ambas acciones pueden divergir. Documentar qué ocurre en cada caso. Si la consistencia es crítica, usar el
patrón **outbox**: persistir el mensaje en la misma transacción que el dato y publicarlo con un proceso aparte.
Como mínimo, **nunca publicar antes de persistir**: un mensaje que referencia un registro inexistente falla en
el consumidor y es más difícil de diagnosticar.

## Comunicación

- Clientes REST tipados (`@RegisterRestClient`) para síncrono.
- Mensajería sobre llamadas directas para asíncrono.
- Header de correlación: **`X-Correlation-Id`**, idéntico en los 4 puntos de propagación. No `X-Request-ID` ni
  variantes. Ver la skill `quarkus-logging-audit`.
- Al cruzar una cola, propagar también `originUser` y `originSessionId` en el DTO del mensaje, o la traza de
  auditoría se corta.

## Al revisar

Prioriza en este orden:

1. Bloqueo del event loop (impacto: pod completo).
2. `@Retry`/`@CircuitBreaker` sin clasificación (reintentos sobre 4xx, circuitos que se abren por bugs).
3. Ausencia de idempotencia en operaciones con efecto externo (duplicados visibles para el cliente).
4. Consumidor sin DLQ ni límite de reintentos (poison message).
5. Excepciones de dominio en `skipOn`/`abortOn` de un cliente REST (código muerto).
6. Presupuesto de tiempo no documentado frente al SLA de entrada.
