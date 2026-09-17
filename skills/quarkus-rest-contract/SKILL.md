---
name: quarkus-rest-contract
description: Diseña o revisa el contrato REST de microservicios Quarkus según el estándar corporativo. Cubre rutas de recursos, códigos HTTP semánticos, DTOs como record, anotaciones OpenAPI, el envoltorio ApiResponse, el catálogo de codRespuesta y los ExceptionMapper. Úsalo cuando el trabajo involucre endpoints, recursos JAX-RS, DTOs, OpenAPI/Swagger, códigos de respuesta, manejo de errores o mapeo de excepciones.
---

# Contrato REST — Quarkus

Referencia normativa: `/home/marco/Documents/manuals/microservices-ai-rules.md`, secciones 3, 4, 6, 12, 14,
15, 22. Catálogo de códigos (fuente de verdad): `/home/marco/Documents/manuals/RESPONSE_CODES.md`.

Ambos viven **fuera** del repositorio del microservicio: léelos con ruta absoluta, no los copies al proyecto.

## Recursos JAX-RS

**Sin scope CDI explícito.** Con `quarkus-rest` (RESTEasy Reactive), añadir `@ApplicationScoped` a un recurso
genera un proxy CDI que interfiere con los interceptores de Bean Validation e impide que `@Valid` dispare.

```java
@Path("/v1/productos")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ProductoResource {
    private final ProductoService productoService;
    public ProductoResource(ProductoService productoService) {  // inyección por constructor
        this.productoService = productoService;
    }
}
```

Toda la cadena retorna `Uni<T>`. Prohibido `List<T>`, `Optional<T>` o respuestas síncronas en capas expuestas,
y prohibido `await()` en producción.

## Rutas

- **Recursos, no acciones.** Sustantivos en plural; el verbo HTTP comunica la intención.
  ```
  POST /v1/whatsapp/deliveries      ✓
  POST /v1/whatsapp/send            ❌ verbo en la ruta
  ```
- **Sin prefijo `/api`.** Solo tiene sentido en monolitos donde coexisten páginas y REST.
- **Versionado desde el primer día**: `/v1/` en la raíz.
- **Namespacing por canal** cuando el servicio agrupa subdominios: `/v1/sms/deliveries`, `/v1/email/deliveries`.
- `kebab-case` en los segmentos.
- **Prohibido** transportar datos sensibles (PAN, cédula, token) como path o query param: quedan en el access
  log, en el proxy y en el historial. Van en el body de un `POST`.

Servicios con el mismo propósito funcional exponen **exactamente** el mismo patrón de ruta y estructura.

## Códigos HTTP semánticos

| Operación | Situación | Código |
|---|---|---|
| `GET` | Encontrado / no encontrado | `200` / `404` |
| `POST` | Recurso creado y persistido | `201` + `Location` header |
| `POST` | Proceso aceptado por proveedor externo | `202` |
| `POST` | Válido pero el proveedor no puede procesarlo | `422` |
| `PUT`/`PATCH` | Actualizado | `200` |
| `DELETE` | Eliminado | `204` |
| Cualquiera | Campos inválidos | `400` |
| Cualquiera | No autenticado / sin permisos | `401` / `403` |

`400` vs `422`: el `400` es petición mal formada (falta un campo, tipo incorrecto, JSON inválido), falla
**antes** del negocio. El `422` es petición estructuralmente válida que el negocio o un sistema externo no
puede procesar.

Retornar `200` para todo priva al consumidor de información semántica. Un delivery worker retorna `202`
cuando el proveedor acepta, no `200`.

## DTOs

**`record` para DTOs de salida e internos.** Jackson deserializa records vía constructor canónico sin
anotaciones extra.

```java
public record ProductoResponseDto(
    @Schema(description = "ID del producto", examples = {"42"}) Long id,
    @Schema(description = "Nombre del producto", examples = {"Laptop Pro"}) String nombre
) {}
```

Clase mutable permitida solo en dos casos, **siempre documentados con Javadoc**: DTOs de entrada de sistemas
externos con clases anidadas que Jackson deserializa con constructor por defecto, y DTOs construidos
incrementalmente en un flujo reactivo.

- Acceso por accessor (`dto.id()`), nunca al campo.
- Campos JSON en `camelCase` semántico. **Prohibido** exponer prefijos de columna de BD (`cnotificacion`,
  `c_notificacion`); usar `@JsonProperty` para mapear.
- **Si el DTO contiene datos sensibles, sobrescribir `toString()`**: el generado por el record expone todos
  los campos en cualquier log o mensaje de excepción.

## OpenAPI

- Todos los campos con `description` y `examples` (arreglo) en `@Schema`.
- **Prohibido** Javadoc en campos de DTO: la documentación de campos es responsabilidad exclusiva de `@Schema`.
- Cada endpoint con `@Operation` (`summary` + `description`) y **todos** los `@APIResponse` que puede retornar.

```java
@Operation(summary = "Iniciar entrega", description = "Inicia el proceso de entrega de una notificación.")
@APIResponse(responseCode = "202", description = "Entrega aceptada por el proveedor")
@APIResponse(responseCode = "400", description = "Error de validación de campos")
@APIResponse(responseCode = "404", description = "Notificación no encontrada")
@APIResponse(responseCode = "422", description = "El proveedor no pudo procesarla")
public Uni<Response> createDelivery(@Valid DeliveryRequest request) { ... }
```

## `ApiResponse<T>` y `codRespuesta`

Único envoltorio permitido, en el paquete `dto`.

`codRespuesta` es un **código de negocio, no un espejo del HTTP status**:

- El éxito **siempre** es `"000"`, sea `200`, `201` o `202`.
- Prohibido devolver el HTTP status como valor (`"404"`, `"500"`). Los rangos `4xx`/`5xx` están reservados.
- Cadenas de tres dígitos.

Reglas de consistencia:

- `data` es `null` cuando `codRespuesta != "000"`.
- `violations` solo presente cuando `codRespuesta == "100"`.
- `msgTecnico` **nunca** stack trace completo; en `%prod`, tampoco el mensaje de la excepción (puede contener
  el valor rechazado, incluido un PAN). Devolver el `correlationId` para que soporte lo busque en el log.

Rangos del catálogo (detalle en `RESPONSE_CODES.md`):

| Rango | Significado | HTTP |
|---|---|---|
| `000` | Éxito | 200/201/202/204 |
| `1xx` | Entrada / contrato | 400, 422 |
| `2xx` | Negocio / dominio | 404, 409, 422 |
| `3xx` | Dependencias externas | 502, 503, 504 |
| `6xx` | Autenticación y autorización | 401, 403 |
| `7xx` | Idempotencia y concurrencia | 409 |
| `9xx` | Internos | 500 |

**Un único `enum ResponseCode`** en el paquete `util` (neutral: lo consumen dominio, adaptadores y REST).
Prohibido escribir los códigos como literales fuera del enum. Consultar `RESPONSE_CODES.md` antes de crear
uno nuevo; incluir un test que ancle los valores.

## ExceptionMapper

**Excepciones de dominio propias.** Prohibido lanzar `NotFoundException`/`BadRequestException` de JAX-RS desde
la capa de servicio: pertenecen a presentación. El mapper es el único que conoce `Response` y HTTP.

Varios mappers, uno por familia de excepciones, es **preferible** a un `switch` gigante: SRP, testeable
aislado, y agregar un tipo es una clase nueva. JAX-RS despacha al mapper cuyo tipo sea el más específico —
mecanismo nativo del spec, sin orden manual.

Requisito no negociable: todos toman el `codRespuesta` del **mismo enum compartido**.

### Mapper genérico sobre `Throwable`, no `RuntimeException`

Con `RuntimeException` se escapan las checked y los `Error`, y el cliente recibe la página HTML de Quarkus en
lugar del contrato.

```java
@Provider
public class GlobalExceptionMapper implements ExceptionMapper<Throwable> {
    @Override
    public Response toResponse(Throwable exception) {
        return switch (exception) {
            case ResourceNotFoundException e -> buildResponse(NOT_FOUND, ..., RESOURCE_NOT_FOUND);
            // Derivar el ResponseCode del status REAL: mapear todo a RESOURCE_NOT_FOUND
            // hace que un 401 o 405 respondan "recurso no encontrado".
            case WebApplicationException wae -> { /* responseCodePorStatus(status) */ }
            default -> {
                LOG.error("[UNHANDLED_ERROR] Excepción no controlada", exception);  // único log del 500
                yield buildResponse(INTERNAL_SERVER_ERROR, mensajeNeutro, ..., INTERNAL_ERROR);
            }
        };
    }
}
```

Logging en mappers: todo 5xx se loguea **exactamente una vez**, a `ERROR`, con stacktrace, y ese lugar es el
mapper genérico. Los 4xx a `DEBUG` (o `WARN` si son de autorización). Prohibido re-loguear la misma excepción
en el servicio y en el mapper.

### Precedencia sobre el handler de Quarkus

`quarkus.hibernate-validator.fail-fast` **no controla esto** — decide si la validación se detiene en la primera
violación, y su default ya es `false`. Si la ves con el comentario "desactiva el handler de Quarkus", bórrala.

La palanca real es la **especificidad del tipo**: `ExceptionMapper<ConstraintViolationException>` es más
específico que el built-in registrado sobre `ValidationException`. Si no dispara, Quarkus está envolviendo en
`ResteasyReactiveViolationException`: declarar sobre `ValidationException` y desempaquetar. `@Priority` no es
fiable para sobrescribir mappers de extensión.

**El wrapping cambia entre versiones de Quarkus.** Verificar con un test de integración que ancle la estructura
de la respuesta 400, o el siguiente upgrade la cambia en silencio y rompe a todos los consumidores.

## Verificación

Todo endpoint nuevo necesita al menos tres tests de integración: flujo feliz con el 2xx correcto y
`codRespuesta: "000"`, validación fallida con `400` + `codRespuesta: "100"` + array `violations`, y recurso no
encontrado con `404` + el `codRespuesta` de dominio.

Añadir un test que confirme que la estructura de validación es la propia (`violations`) y no la de Quarkus
(`parameterViolations`).
