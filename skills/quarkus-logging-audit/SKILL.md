---
name: quarkus-logging-audit
description: Implementa o revisa logging, trazabilidad y auditoría en microservicios Quarkus según el estándar corporativo. Cubre el formato de log exigido por seguridad ([fecha/hora] [tipo de evento] [sesión - IP - usuario] descripción, resultado), Correlation ID, MDC, eventos de auditoría de acciones de usuario, y la prohibición de datos confidenciales de tarjetas en logs. Úsalo cuando el trabajo involucre logs, MDC, correlationId, auditoría, trazabilidad, datos sensibles/PII/PCI en logs, o configuración de logging en application.properties.
---

# Logging, Trazabilidad y Auditoría — Quarkus

Referencia normativa: `/home/marco/Documents/manuals/microservices-ai-rules.md`, secciones 18.x. Este
documento contiene las reglas accionables; consulta la norma completa (ruta absoluta, vive fuera del
repositorio) solo si necesitas el detalle de una decisión.

## Requisito de seguridad (no negociable)

El departamento de seguridad exige tres cosas:

1. Los logs permiten trazar las acciones de los usuarios: **quién**, qué, desde dónde, cuándo, con qué resultado.
2. Los logs **no almacenan** información confidencial de tarjetas.
3. Se cumple la estructura estándar:
   ```
   [fecha/hora] [tipo de evento] [sesión – IP – usuario] Descripción del evento, resultado del evento
   ```

Ninguna de las tres admite excepción por conveniencia técnica ni por plazo de entrega.

## Formato obligatorio

```properties
quarkus.log.console.format=%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} [%X{eventType}] [%X{sessionId} - %X{clientIp} - %X{user}] %s, outcome=%X{outcome} [cid=%X{correlationId}]%e%n
quarkus.log.console.timezone=America/Guayaquil
quarkus.log.file.enable=false
```

Idéntico en los tres perfiles. Los campos vienen del MDC, así que **ninguna clase conoce el formato**.

- Timestamp ISO-8601 **con fecha y offset**. `HH:mm:ss` suelto no permite auditar un evento de hace dos días.
- Todas las posiciones se rellenan con `-` cuando no aplican, para que la línea sea parseable de forma estable.
- El `eventType` es un **campo del MDC**, no un prefijo `[REQUEST_IN]` incrustado en el texto del mensaje.

## Claves MDC obligatorias

| Clave | Origen | Si no aplica |
|---|---|---|
| `correlationId` | Header `X-Correlation-Id` o UUID generado | obligatorio |
| `eventType` | Catálogo técnico o de auditoría | obligatorio |
| `outcome` | `SUCCESS` / `FAILURE` / `DENIED` | obligatorio |
| `user` | `SecurityIdentity.getPrincipal().getName()` o claim `sub` | `anonymous` |
| `sessionId` | Claim `jti` del JWT; alternativa header `X-Session-Id` | `-` |
| `clientIp` | `HttpServerRequest.remoteAddress()` | `-` |
| `service` | `quarkus.application.name` | obligatorio |

## Reglas de implementación

### Clases requeridas

- `util/CorrelationContext.java` — todas las constantes de clave MDC, `initCorrelation`, `setEventType`,
  `setOutcome`, `capture`, `restore`, `clear`.
- `util/Outcome.java` — enum `SUCCESS`, `FAILURE`, `DENIED`.
- `util/LogSanitizer.java` — enmascarado de PAN con Luhn + eliminación de CRLF.
- `filter/CorrelationFilter.java` — siembra el MDC completo; **único** lugar donde se siembra en flujo HTTP.
- `filter/CorrelationClientFilter.java` — propaga `X-Correlation-Id` en llamadas salientes.
- `service/AuditLogger.java` — eventos de auditoría en la categoría `audit`.

### El MDC se siembra solo en el borde

```java
// Correcto — el código de negocio no toca el MDC ni interpola contexto
Log.infof("Notificación persistida cNotificacion=%d", notificacion.getId());

// Incorrecto — duplica lo que ya aporta el formato
Log.infof("... correlationId=%s", CorrelationContext.getCorrelationId());  // ❌
```

Dos excepciones acotadas: `setEventType`/`setOutcome` al registrar auditoría, y `capture`/`restore` para
cruzar un salto de hilo (que restaura un contexto existente, no lo siembra).

### `clear()` siempre en `finally`

El MDC se hereda del hilo reutilizado del pool. Un MDC sin limpiar hace que el siguiente request loguee con el
usuario del anterior: no es ruido, es una traza de auditoría que atribuye acciones al usuario equivocado.

### Saltos de hilo en Mutiny

```java
Map<String, String> logContext = CorrelationContext.capture();
emitter.send(msg).whenComplete((r, failure) -> {
    CorrelationContext.restore(logContext);
    try { /* log */ } finally { CorrelationContext.clear(); }
});
```

`capture()`/`restore()` mueven **todas** las claves. Copiar solo `correlationId` pierde `user`, `sessionId` y
`clientIp`, y rompe la auditoría después del salto.

### API de logging

- `@io.quarkus.logging.Log` (Quarkus 3.x) o `org.jboss.logging.Logger`. Una sola API por proyecto.
- Prohibido `System.out.println`, `e.printStackTrace()`, loggers de otras librerías.
- El `Throwable` va **primero**: `LOG.errorf(e, "mensaje %s", valor)`. Al final se descarta silenciosamente.
- Todo valor de origen externo se sanea con `LogSanitizer` antes de interpolarlo.

### IP real detrás del router de OpenShift

```properties
quarkus.http.proxy.proxy-address-forwarding=true
quarkus.http.proxy.trusted-proxies=${TRUSTED_PROXY_CIDR:10.0.0.0/8}
```

**Prohibido** leer `X-Forwarded-For` a mano: sin `trusted-proxies` es un header que el cliente controla y la
IP registrada deja de ser evidencia válida.

## Eventos de auditoría

Registran intención del usuario, no mecánica del transporte. Todo endpoint que lea o modifique datos de
cliente debe emitir uno.

| `eventType` | Cuándo | Nivel |
|---|---|---|
| `AUTH_SUCCESS` | Autenticación exitosa | INFO |
| `AUTH_FAILURE` | Credenciales o token rechazado | WARN |
| `ACCESS_DENIED` | Autenticado sin permisos (403) | WARN |
| `DATA_READ` | Consulta de datos de cliente o negocio | INFO |
| `DATA_CREATE` / `DATA_UPDATE` / `DATA_DELETE` | Mutación de recurso | INFO |
| `CONFIG_CHANGE` | Cambio de parámetro operativo | INFO |
| `EXPORT` | Descarga o exportación masiva | INFO |
| `BUSINESS_ACTION` | Acción de negocio relevante | INFO |

Contenido del mensaje:

- Identificar el recurso por su **identificador técnico** (`id=42`), nunca por datos personales o de tarjeta.
- En `DATA_UPDATE`, registrar **qué campos** cambiaron, no sus valores:
  `campos=[direccion, telefono]`, jamás `telefono: 0999... -> 0988...`.

### La auditoría nunca se silencia

```properties
quarkus.log.category."audit".level=INFO
quarkus.log.category."audit".min-level=INFO
```

`min-level` es **build-time**. Si queda en `WARN`, ningún ajuste en runtime consigue que se emitan los eventos
y el requisito queda incumplido **sin ningún error visible**. Es la forma más fácil de fallar esta sección:
verifícalo siempre.

## Datos de tarjeta — prohibición absoluta

Un log es almacenamiento. Lo siguiente se prohíbe en **cualquier** nivel (`TRACE` incluido), **cualquier**
perfil (`%dev` incluido) y cualquier entorno.

| Dato | Regla |
|---|---|
| PAN completo | Prohibido; solo enmascarado 6+4 con justificación documentada |
| CVV / CVC2 / CID | **Prohibido, ni enmascarado** |
| PIN / PIN block | **Prohibido, ni enmascarado** |
| Track 1/2, banda, chip | **Prohibido, ni enmascarado** |
| Contraseñas, tokens, JWT, API keys | Prohibido |

**Distinción crítica:** el PAN admite enmascaramiento; los datos sensibles de autenticación (CVV, PIN, track)
**no se almacenan nunca** tras la autorización. Escribir `cvv=***` ya es un error de diseño: implica que el
valor pasó por el formateador.

Enmascarado válido del PAN: máximo primeros 6 + últimos 4 → `411111******1111`.

### Rutas de fuga a cerrar (revisar todas)

1. **Tramas REST client** → `scope=none` en `%qa` **y** `%prod`. Si el servicio toca tarjetas, también `%dev`.
   ```properties
   %dev.quarkus.rest-client.logging.scope=request-response
   %qa.quarkus.rest-client.logging.scope=none
   %prod.quarkus.rest-client.logging.scope=none
   ```
2. **Mensajes de excepción.** Jackson incluye el valor rechazado; Hibernate Validator interpola
   `${validatedValue}`. Prohibido `${validatedValue}` en cualquier constraint; `msgTecnico` sin
   `exception.getMessage()` en prod.
3. **Access log.** Usar `%m %U %s %b ms=%D`. **Prohibido `%r` y `%q`** (incluyen query string).
4. **`toString()` de records.** Genera todos los campos. Sobrescribir en cualquier DTO con datos sensibles.
   Prohibido loguear un DTO de request completo.
5. **SQL con parámetros** → `bind-parameters=false` en qa y prod.
6. **Excepciones de proveedores externos** — el SDK puede incluir el request completo. Sanear siempre.
7. **Categorías de librerías**: `io.quarkus.mailer`, `io.vertx.core.http`, `org.hibernate.SQL`,
   `org.apache.http.wire`. Gate por perfil, nunca por encima de `WARN` fuera de dev.

### `LogSanitizer`

Dos responsabilidades: enmascarar secuencias de 13-19 dígitos **que pasen Luhn** (para no destrozar
identificadores numéricos legítimos), y eliminar `\r\n` y caracteres de control (log injection).

Es una **red de seguridad**, no licencia para loguear tarjetas. El diseño correcto es que el PAN nunca llegue
al log.

## JSON estructurado — desactivado por defecto

Texto plano en los tres perfiles. El JSON solo aporta si un backend indexa los campos; sin eso, únicamente
dificulta `oc logs`.

Deja el bloque JSON **comentado** en `application.properties` con la condición de activación al lado: cuando
plataforma confirme que el `ClusterLogForwarder` de OpenShift tiene `parse: json` con `structuredTypeKey`.

Sintaxis correcta (dos líneas por campo, singular):
```properties
quarkus.log.console.json.additional-field.user.value=%X{user}
quarkus.log.console.json.additional-field.user.type=string
```
`additional-fields` (plural, una línea) **no es válida**. Y `quarkus.log.console.json` sin `.enabled` está
deprecada desde Quarkus 3.19.

## Verificación antes de cerrar

Tests obligatorios:

- El formato de log incluye fecha, tipo de evento, sesión, IP, usuario y resultado.
- `maskPan("4111111111111111")` → `"411111******1111"`.
- Un PAN embebido en texto libre se enmascara.
- Un identificador numérico que no pasa Luhn **no** se enmascara.
- Un `\n` en la entrada no produce una línea de log nueva.
- El `toString()` de un DTO con tarjeta no expone PAN ni CVV.
- Un endpoint que modifica datos emite el evento de auditoría con `user` y `outcome`.

Checklist de revisión:

- [ ] Ningún log interpola un DTO de request completo
- [ ] `rest-client.logging.scope=none` en `%qa` y `%prod`
- [ ] Access log sin `%r` ni `%q`
- [ ] Ningún constraint usa `${validatedValue}`
- [ ] `msgTecnico` sin mensaje de excepción en `%prod`
- [ ] Categoría `audit` con `min-level=INFO`
- [ ] `proxy-address-forwarding` + `trusted-proxies` configurados
- [ ] `capture()`/`restore()` en todo salto de hilo, `clear()` en `finally`
- [ ] Todo endpoint que lee/modifica datos de cliente emite evento de auditoría

## Al revisar código existente

Reporta hallazgos con `archivo:línea`. Prioriza en este orden:

1. Fugas activas de datos de tarjeta o credenciales (riesgo material inmediato).
2. Ausencia de identidad en los logs (incumple el requisito 1 de seguridad).
3. Formato que no cumple el estándar (incumple el requisito 3).
4. `min-level` que silencia la auditoría (incumplimiento invisible).
5. MDC sin limpiar (atribución incorrecta de acciones).
