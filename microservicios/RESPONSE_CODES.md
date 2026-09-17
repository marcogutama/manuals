# Catálogo Maestro de Códigos de Respuesta de Negocio

> **Versión del catálogo:** `1.1.0`
> **Alcance:** todos los microservicios del ecosistema.
> **Documento normativo relacionado:** `microservices-ai-rules.md`, sección 22.

Este archivo es la **única fuente de verdad** de los valores de `codRespuesta`. Las tablas de la sección 22.2
de `microservices-ai-rules.md` son un resumen de referencia rápida; ante cualquier discrepancia, manda este
documento.

---

## 1. Principio fundamental

`codRespuesta` es un **código de negocio**, no un espejo del HTTP status. El código HTTP lo transporta el
protocolo; `codRespuesta` expresa el resultado desde la perspectiva del dominio.

- **El éxito siempre es `"000"`**, sin importar el HTTP status (`200`, `201`, `202`).
- Cualquier valor distinto de `"000"` indica una condición anómala específica.
- Los códigos son cadenas de tres dígitos (`String`), por compatibilidad con sistemas legados y para permitir
  sub-rangos futuros.
- **Prohibido** devolver el HTTP status como valor de `codRespuesta` (`"200"`, `"404"`, `"500"`).

---

## 2. Rangos reservados

| Rango | Significado | HTTP asociado |
|---|---|---|
| `000` | Éxito | `200`, `201`, `202`, `204` |
| `1xx` | Errores de entrada / contrato (cliente) | `400`, `422` |
| `2xx` | Errores de negocio / dominio | `404`, `409`, `422` |
| `3xx` | Errores de dependencias externas (downstream) | `502`, `503`, `504` |
| `4xx` | **Reservado** — no usar | — |
| `5xx` | **Reservado** — no usar | — |
| `6xx` | Autenticación y autorización | `401`, `403` |
| `7xx` | Idempotencia y concurrencia | `409`, `422` |
| `8xx` | **Libre** para códigos específicos de dominio, previa aprobación | — |
| `9xx` | Errores internos / inesperados | `500` |

Los rangos `4xx` y `5xx` están reservados deliberadamente y **no deben usarse**: un `codRespuesta` de `"404"`
o `"500"` es indistinguible del HTTP status y contradice el principio de la sección 1.

---

## 3. Catálogo

### Rango `000` — Éxito

| Código | Constante | `msgUsuario` estándar | Escenario |
|---|---|---|---|
| `000` | `SUCCESS` | Operación exitosa | Operación completada correctamente. |

### Rango `1xx` — Errores de entrada / contrato

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `100` | `VALIDATION_ERROR` | Los datos enviados no son válidos | Violaciones de Bean Validation. Siempre acompaña un array `violations`. | `400` |
| `101` | `MISSING_REQUIRED_FIELD` | Falta un campo obligatorio | Campo requerido ausente no cubierto por Bean Validation. | `400` |
| `102` | `INVALID_FORMAT` | El formato del dato enviado no es correcto | Tipo de dato incorrecto, JSON malformado, fecha inválida. | `400` |
| `103` | `UNSUPPORTED_VALUE` | El valor indicado no está soportado | Valor de enumeración desconocido, método HTTP o content-type no soportado. | `400`, `405`, `415` |
| `104` | `PAYLOAD_TOO_LARGE` | El tamaño de la petición excede el límite permitido | Body por encima de `quarkus.http.limits.max-body-size`. | `413` |

### Rango `2xx` — Errores de negocio / dominio

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `200` | `RESOURCE_NOT_FOUND` | El recurso solicitado no fue encontrado | Entidad buscada no existe. | `404` |
| `201` | `NO_ACTIVE_RULES` | No existen reglas activas para los parámetros indicados | Sin reglas habilitadas para el par evento/origen. | `404` |
| `202` | `MISSING_CONTACT_INFO` | No se pudo obtener información de contacto para el destinatario | Sin teléfono/correo en el request ni en el orquestador externo. | `422` |
| `203` | `BUSINESS_RULE_VIOLATION` | La operación no puede completarse por una regla de negocio | Caso de uso válido pero vetado por una regla de dominio. | `422` |
| `204` | `RESOURCE_ALREADY_EXISTS` | El recurso ya existe | Violación de unicidad de negocio. | `409` |
| `205` | `INVALID_STATE_TRANSITION` | El recurso no permite esta operación en su estado actual | Transición de estado no válida (ej. anular algo ya anulado). | `422` |

### Rango `3xx` — Errores de dependencias externas

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `300` | `DOWNSTREAM_ERROR` | Error al comunicarse con un servicio externo | Fallo genérico en una dependencia externa. | `502` |
| `301` | `PERSISTENCE_ERROR` | Error al comunicarse con el servicio de persistencia | Fallo al registrar o consultar en persistencia. | `502` |
| `302` | `DISPATCH_ERROR` | Error al comunicarse con el servicio de despacho | Fallo al enviar al canal (SMS, Email, WhatsApp). | `502` |
| `303` | `STORAGE_ERROR` | Error al subir el adjunto al almacenamiento | Fallo en Document Object Storage. | `502` |
| `304` | `CUSTOMER_INFO_ERROR` | Error al consultar los datos del cliente | Fallo al consultar el orquestador de datos de persona. | `502` |
| `305` | `CIRCUIT_BREAKER_OPEN` | El servicio no está disponible temporalmente, intente más tarde | Circuit breaker abierto en alguna dependencia. | `503` |
| `306` | `DOWNSTREAM_TIMEOUT` | El servicio externo no respondió en el tiempo esperado | Timeout agotado contra una dependencia. | `504` |

### Rango `6xx` — Autenticación y autorización

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `600` | `UNAUTHENTICATED` | No autenticado | Token ausente, mal firmado, o con issuer/audience inválido. | `401` |
| `601` | `ACCESS_DENIED` | No tiene permisos para realizar esta operación | Autenticado pero sin el rol requerido. | `403` |
| `602` | `TOKEN_EXPIRED` | La sesión ha expirado, vuelva a autenticarse | Token válido pero vencido. | `401` |

**Reglas obligatorias del rango `6xx`:**

- Emitir siempre el evento de auditoría correspondiente (`AUTH_FAILURE` o `ACCESS_DENIED`) con
  `outcome=DENIED`, conforme a la sección 18.9.2 de `microservices-ai-rules.md`.
- `msgTecnico` **genérico**. No revelar si el usuario existe, si la contraseña era incorrecta ni qué rol
  faltaba: eso permite enumerar usuarios y permisos. El detalle va al log de auditoría, nunca a la respuesta.

### Rango `7xx` — Idempotencia y concurrencia

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `700` | `DUPLICATE_REQUEST` | La operación ya fue procesada previamente | Clave de idempotencia repetida; se devuelve el resultado original. | `200`, `409` |
| `701` | `CONCURRENT_MODIFICATION` | El recurso fue modificado por otra operación, vuelva a intentar | Conflicto de bloqueo optimista. | `409` |

### Rango `9xx` — Errores internos

| Código | Constante | `msgUsuario` estándar | Escenario | HTTP |
|---|---|---|---|---|
| `900` | `INTERNAL_ERROR` | Ha ocurrido un error inesperado. Por favor contacte al soporte técnico. | Error de runtime no capturado por ningún handler específico. | `500` |
| `901` | `CONFIGURATION_ERROR` | Error en la configuración del sistema | Parámetro de configuración inválido detectado en runtime. | `500` |

---

## 4. Implementación

Cada microservicio representa este catálogo como un único `enum ResponseCode` en el paquete `util` (paquete
neutral: lo consumen dominio, adaptadores y capa REST por igual).

- **Prohibido** escribir los códigos como strings literales fuera del enum.
- El nombre de las constantes es en inglés, conforme a la sección 16 de `microservices-ai-rules.md`.
- Un servicio incluye **solo** las constantes que usa, pero **nunca** con un valor distinto al de este
  catálogo. Reutilizar `"300"` para otro significado rompe el contrato compartido.

```java
/**
 * Códigos de respuesta de negocio. Única fuente de verdad en el servicio.
 * Catálogo maestro: RESPONSE_CODES.md (versión 1.1.0).
 */
public enum ResponseCode {

    SUCCESS("000"),

    VALIDATION_ERROR("100"),
    MISSING_REQUIRED_FIELD("101"),
    INVALID_FORMAT("102"),
    UNSUPPORTED_VALUE("103"),

    RESOURCE_NOT_FOUND("200"),
    BUSINESS_RULE_VIOLATION("203"),

    DOWNSTREAM_ERROR("300"),
    PERSISTENCE_ERROR("301"),
    CIRCUIT_BREAKER_OPEN("305"),

    UNAUTHENTICATED("600"),
    ACCESS_DENIED("601"),
    TOKEN_EXPIRED("602"),

    DUPLICATE_REQUEST("700"),

    INTERNAL_ERROR("900"),
    CONFIGURATION_ERROR("901");

    private final String code;

    ResponseCode(String code) {
        this.code = code;
    }

    /**
     * Valor textual de tres dígitos que viaja en el campo codRespuesta.
     *
     * @return el código de negocio
     */
    public String code() {
        return code;
    }
}
```

### Test de conformidad

Cada servicio debe incluir un test que ancle los valores. Sin él, un cambio accidental en un dígito pasa
inadvertido y rompe a los consumidores en runtime.

```java
@Test
@DisplayName("Los códigos deben coincidir con el catálogo maestro RESPONSE_CODES.md")
void shouldMatchMasterCatalog() {
    assertThat(ResponseCode.SUCCESS.code()).isEqualTo("000");
    assertThat(ResponseCode.VALIDATION_ERROR.code()).isEqualTo("100");
    assertThat(ResponseCode.RESOURCE_NOT_FOUND.code()).isEqualTo("200");
    assertThat(ResponseCode.UNAUTHENTICATED.code()).isEqualTo("600");
    assertThat(ResponseCode.INTERNAL_ERROR.code()).isEqualTo("900");
}

@Test
@DisplayName("No debe haber códigos duplicados en el enum")
void shouldNotHaveDuplicateCodes() {
    Set<String> codes = Arrays.stream(ResponseCode.values())
            .map(ResponseCode::code)
            .collect(Collectors.toSet());
    assertThat(codes).hasSameSizeAs(ResponseCode.values());
}
```

---

## 5. Gobierno del catálogo

### Cómo añadir un código

1. Verificar que no exista ya uno con la misma semántica. La duplicación semántica es el problema más común:
   dos servicios inventando `"310"` y `"311"` para el mismo fallo.
2. Elegir el rango correcto según la tabla de la sección 2.
3. Añadirlo a este archivo con constante, `msgUsuario`, escenario y HTTP asociado.
4. Incrementar la versión del catálogo (semver: *minor* para códigos nuevos, *major* si cambia el significado
   de uno existente).
5. Comunicarlo al equipo antes de publicar el servicio que lo usa.

### Prohibiciones

- **No** crear códigos fuera de los rangos definidos.
- **No** reutilizar un código con un significado distinto al documentado aquí.
- **No** cambiar el valor numérico de un código existente. Si su semántica ya no aplica, marcarlo como
  deprecado y crear uno nuevo.
- **No** mantener variantes del catálogo por microservicio.

### Códigos deprecados

| Código | Constante | Estado | Reemplazo |
|---|---|---|---|
| — | — | — | — |

---

## 6. Historial de versiones

| Versión | Fecha | Cambio |
|---|---|---|
| `1.0.0` | — | Catálogo inicial extraído de `microservices-ai-rules.md` sección 22.2. |
| `1.1.0` | 2026-09-16 | Se añaden rango `6xx` (autenticación/autorización), rango `7xx` (idempotencia/concurrencia), y los códigos `104`, `204`, `205`, `306`. Se reservan explícitamente los rangos `4xx` y `5xx`. |
