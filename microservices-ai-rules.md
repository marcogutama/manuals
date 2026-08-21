# Estándares y Mejores Prácticas para Microservicios con Agentes de IA
### Stack: Quarkus · Mutiny · MicroProfile · Jakarta EE · Java 25

> **Propósito:** Este documento establece las reglas y convenciones que deben seguirse en el desarrollo de microservicios. Sirve como referencia normativa para modelos de inteligencia artificial y desarrolladores que implementen o revisen código.

---

## 1. Paradigma Reactivo

- Toda la cadena desde el controlador hasta el cliente REST debe ser **no-bloqueante**, utilizando `Uni<T>` de Mutiny.
- Prohibido el uso de tipos bloqueantes (`List<T>`, `Optional<T>`, respuestas síncronas directas) en capas expuestas al cliente.
- Los métodos de servicio y repositorio deben retornar `Uni<T>` o `Multi<T>` según corresponda.

**Correcto:**
```java
public Uni<ProductoDTO> obtenerProducto(Long id) {
    return productoRepository.findById(id)
        .map(productMapper::toDTO);
}
```

**Incorrecto:**
```java
public ProductoDTO obtenerProducto(Long id) {
    return productoRepository.findById(id)
        .map(productMapper::toDTO)
        .await().indefinitely(); // ❌ bloqueante
}
```

---

## 2. Monitoreo y Salud del Servicio

El health check debe implementarse exclusivamente mediante la extensión `quarkus-smallrye-health`. **Prohibido** implementar un `HealthController` manual que retorne `{"status":"UP"}` hardcoded — no verifica dependencias reales y es código muerto.

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-smallrye-health</artifactId>
</dependency>
```

Quarkus expone automáticamente `/q/health`, `/q/health/live` y `/q/health/ready` con checks reales de los clientes REST registrados. No se requiere ninguna clase adicional.

- `/q/health/live` — el proceso está vivo.
- `/q/health/ready` — el servicio está listo para recibir tráfico.
- Las rutas de negocio no deben mezclar lógica de monitoreo ni exponer métricas internas.

---

## 3. Recursos JAX-RS con RESTEasy Reactive

Con `quarkus-rest` (RESTEasy Reactive), los recursos JAX-RS **no deben declarar scope CDI explícito** (`@ApplicationScoped`, `@RequestScoped`, etc.). Quarkus gestiona su ciclo de vida internamente. Agregar un scope CDI hace que CDI genere un proxy que interfiere con los interceptores de Bean Validation, impidiendo que `@Valid` dispare la validación automática.

**Correcto:**
```java
@Path("/v1/productos")
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.APPLICATION_JSON)
public class ProductoResource {

    private final ProductoService productoService;

    public ProductoResource(ProductoService productoService) {
        this.productoService = productoService;
    }
}
```

**Incorrecto:**
```java
@Path("/v1/productos")
@ApplicationScoped  // ❌ rompe @Valid en RESTEasy Reactive
public class ProductoResource { ... }
```

---

## 4. Documentación de API (OpenAPI / Swagger)

### 4.1 Anotaciones en DTOs

- Todos los campos de los DTOs deben incluir `description` y `examples` (como arreglo) en `@Schema`.
- **Prohibido** agregar Javadoc (`/** */`) a los campos de DTOs. La documentación de campos es responsabilidad exclusiva de `@Schema`.

**Correcto:**
```java
@Schema(description = "Identificador único del producto", examples = {"1", "42", "100"})
private Long id;

@Schema(description = "Nombre del producto", examples = {"Laptop Pro", "Mouse Inalámbrico"})
private String nombre;
```

**Incorrecto:**
```java
/** Identificador único del producto */ // ❌ Javadoc en campo de DTO
private Long id;
```

### 4.2 Documentación de Endpoints

- Cada endpoint debe estar anotado con `@Operation`, incluyendo `summary` y `description`.
- Los posibles códigos de respuesta deben documentarse con `@APIResponse`, incluyendo todos los códigos que el endpoint puede retornar.

```java
@Operation(
    summary = "Iniciar entrega de notificación",
    description = "Inicia de forma síncrona el proceso de entrega de una notificación. Retorna el resultado del proveedor."
)
@APIResponse(responseCode = "202", description = "Entrega aceptada por el proveedor")
@APIResponse(responseCode = "400", description = "Petición inválida o error en validación de campos")
@APIResponse(responseCode = "404", description = "Notificación no encontrada")
@APIResponse(responseCode = "422", description = "La notificación existe pero el proveedor no pudo procesarla")
public Uni<Response> createDelivery(@Valid DeliveryRequest request) { ... }
```

---

## 5. Documentación de Código (Javadoc)

- **Obligatorio** en español para todas las clases y métodos, tanto públicos como privados.
- Las descripciones deben ser cortas y concisas; evitar redundancias con el nombre del método.
- No documentar campos de DTO con Javadoc (ver sección 4.1).

**Correcto:**
```java
/**
 * Servicio encargado de la gestión de productos.
 */
@ApplicationScoped
public class ProductoService {

    /**
     * Busca un producto por su identificador.
     *
     * @param id identificador del producto
     * @return el DTO del producto encontrado
     */
    public Uni<ProductoDTO> obtenerPorId(Long id) { ... }
}
```

---

## 6. Diseño de DTOs en Java 25

### 6.1 Records para DTOs inmutables

Los **DTOs de salida e internos** deben modelarse como `record` para garantizar inmutabilidad, eliminar boilerplate y hacer explícito que no deben mutarse. Jackson y Quarkus 3.x deserializan records vía constructor canónico sin anotaciones adicionales.

```java
// Correcto — DTO de salida como record
public record ProductoResponseDto(
    @Schema(description = "ID del producto", examples = {"42"}) Long id,
    @Schema(description = "Nombre del producto", examples = {"Laptop Pro"}) String nombre
) {}
```

### 6.2 Excepciones justificadas para clase mutable

Se permite mantener clase mutable (no `record`) en los siguientes casos, **siempre documentados con Javadoc**:

- DTOs de entrada de sistemas externos con clases anidadas que Jackson debe deserializar con constructor por defecto.
- DTOs construidos incrementalmente en un flujo reactivo (ej. adjuntos resueltos asincrónicamente tras la construcción inicial).

```java
/**
 * Mantenido como clase mutable y no como {@code record} porque es construido
 * de forma incremental: los adjuntos se resuelven asincrónicamente después
 * de la construcción inicial en el flujo reactivo.
 */
public class PersistenceNotificationRequest { ... }
```

### 6.3 Acceso a campos de records

**Prohibido** acceder a campos directamente en records. Usar siempre los accessors generados:

```java
// Correcto
Long id = dto.id();
String nombre = dto.nombre();

// Incorrecto
Long id = dto.id;  // ❌ los records no tienen campos públicos
```

---

## 7. Enums para valores de dominio

Los valores de dominio que aparecen como cadenas literales repetidas en múltiples clases (canales, estados, tipos) deben modelarse como `enum`. **Prohibido** usar strings mágicos para ramificar lógica de negocio.

```java
// Correcto
public enum NotificationChannel {
    SMS, WHATSAPP, EMAIL, MAIL;

    public static NotificationChannel fromString(String value) {
        if (value == null || value.isBlank()) return null;
        try { return valueOf(value.trim().toUpperCase(Locale.ROOT)); }
        catch (IllegalArgumentException e) { return null; }
    }
}

// Uso correcto
if (channel == NotificationChannel.SMS || channel == NotificationChannel.WHATSAPP) { ... }

// Incorrecto — strings mágicos en lógica de negocio
if ("SMS".equals(channel) || "WHATSAPP".equals(channel)) { ... }  // ❌
```

---

## 8. Utilidades de Código Compartido

Los métodos utilitarios de uso general deben residir en clases dedicadas bajo el paquete `util`. **Prohibido** añadir métodos `static` utilitarios en clases de otra responsabilidad (mappers, servicios, DTOs).

```java
// Correcto — clase utilitaria dedicada
public final class StringUtils {
    private StringUtils() {}

    public static String trimToNull(String value) {
        if (value == null) return null;
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    public static String normalize(String value) {
        String trimmed = trimToNull(value);
        return trimmed == null ? "" : trimmed.toUpperCase(Locale.ROOT);
    }
}

// Incorrecto — utilidades de string en un mapper
@ApplicationScoped
public class ProductoMapper {
    static String trimToNull(String v) { ... }  // ❌ SRP violado
}
```

---

## 9. Inyección de Dependencias

- **Obligatorio** usar inyección por constructor en todas las clases.
- **Prohibido** el uso de `@Inject` en campos.
- El constructor debe ser el único punto de entrada de dependencias; facilita las pruebas unitarias y hace explícitas las dependencias.
- En Quarkus/CDI, cuando existe un **único constructor**, `@Inject` es opcional; el contenedor lo detecta automáticamente. Se omite para reducir ruido.

**Correcto:**
```java
@ApplicationScoped
public class ProductoService {

    private final ProductoRepository productoRepository;
    private final ProductoMapper productoMapper;

    // @Inject es opcional con un único constructor en Quarkus CDI
    public ProductoService(ProductoRepository productoRepository, ProductoMapper productoMapper) {
        this.productoRepository = productoRepository;
        this.productoMapper = productoMapper;
    }
}
```

**Incorrecto:**
```java
@ApplicationScoped
public class ProductoService {

    @Inject // ❌ inyección en campo
    ProductoRepository productoRepository;
}
```

---

## 10. Pruebas

### 10.1 Dependencias obligatorias

Todo proyecto debe incluir las siguientes dependencias de prueba:

```xml
<!-- Contexto Quarkus + cobertura JaCoCo -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jacoco</artifactId>
    <scope>test</scope>
</dependency>

<!-- Mocks dentro del contexto CDI de Quarkus -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit-mockito</artifactId>
    <scope>test</scope>
</dependency>

<!-- Tests de endpoint REST -->
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>
```

> **Importante:** `quarkus-jacoco` se engancha al contexto de Quarkus para instrumentar el código. El reporte de cobertura **solo se genera a partir de clases ejecutadas bajo `@QuarkusTest`**. Las pruebas sin `@QuarkusTest` no contribuyen al reporte.

### 10.2 Anotación obligatoria: @QuarkusTest

**Todas** las clases de prueba deben anotarse con `@QuarkusTest`. Para mocks, usar `@InjectMock` (de `quarkus-junit-mockito`) ya que opera dentro del contexto CDI de Quarkus.

### 10.3 Estrategia por tipo de clase

| Clase | Anotación | Razón |
|---|---|---|
| Servicios con dependencias CDI | `@QuarkusTest` + `@InjectMock` | Requiere contexto CDI para inyección |
| Mappers y utilidades | `@QuarkusTest` | Contribuye a JaCoCo; sin mocks necesarios |
| Tests de endpoint REST | `@QuarkusTest` + REST Assured | Verifica el contrato HTTP completo |

### 10.4 Tests de endpoint obligatorios

Todo endpoint nuevo debe tener al menos tres tests de integración:

- **Flujo feliz:** verifica el código 2xx apropiado (`200`, `201`, `202`) con el body esperado, incluyendo `codRespuesta: "000"`.
- **Validación fallida:** verifica `400` con la estructura unificada (`codRespuesta: "100"` y array `violations`).
- **Recurso no encontrado:** verifica `404` con el body del `ExceptionMapper` de dominio y su `codRespuesta` correspondiente.

```java
@QuarkusTest
class ProductoResourceIT {

    @Test
    @DisplayName("Debe responder 200 con codRespuesta 000 en el flujo exitoso")
    void shouldReturn200WithCodRespuesta000() {
        given()
            .contentType(ContentType.JSON)
            .body("{\"nombre\": \"Laptop Pro\"}")
            .when().post("/v1/productos")
            .then()
            .statusCode(200)
            .body("codRespuesta", equalTo("000"))
            .body("data", notNullValue());
    }

    @Test
    @DisplayName("Debe retornar 400 con codRespuesta 100 y violations cuando el campo es inválido")
    void shouldReturn400WithViolationsWhenFieldInvalid() {
        given()
            .contentType(ContentType.JSON)
            .body("{}")
            .when().post("/v1/productos")
            .then()
            .statusCode(400)
            .body("codRespuesta", equalTo("100"))
            .body("violations.field", hasItem("nombre"));
    }

    @Test
    @DisplayName("Debe retornar 404 con codRespuesta de dominio cuando el recurso no existe")
    void shouldReturn404WhenResourceDoesNotExist() {
        given()
            .when().get("/v1/productos/9999")
            .then()
            .statusCode(404)
            .body("codRespuesta", notNullValue())
            .body("msgUsuario", notNullValue());
    }
}
```

### 10.5 Mocks explícitos

**Prohibido** instanciar servicios con dependencias `null` en tests. Toda dependencia debe mockearse explícitamente con `@InjectMock`.

```java
// Incorrecto
new MiServicio(null, "bucket", "prefix");  // ❌ NPE silencioso en extensiones futuras

// Correcto
@InjectMock
MiClienteRest clienteRest;
```

### 10.6 Convenciones de pruebas

- Los nombres de los métodos deben seguir el patrón `should[ComportamientoEsperado]`.
- Cada prueba debe incluir `@DisplayName` con descripción breve y clara.
- Seguir la estructura **Arrange / Act / Assert** (AAA), con comentarios explícitos en pruebas complejas.
- Coverage mínimo esperado: **80%** en lógica de negocio (servicios y casos de uso).

```java
@QuarkusTest
class ProductoServiceTest {

    @InjectMock
    ProductoRepository productoRepository;

    @Inject
    ProductoService productoService;

    @Test
    @DisplayName("Debe retornar el producto cuando existe el ID")
    void shouldReturnProductWhenIdExists() {
        // Arrange
        Long id = 1L;
        Producto producto = new Producto(id, "Laptop Pro");
        when(productoRepository.findById(id)).thenReturn(Uni.createFrom().item(producto));

        // Act
        ProductoDTO resultado = productoService.obtenerPorId(id).await().indefinitely();

        // Assert
        assertThat(resultado.getNombre()).isEqualTo("Laptop Pro");
    }
}
```

---

## 11. Gestión de Secretos y Configuración

- Las contraseñas y credenciales **nunca** deben estar en texto plano en los archivos de propiedades.
- Deben gestionarse como secretos mediante variables de entorno, con un valor por defecto **solo para entornos de prueba**.

```properties
# Correcto: secreto con valor por defecto para pruebas
db.password=${DB_PASSWORD:default_test_password}
api.key=${API_KEY:default_api_key_test}

# Incorrecto: valor en texto plano
db.password=miPasswordSuperSegura123  # ❌
```

- En producción, la variable de entorno debe estar definida y el valor por defecto nunca debe usarse.

---

## 12. Manejo de Errores y Excepciones

### 12.1 Excepciones de dominio

Definir excepciones de dominio propias. **Prohibido** lanzar excepciones JAX-RS (`NotFoundException`, `BadRequestException`) desde la capa de servicio — estas pertenecen exclusivamente a la capa de presentación.

```java
// Correcto — excepción de dominio sin dependencia de JAX-RS
public class RecursoNoEncontradoException extends RuntimeException {
    public RecursoNoEncontradoException(String message) { super(message); }
}

// Incorrecto — excepción HTTP en la capa de servicio
throw new NotFoundException("Producto no encontrado");  // ❌
```

### 12.2 ExceptionMapper — uno o varios, según el tipo de excepción

JAX-RS despacha cada excepción al `ExceptionMapper<T>` cuyo tipo `T` sea el **más específico** que aplique — este mecanismo es nativo del spec, no requiere lógica de ordenamiento manual. Por eso está permitido y es preferible tener **varios mappers**, uno por familia de excepciones, en lugar de forzar toda la lógica en un único `ExceptionMapper<RuntimeException>` con un `switch`/`instanceof` gigante:

- **A favor de varios mappers:** cada uno cumple el Principio de Responsabilidad Única, se testea de forma aislada, y agregar un nuevo tipo de excepción es una clase nueva (abierto/cerrado) en vez de tocar un `switch` que ya maneja varios casos.
- **Requisito no negociable:** todos los mappers del proyecto —sin importar cuántos sean— deben tomar el valor de `codRespuesta` de un **único enum compartido** que represente el catálogo de la sección 22.2 (ver `ResponseCode` más abajo). **Prohibido** escribir el código como string literal (`"200"`, `"900"`...) en más de un lugar; eso es lo que realmente rompe la consistencia entre microservicios, no la cantidad de clases mapper.

```java
// Enum compartido — única fuente de verdad para codRespuesta (catálogo, sección 22.2)
// El nombre debe ser en inglés conforme a la sección 16 (Nomenclatura y Convenciones)
public enum ResponseCode {
    SUCCESS("000"),
    VALIDATION_ERROR("100"),
    RESOURCE_NOT_FOUND("200"),
    BUSINESS_RULE_VIOLATION("203"),
    DOWNSTREAM_ERROR("300"),
    PERSISTENCE_ERROR("301"),
    DISPATCH_ERROR("302"),
    INTERNAL_ERROR("900");
    // ... resto del catálogo de la sección 22.2

    private final String code;
    ResponseCode(String code) { this.code = code; }
    public String code() { return code; }
}

// Mapper específico — más concreto que RuntimeException, JAX-RS lo prioriza automáticamente
@Provider
public class ValidationExceptionMapper implements ExceptionMapper<ConstraintViolationException> {

    @Override
    public Response toResponse(ConstraintViolationException exception) {
        List<ApiResponse.Violation> violations = /* ... */;
        return Response.status(Response.Status.BAD_REQUEST)
                .entity(ApiResponse.validationError("Constraint Violation", violations)) // usa ResponseCode.VALIDATION_ERROR internamente
                .build();
    }
}

// Mapper genérico — captura todo lo que no tiene mapper específico
@Provider
public class GlobalExceptionMapper implements ExceptionMapper<RuntimeException> {

    @Override
    public Response toResponse(RuntimeException exception) {
        return switch (exception) {
            case ResourceNotFoundException rnfe -> buildResponse(Response.Status.NOT_FOUND,
                    "Recurso no encontrado", rnfe.getMessage(), ResponseCode.RESOURCE_NOT_FOUND);
            // WebApplicationException cubre NotFoundException, BadRequestException y cualquier
            // otro error HTTP nativo de JAX-RS (404, 405, etc.) generado p.ej. por el escáner DAST.
            // Se registra en debug para evitar ruido en los logs y se retorna el código HTTP original.
            case WebApplicationException wae -> {
                Log.debugf("Excepción HTTP JAX-RS (ej. 404, 405): %s", wae.getMessage());
                yield Response.status(wae.getResponse().getStatus())
                        .type(MediaType.APPLICATION_JSON)
                        .entity(ApiResponse.error(
                                "Recurso no encontrado o método no permitido",
                                wae.getMessage(),
                                ResponseCode.RESOURCE_NOT_FOUND.code()))
                        .build();
            }
            default -> buildResponse(Response.Status.INTERNAL_SERVER_ERROR,
                    "Ha ocurrido un error inesperado. Por favor contacte al soporte técnico.",
                    exception.getMessage(), ResponseCode.INTERNAL_ERROR);
        };
    }

    private Response buildResponse(Response.Status status, String msgUsuario,
                                   String msgTecnico, ResponseCode codigo) {
        return Response.status(status)
                .type(MediaType.APPLICATION_JSON)
                .entity(ApiResponse.error(msgUsuario, msgTecnico, codigo.code()))
                .build();
    }
}
```

El mapper (o mappers) es el **único punto** que conoce JAX-RS y traduce a HTTP. Las capas de servicio y cliente nunca deben conocer `Response` ni códigos HTTP — pero sí pueden (y deben) referenciar `ResponseCode` cuando necesiten expresar un resultado de negocio, ya que es un código de dominio, no un detalle de transporte HTTP.

> **Nota de ubicación:** `ResponseCode` es consumido por capas de dominio, adaptadores de proveedores externos y la capa REST por igual. Para no crear una dependencia inversa (dominio → presentación), el enum debe vivir en un paquete neutral compartido (ej. `util` o `common`), nunca dentro del paquete `resource`/`rest` de la capa de presentación.

> **Sobre la precedencia con `ConstraintViolationException`:** al tener su propio mapper (`ValidationExceptionMapper implements ExceptionMapper<ConstraintViolationException>`), JAX-RS lo selecciona automáticamente por ser más específico que `ExceptionMapper<RuntimeException>` — no hace falta ningún `instanceof` ni orden manual para este caso.

### 12.3 Prioridad de los ExceptionMapper de la aplicación sobre el handler de Quarkus

Por defecto, Quarkus tiene su propio handler para `ConstraintViolationException` que produce una respuesta con estructura propia. Para garantizar que los `ExceptionMapper` de la aplicación (sea uno solo o varios, ver 12.2) tengan precedencia, agregar en `application.properties`:

```properties
# Desactiva el handler automático de Quarkus para ConstraintViolationException
quarkus.hibernate-validator.fail-fast=false
```

### 12.4 No propagar excepciones técnicas al cliente

`SQLException`, `NullPointerException`, stack traces y mensajes internos de la JVM **nunca** deben llegar al cuerpo de la respuesta. El `GlobalExceptionMapper` debe capturarlos en el caso `else` genérico y devolver siempre el mensaje neutro con `codRespuesta: "900"`.

---

## 13. Estructura de Paquetes y Elección de Arquitectura

### 13.1 Principio general

No existe una arquitectura única por defecto para microservicios. La elección depende de la **complejidad del dominio**, no de una convención fija. Sobre-arquitecturar un servicio CRUD con hexagonal es tan perjudicial como no arquitecturar uno con dominio complejo.

### 13.2 Arquitectura en capas (Layered) — recomendada por defecto

**Usar cuando:** el microservicio es predominantemente CRUD o de orquestación, con lógica de negocio delgada. Es la arquitectura de partida para la mayoría de los microservicios de soporte, integración y orquestación.

```
ec.fin.baustro.servicio
├── resource         # Controladores REST (JAX-RS)
├── service          # Lógica de negocio y orquestación
├── client           # Clientes REST externos (@RegisterRestClient)
├── dto              # DTOs de entrada y salida
├── exception        # Excepciones de dominio y ExceptionMappers
├── enums            # Enumeraciones de dominio
└── util             # Utilidades compartidas (StringUtils, etc.)
```

### 13.3 Arquitectura Hexagonal (Ports & Adapters)

**Usar cuando:** el microservicio tiene lógica de dominio no trivial que debe ser completamente independiente de la infraestructura, múltiples adaptadores de entrada/salida intercambiables, o requisito de testear el dominio sin ninguna dependencia externa.

```
ec.fin.baustro.servicio
├── api                  # Adaptadores de entrada: controladores REST y DTOs
│   ├── controller
│   └── dto
├── application          # Casos de uso / servicios de aplicación
├── domain               # Entidades, puertos, excepciones de dominio
│   ├── model
│   ├── port
│   └── exception
└── infrastructure       # Adaptadores de salida: repositorios, clientes HTTP
    ├── persistence
    └── client
```

### 13.4 Criterio de decisión

| Característica del servicio | Arquitectura recomendada |
|---|---|
| CRUD simple o gateway/orquestador | Capas (Layered) |
| Reglas de negocio complejas e intercambiables | Hexagonal |
| Equipo grande, features independientes entre sí | Clean Architecture / Vertical Slices |
| Microservicio nuevo sin dominio definido aún | Capas (Layered), migrar si crece |

---

## 14. Diseño de API REST

### 14.1 Estructura de rutas — recursos, no acciones

Los endpoints deben representar **recursos** (sustantivos en plural), no acciones. El verbo HTTP ya comunica la intención; incluir verbos de acción en la ruta es una violación de los principios REST.

**Correcto:**
```
POST /v1/whatsapp/deliveries      # crea/inicia una entrega
POST /v1/sms/deliveries
POST /v1/email/deliveries
GET  /v1/whatsapp/deliveries/{id} # consulta el estado de una entrega
```

**Incorrecto:**
```
POST /v1/whatsapp/send      # ❌ verbo de acción en la ruta
POST /v1/sms/sendMessage    # ❌ verbo de acción en la ruta
POST /v1/notifications/process  # ❌ verbo de acción en la ruta
```

### 14.2 Prefijo `/api` — omitir en microservicios dedicados

**Prohibido** incluir el prefijo `/api` en las rutas de microservicios. El prefijo tiene sentido únicamente en monolitos donde coexisten rutas de páginas web y endpoints REST en el mismo servidor. En un microservicio dedicado es ruido que no aporta información.

```
# Correcto — microservicio dedicado
/v1/whatsapp/deliveries

# Incorrecto — prefijo redundante en microservicio
/api/v1/whatsapp/deliveries   # ❌
```

### 14.3 Namespacing por canal o dominio

Cuando un servicio agrupa recursos de varios canales o subdominios, usar el canal/subdominio como primer segmento de ruta antes del recurso. Esto crea un namespace claro y permite extender la API sin colisiones.

```
/v1/whatsapp/deliveries
/v1/sms/deliveries
/v1/email/deliveries
```

### 14.4 Nombres de campos en el contrato JSON

Los nombres de campos del contrato JSON deben ser **semánticos y autodescriptivos** en `camelCase`. **Prohibido** exponer convenciones internas de base de datos (prefijos de columna como `c`, `t`, `n`) en el contrato de la API.

**Correcto:**
```json
{ "notificationId": 13 }
```

**Incorrecto:**
```json
{ "cnotificacion": 13 }   // ❌ prefijo de columna expuesto en el contrato
{ "c_notificacion": 13 }  // ❌ snake_case con prefijo de BD
```

```java
// Correcto — el @JsonProperty mapea el contrato externo al nombre interno
public record DeliveryRequest(
    @NotNull(message = "El campo notificationId es requerido")
    @Schema(description = "Identificador de la notificación a entregar", examples = {"13", "42"})
    @JsonProperty("notificationId")
    Long notificationId
) {}
```

### 14.5 Consistencia entre microservicios del mismo dominio

Los microservicios que comparten el mismo contrato de entrada y el mismo propósito funcional deben exponer **exactamente el mismo patrón de ruta y la misma estructura de request/response**.

| Microservicio | Endpoint REST | Cola asíncrona |
|---|---|---|
| WhatsAppDeliveryWorker | `POST /v1/whatsapp/deliveries` | `whatsapp-in` |
| SmsDeliveryWorker | `POST /v1/sms/deliveries` | `sms-in` |
| EmailDeliveryWorker | `POST /v1/email/deliveries` | `email-in` |

---

## 15. Códigos de Respuesta HTTP Semánticos

El uso correcto de los códigos HTTP es parte del contrato de la API. Retornar `200 OK` para todas las respuestas exitosas es incorrecto y priva al consumidor de información semántica relevante.

### 15.1 Tabla de referencia por operación

| Operación | Situación | Código correcto |
|---|---|---|
| `GET` | Recurso encontrado | `200 OK` |
| `GET` | Recurso no encontrado | `404 Not Found` |
| `POST` | Recurso creado y persistido | `201 Created` |
| `POST` | Proceso iniciado / aceptado por proveedor externo | `202 Accepted` |
| `POST` | Request válida, pero el proveedor no puede procesarla | `422 Unprocessable Entity` |
| `PUT` / `PATCH` | Recurso actualizado | `200 OK` |
| `DELETE` | Recurso eliminado | `204 No Content` |
| Cualquiera | Campos inválidos o ausentes | `400 Bad Request` |
| Cualquiera | No autenticado | `401 Unauthorized` |
| Cualquiera | Autenticado pero sin permisos | `403 Forbidden` |
| Cualquiera | Error interno del servidor | `500 Internal Server Error` |

### 15.2 Distinción entre 400 y 422

- `400 Bad Request` — la petición está mal formada: campo obligatorio ausente, tipo de dato incorrecto, JSON inválido. La validación falla **antes** de intentar procesar el negocio.
- `422 Unprocessable Entity` — la petición es estructuralmente válida y los campos pasan la validación, pero la **lógica de negocio o un sistema externo** no puede procesarla.

### 15.3 Uso de 202 Accepted en workers de entrega

Los microservicios de tipo delivery worker deben retornar `202 Accepted` cuando el proveedor externo acepta el mensaje para procesamiento, **no** `200 OK`.

```java
// Correcto
return service.sendSync(request.notificationId())
    .map(response -> {
        if (response.accepted()) {
            return Response.accepted(response).build();           // 202
        } else {
            return Response.status(422).entity(response).build(); // 422
        }
    });

// Incorrecto
return Response.ok(response).build(); // ❌ 200 para toda situación
```

### 15.4 Incluir Location header en 201 Created

```java
URI location = uriInfo.getAbsolutePathBuilder()
    .path(String.valueOf(recurso.getId()))
    .build();

return Response.created(location).entity(recurso).build();
```

---

## 16. Nomenclatura y Convenciones de Código

- **Idioma de clases:** Todos los nombres de clases, interfaces, records y enums deben ser redactados en **inglés** obligatoriamente. Los comentarios, Javadocs y mensajes orientados al usuario final o logs de negocio locales pueden permanecer en español.

| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | `PascalCase` | `ProductService` |
| Métodos y variables | `camelCase` | `getProduct` |
| Constantes | `UPPER_SNAKE_CASE` | `MAX_RETRIES` |
| Paquetes | `lowercase` | `ec.fin.baustro.api` |
| Endpoints REST — segmentos de ruta | `kebab-case` en plural, sin prefijo `/api` | `/v1/products`, `/v1/whatsapp/deliveries` |
| Campos JSON de contrato de API | `camelCase` semántico, sin prefijos de BD | `notificationId`, `purchaseOrderId` |
| Variables de entorno | `UPPER_SNAKE_CASE` | `DB_PASSWORD`, `API_KEY` |
| Excepciones de dominio | `PascalCase` + sufijo `Exception` | `ResourceNotFoundException` |
| ExceptionMappers | mismo nombre + sufijo `Mapper` | `ResourceNotFoundExceptionMapper` |
| Clases utilitarias | `PascalCase` + sufijo `Utils` | `StringUtils`, `DateUtils` |
| Enums de dominio | `PascalCase` singular | `NotificationChannel`, `NotificationStatus` |
| Tests de servicio | sufijo `Test` | `ProductServiceTest` |
| Tests de integración REST | sufijo `IT` | `ProductResourceIT` |

---

## 17. Seguridad

- Validar **todas** las entradas del cliente con Bean Validation (`@NotNull`, `@Size`, `@Pattern`, etc.).
- Nunca registrar en logs datos sensibles: contraseñas, tokens, PII.
- Implementar autenticación con JWT y autorización basada en roles (`@RolesAllowed`).
- Configurar CORS explícitamente; evitar `*` en producción.
- Usar HTTPS obligatoriamente en todos los entornos fuera de desarrollo local.

---

## 18. Logging y Trazabilidad Distribuida

### 18.1 Principio general

El objetivo no es solo registrar eventos: es poder **seguir un mismo request a través de varios microservicios** usando un único identificador. Esto se resuelve con tres piezas — un Correlation ID propagado en el borde, MDC poblado una sola vez, y logging estructurado por perfil — sin necesidad de introducir un stack de trazas distribuidas (Jaeger/Zipkin/OpenTelemetry) salvo que el proyecto lo requiera explícitamente.

### 18.2 API de logging

- Usar el mecanismo idiomático de Quarkus según la versión del proyecto:
  - **Quarkus 3.x (recomendado):** anotación `@io.quarkus.logging.Log`.
  - **Alternativa compatible:** `org.jboss.logging.Logger` instanciado manualmente.
- **Prohibido** usar `System.out.println`, `e.printStackTrace()`, o loggers de otras librerías.
- Elegir una sola API de logging por proyecto y mantenerla consistente en todas las clases.
- Al usar `Logger.warnf`/`errorf` con una excepción, el `Throwable` va como **primer** argumento: `LOG.errorf(e, "mensaje %s", valor)`, nunca `LOG.errorf("mensaje %s", valor, e)`.

```java
// Correcto
LOG.warnf(e, "[WARN-SKIP] No se pudo cerrar la respuesta (correlationId=%s)",
        CorrelationContext.getCorrelationId());

// Incorrecto — el stacktrace se descarta silenciosamente
LOG.warnf("[WARN-SKIP] No se pudo cerrar la respuesta (correlationId=%s)",
        CorrelationContext.getCorrelationId(), e);  // ❌
```

- Niveles recomendados: `DEBUG` (flujo interno), `INFO` (eventos de negocio), `WARN` (anomalías no críticas), `ERROR` (fallos que requieren atención).

### 18.3 Correlation ID — propagación end-to-end

| Elemento | Valor estándar |
|---|---|
| Header HTTP | `X-Correlation-Id` |
| Clave MDC | `correlationId` |
| Clase utilitaria | `util/CorrelationContext.java` |
| Filtro JAX-RS (servidor) | `filter/CorrelationFilter.java` |
| Filtro de cliente REST (saliente) | `filter/CorrelationClientFilter.java` |

**`CorrelationContext`:**
```java
public final class CorrelationContext {

    public static final String HEADER_NAME = "X-Correlation-Id";
    public static final String MDC_KEY = "correlationId";
    public static final String MDC_SERVICE_KEY = "service";

    private CorrelationContext() {}

    public static String initCorrelation(String incomingCorrelationId) {
        String id = (incomingCorrelationId != null && !incomingCorrelationId.isBlank())
                ? incomingCorrelationId
                : UUID.randomUUID().toString();
        MDC.put(MDC_KEY, id);
        return id;
    }

    public static String getCorrelationId() {
        Object val = MDC.get(MDC_KEY);
        return val != null ? val.toString() : null;
    }

    public static void clear() {
        MDC.remove(MDC_KEY);
        MDC.remove(MDC_SERVICE_KEY);
    }
}
```

**`CorrelationFilter`** — único lugar donde se llama `MDC.put`/`MDC.remove` en el servicio:
```java
@Provider
public class CorrelationFilter implements ContainerRequestFilter, ContainerResponseFilter {

    private static final Logger LOG = Logger.getLogger(CorrelationFilter.class);
    private static final String REQUEST_START_TIME = "X-Request-Start-Time";
    private static final String SERVICE_NAME = "nombre-del-microservicio"; // ajustar por servicio

    @Override
    public void filter(ContainerRequestContext req) {
        String resolvedId = CorrelationContext.initCorrelation(req.getHeaderString(CorrelationContext.HEADER_NAME));
        MDC.put(CorrelationContext.MDC_SERVICE_KEY, SERVICE_NAME);
        req.setProperty(REQUEST_START_TIME, System.currentTimeMillis());
        LOG.infof("[REQUEST_IN] method=%s uri=%s correlationId=%s",
                req.getMethod(), req.getUriInfo().getRequestUri(), resolvedId);
    }

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        String correlationId = CorrelationContext.getCorrelationId();
        if (correlationId != null) {
            res.getHeaders().add(CorrelationContext.HEADER_NAME, correlationId);
        }
        Long startTime = (Long) req.getProperty(REQUEST_START_TIME);
        long latencyMs = startTime != null ? System.currentTimeMillis() - startTime : -1;
        LOG.infof("[REQUEST_OUT] status=%d latencyMs=%d correlationId=%s",
                res.getStatus(), latencyMs, correlationId);
        CorrelationContext.clear();
    }
}
```

**`CorrelationClientFilter`** — propaga el ID a toda llamada REST saliente:
```java
@Provider
public class CorrelationClientFilter implements ClientRequestFilter {

    @Override
    public void filter(ClientRequestContext requestContext) {
        String correlationId = (String) MDC.get("correlationId");
        if (correlationId != null) {
            requestContext.getHeaders().putSingle("X-Correlation-Id", correlationId);
        }
    }
}
```

**Regla no negociable: el MDC se siembra solo en el borde, nunca en el código de negocio.**

```java
// Correcto — el código de negocio no toca el MDC
Log.infof("[NOTIFICATION_PERSISTED] cNotificacion=%d", notificacion.getId());

// Incorrecto — reintroduce dependencia manual
Log.infof("[NOTIFICATION_PERSISTED] cNotificacion=%d correlationId=%s",
        notificacion.getId(), CorrelationContext.getCorrelationId());  // ❌
```

### 18.4 Correlation ID a través de colas AMQP (asíncrono)

El Correlation ID viaja **dentro del body del mensaje** como un campo del DTO:

```java
public record WhatsappDeliveryMessage(
        @JsonProperty("cnotificacion") Long cNotificacion,
        @JsonProperty("correlationId") String correlationId
) {}
```

```java
@Incoming("whatsapp-in")
public Uni<Void> consume(JsonObject jsonMessage) {
    WhatsappDeliveryMessage message = jsonMessage.mapTo(WhatsappDeliveryMessage.class);
    String correlationId = (message.correlationId() != null && !message.correlationId().isBlank())
            ? message.correlationId()
            : UUID.randomUUID().toString();
    MDC.put("correlationId", correlationId);
    MDC.put("service", "nombre-del-microservicio");
    LOG.infof("[AMQ_CONSUMED] queue=nombreDeLaCola cNotificacion=%d", message.cNotificacion());
    return service.process(message.cNotificacion())
            .onFailure().invoke(e -> LOG.errorf(e, "[AMQ_FAILED] cNotificacion=%d", message.cNotificacion()))
            .eventually(() -> {
                MDC.remove("correlationId");
                MDC.remove("service");
                return Uni.createFrom().voidItem();
            });
}
```

#### 18.4.1 MDC y saltos de hilo en código reactivo (Mutiny)

En una cadena `Uni<T>`, cada operador puede ejecutarse en un hilo distinto. Capturar el correlationId **antes del salto** y restaurarlo dentro del callback:

```java
// Correcto
String correlationId = CorrelationContext.getCorrelationId();

emitter.send(message).whenComplete((result, failure) -> {
    MDC.put("correlationId", correlationId);
    if (failure != null) {
        LOG.errorf(failure, "[AMQ_PUBLISH_FAILED] correlationId=%s", correlationId);
    } else {
        LOG.infof("[AMQ_PUBLISH] correlationId=%s", correlationId);
    }
    MDC.remove("correlationId");
});
```

### 18.5 `application.properties` — perfiles y logging estructurado

```properties
# --- DEV: consola legible para humanos ---
%dev.quarkus.log.console.format=%d{HH:mm:ss.SSS} %-5p [%c{2.}] (%t) [%X{correlationId}] %s%e%n
%dev.quarkus.log.level=INFO
%dev.quarkus.log.category."ec.fin.baustro".level=DEBUG

# --- QA: JSON estructurado ---
%qa.quarkus.log.console.json=true
%qa.quarkus.log.level=INFO
%qa.quarkus.log.category."ec.fin.baustro".level=INFO
%qa.quarkus.log.console.json.additional-field.env.value=qa
%qa.quarkus.log.console.json.additional-field.env.type=string

# --- PROD: JSON estructurado, ruido de frameworks reducido ---
%prod.quarkus.log.console.json=true
%prod.quarkus.log.level=WARN
%prod.quarkus.log.category."ec.fin.baustro".level=INFO
%prod.quarkus.log.console.json.additional-field.env.value=prod
%prod.quarkus.log.console.json.additional-field.env.type=string

# --- Tramas REST Client salientes — solo dev/qa, nunca prod ---
%dev.quarkus.rest-client.logging.scope=request-response
%dev.quarkus.rest-client.logging.body-limit=4096
%qa.quarkus.rest-client.logging.scope=request-response
%qa.quarkus.rest-client.logging.body-limit=1024
%prod.quarkus.rest-client.logging.scope=none

# --- Access log HTTP entrante ---
%dev.quarkus.http.access-log.enabled=true
%dev.quarkus.http.access-log.pattern="%r %s %b ms=%D"
%qa.quarkus.http.access-log.enabled=true
%qa.quarkus.http.access-log.pattern="%r %s %b"
%prod.quarkus.http.access-log.enabled=false
```

> **Si se usa logging JSON** (`quarkus-logging-json`), agregar los campos MDC con la sintaxis correcta `.additional-field.<nombre>.value` + `.type`:
> ```properties
> quarkus.log.console.json.additional-field.correlationId.value=%X{correlationId}
> quarkus.log.console.json.additional-field.correlationId.type=string
> quarkus.log.console.json.additional-field.service.value=%X{service}
> quarkus.log.console.json.additional-field.service.type=string
> ```
> La forma `additional-fields` (plural, una sola línea) **no es válida**.

**Nunca activar logging de tramas completas sin gate de perfil** — expone PII en producción.

### 18.6 PII en categorías de log de librerías de infraestructura

Algunas extensiones de Quarkus loguean PII a niveles que parecen inofensivos (`quarkus-mailer` imprime destinatario y cuerpo a nivel `INFO`). Siempre revisar antes de subir el nivel de una categoría externa y aplicar gate por perfil.

```properties
%dev.quarkus.log.category."io.quarkus.mailer".level=DEBUG
%qa.quarkus.log.category."io.quarkus.mailer".level=INFO
%prod.quarkus.log.category."io.quarkus.mailer".level=WARN
```

### 18.7 Catálogo de eventos — prefijos estandarizados

| Prefijo | Cuándo se usa |
|---|---|
| `[REQUEST_IN]` | Entrada a un endpoint HTTP |
| `[REQUEST_OUT]` | Salida de un endpoint HTTP, con status code y latencia |
| `[AMQ_CONSUMED]` | Mensaje recibido desde una cola AMQP |
| `[AMQ_PUBLISH]` | Mensaje publicado exitosamente en una cola AMQP |
| `[AMQ_PUBLISH_FAILED]` / `[AMQ_FAILED]` | Falla al publicar o procesar un mensaje AMQP |
| `[DELIVERY_SENDING]` / `[DELIVERY_SENT]` | Envío iniciado / aceptado por un proveedor externo |
| `[DELIVERY_FAILED_TEMP]` / `[DELIVERY_FAILED_PERM]` | Falla temporal / permanente en la entrega |
| `[WARN-SKIP]` | Situación anómala no crítica que se omite sin interrumpir el flujo |

### 18.8 Checklist de implementación para un microservicio nuevo

1. Crear `util/CorrelationContext.java` y `filter/CorrelationFilter.java`, ajustando `SERVICE_NAME`.
2. Crear `filter/CorrelationClientFilter.java`.
3. Si consume colas AMQP: agregar el campo `correlationId` al DTO de mensaje y sembrar/limpiar MDC en `@Incoming`.
4. Si se usa JSON logging: agregar dependencia `quarkus-logging-json` al `pom.xml`.
5. Configurar `application.properties` con gate por perfil en todo lo que loguee tramas o body.
6. Revisar las categorías de logging de extensiones con datos del cliente (sección 18.6).
7. Prefijar los logs de eventos con el catálogo de la sección 18.7.
8. **No** llamar `CorrelationContext.getCorrelationId()` desde el código de negocio.

---

## 19. Versionado de API

- Versionar los endpoints desde la primera publicación usando `/v1/` directamente en la raíz, sin prefijo `/api`.
- Nunca eliminar ni romper contratos de versiones activas; deprecar antes de eliminar.
- Indicar la deprecación con `@Deprecated` en el código y en la anotación OpenAPI correspondiente.
- Al introducir `/v2/`, mantener la versión anterior activa durante un periodo de transición acordado.

---

## 20. Comunicación entre Microservicios

- Usar clientes REST tipados (`@RegisterRestClient`) para comunicación síncrona.
- Para comunicación asíncrona, preferir mensajería (Kafka, RabbitMQ, AMQ) sobre llamadas directas.
- Implementar `@CircuitBreaker`, `@Retry` y `@Timeout` en todos los clientes externos.

### 20.1 Externalizar parámetros de resiliencia en properties

**Prohibido** hardcodear los valores en las anotaciones. Externalizarlos en `application.properties`:

```java
@GET
@CircuitBreaker(requestVolumeThreshold = 4)
@Retry(maxRetries = 3, delay = 1000)
@Timeout(value = 5000)
Uni<List<ReglaConfigDto>> getRules(@QueryParam("cevento") String cEvento,
                                   @QueryParam("corigen") String cOrigen);
```

```properties
ec.fin.baustro.client.PersistenceClient/getRules/Retry/maxRetries=${PERSISTENCE_RETRY_MAX:3}
ec.fin.baustro.client.PersistenceClient/getRules/Retry/delay=${PERSISTENCE_RETRY_DELAY_MS:1000}
ec.fin.baustro.client.PersistenceClient/getRules/Timeout/value=${PERSISTENCE_TIMEOUT_MS:5000}
```

### 20.2 Propagación de ID de correlación

Ver sección 18.3. El header estándar es `X-Correlation-Id` (no `X-Request-ID` ni otra variante) — idéntico en los 4 puntos de propagación.

### 20.3 Acotar `@Retry`, `@CircuitBreaker` y `@Fallback` a fallos transitorios

**Prohibido** declarar `@Retry` y `@CircuitBreaker` sin parámetros de clasificación de excepciones.
Por defecto, MicroProfile Fault Tolerance reintenta ante **cualquier** `Exception`, incluyendo
errores no transitorios (4xx, validación, datos no encontrados). Esto desperdicia reintentos,
retrasa la respuesta al cliente y puede enmascarar bugs reales como si fueran fallos de red.

#### Regla de oro: `@Retry` es lista blanca; `@CircuitBreaker`/`@Fallback` son lista negra

- `@Retry(retryOn = {...})`: **solo** lo listado se reintenta. Todo lo demás aborta
  automáticamente — por tanto, declarar `abortOn` con excepciones que ya están fuera de
  `retryOn` es redundante y debe evitarse.
- `@CircuitBreaker` y `@Fallback` evalúan por defecto **cualquier** `Throwable` como fallo.
  `skipOn` es la única forma de excluir explícitamente una excepción (p. ej. un 4xx) de contar
  como fallo de infraestructura o de disparar el fallback. Aquí `skipOn` **no** es opcional.

**Correcto** (cliente REST reactivo de Quarkus — `quarkus-rest-client-*`):
```java
@CircuitBreaker(skipOn = { jakarta.ws.rs.ClientErrorException.class })
@Retry(retryOn = {
    jakarta.ws.rs.ProcessingException.class,   // timeouts y fallos de transporte (Vert.x/Netty)
    jakarta.ws.rs.ServerErrorException.class   // 5xx del servidor remoto
})
@Fallback(value = MiFallback.class, skipOn = { jakarta.ws.rs.ClientErrorException.class })
public Uni<Respuesta> llamarServicio(...) { ... }
```

**Incorrecto:**
```java
@CircuitBreaker
@Retry
@Fallback(MiFallback.class)   // ❌ reintenta y abre el circuito también ante 4xx y errores de validación
```

#### Por qué `ProcessingException` y no `ConnectException`/`TimeoutException` sueltos

En `quarkus-rest-client` (RESTEasy Reactive sobre Vert.x/Netty), los fallos de conexión y
timeout se propagan encapsulados en `jakarta.ws.rs.ProcessingException` — la causa anidada
puede ser `ConnectException`, `NoStackTraceTimeoutException`, etc., pero el tipo lanzado en el
nivel superior (el que evalúa `retryOn`) siempre es `ProcessingException`. Listar las causas
anidadas por separado en `retryOn` es código muerto: nunca llegan a evaluarse porque
`ProcessingException` ya resuelve el match antes.

> **No asumir esto de memoria.** Verificar contra la versión exacta de Quarkus del proyecto
> (el comportamiento de *wrapping* ha cambiado entre versiones) y, antes de cerrar el PR,
> confirmar con una prueba de integración (p. ej. WireMock con retraso mayor al `read-timeout`,
> o simulando conexión rechazada) qué excepción concreta se lanza. Un test unitario con mocks
> **no** es evidencia válida — nunca dispara un timeout de socket real.

#### Límite del alcance reactivo: no mezclar capas

Una excepción de dominio (p. ej. `ResourceNotFoundException`) que se lanza en el *consumidor*
del `Uni` — no en el método REST-cliente anotado — **nunca** debe aparecer en `abortOn`,
`skipOn` o `failOn` de ese método. No tiene ningún efecto (el interceptor de Fault Tolerance
solo ve las fallas que ocurren dentro del método que anota) y es ruido que sugiere una
comprensión incorrecta del límite entre la llamada HTTP y la lógica de negocio que la consume.

Antes de añadir cualquier excepción a estas anotaciones, preguntar: **¿esta excepción la lanza
directamente el método anotado, o la lanza otro bean más adelante en la cadena reactiva?**
Solo la primera pertenece aquí.

#### Presupuesto de tiempo documentado

Cuando se combinan `@Retry` con `delay` y timeouts de REST client, documentar en el README el
peor caso real, incluyendo el `delay` entre reintentos (no solo `timeout × intentos`):

```
peor_caso_por_llamada = (read-timeout × (maxRetries + 1)) + (delay × maxRetries)
```

Si el flujo encadena varias llamadas externas, multiplicar por el número de llamadas y
verificar que el resultado sea compatible con cualquier SLA de la vía de entrada (AMQP, síncrono, etc.).
Si un escenario de fallo queda deliberadamente fuera de cobertura (p. ej. cierre de conexión a
mitad de transferencia), dejarlo anotado explícitamente como decisión consciente, no como omisión.

---

## 21. Organización de `application.properties`

### 21.1 Orden de bloques recomendado

```properties
# ============================================================
# APPLICATION
# ============================================================
quarkus.application.name=...
quarkus.application.version=1.0.0
quarkus.banner.enabled=false

# ============================================================
# REST CLIENTS — <Nombre del servicio externo>
# ============================================================
%dev.quarkus.rest-client.x-service.url=...
%qa.quarkus.rest-client.x-service.url=...
%prod.quarkus.rest-client.x-service.url=...
quarkus.rest-client.x-service.connect-timeout=3000
quarkus.rest-client.x-service.read-timeout=5000

# ============================================================
# AMQP (si aplica)
# ============================================================

# ============================================================
# RESILIENCE — Retry & Circuit Breaker
# ============================================================

# ============================================================
# OPENAPI
# ============================================================

# ============================================================
# LOGGING ESTRUCTURADO (sección 18.5)
# ============================================================
```

### 21.2 Una dependencia externa, un bloque

Todo lo relacionado a una misma dependencia externa va junto: las 3 URLs por perfil, los timeouts y cualquier configuración propia. No separar URLs y timeouts en secciones distintas del archivo.

### 21.3 Perfiles y entornos de despliegue

- `%dev` — desarrollo local.
- `%qa` / `%prod` — despliegues en clúster, usando variables de entorno con fallback (`${VARIABLE:valor-default}`), nunca URLs hardcodeadas.
- El log a archivo (`quarkus.log.file.*`) **no es el patrón por defecto** en entornos containerizados — escribir a stdout y dejar que el recolector del clúster lo levante.

---

## 22. Catálogo de Códigos de Respuesta de Negocio

### 22.1 Principio fundamental

`codRespuesta` es un **código de negocio**, no un espejo del HTTP status. El código HTTP lo transporta el protocolo; `codRespuesta` expresa el resultado desde la perspectiva del dominio de la aplicación.

- **El éxito siempre es `"000"`**, independientemente del HTTP status (`200`, `201`, `202`).
- Cualquier valor distinto de `"000"` indica una condición anómala específica.
- Los códigos son cadenas de tres dígitos (`String`) para compatibilidad con sistemas legados y para permitir sub-rangos futuros.
- **Prohibido** devolver el HTTP status como valor de `codRespuesta` (ej. `"200"`, `"404"`, `"500"`).
- **Implementación:** cada microservicio debe representar esta tabla como un único `enum` llamado `ResponseCode` (en inglés, conforme a la sección 16), ubicado en el paquete `util`. Prohibido escribir estos códigos como strings literales fuera del enum.

### 22.2 Tabla maestra de códigos

#### Rango `000` — Éxito

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `000` | `SUCCESS` | `Operación exitosa` | Operación completada correctamente. |

#### Rango `1xx` — Errores de entrada / contrato (cliente)

HTTP asociado: `400`, `422`.

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `100` | `VALIDATION_ERROR` | `Los datos enviados no son válidos` | Violaciones de Bean Validation (`@NotNull`, `@Pattern`, `@Size`…). Siempre acompaña un array `violations`. |
| `101` | `MISSING_REQUIRED_FIELD` | `Falta un campo obligatorio` | Campo requerido ausente no cubierto por Bean Validation. |
| `102` | `INVALID_FORMAT` | `El formato del dato enviado no es correcto` | Tipo de dato incorrecto, JSON malformado, fecha inválida. |
| `103` | `UNSUPPORTED_VALUE` | `El valor indicado no está soportado` | Valor de enumeración desconocido (canal, estado, tipo de evento). |

#### Rango `2xx` — Errores de negocio / dominio

HTTP asociado: `404`, `409`, `422`.

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `200` | `RESOURCE_NOT_FOUND` | `El recurso solicitado no fue encontrado` | Entidad buscada no existe en el sistema. HTTP 404. |
| `201` | `NO_ACTIVE_RULES` | `No existen reglas activas para los parámetros indicados` | Sin reglas habilitadas para el par evento/origen. HTTP 404. |
| `202` | `MISSING_CONTACT_INFO` | `No se pudo obtener información de contacto para el destinatario` | Sin teléfono/correo en el request ni en el orquestador externo. |
| `203` | `BUSINESS_RULE_VIOLATION` | `La operación no puede completarse por una regla de negocio` | Caso de uso válido pero vetado por una regla de dominio. HTTP 422. |

#### Rango `3xx` — Errores de dependencias externas (downstream)

HTTP asociado: `502`, `503`, `504`.

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `300` | `DOWNSTREAM_ERROR` | `Error al comunicarse con un servicio externo` | Fallo genérico en una dependencia externa. |
| `301` | `PERSISTENCE_ERROR` | `Error al comunicarse con el servicio de persistencia` | Fallo al registrar o consultar en persistencia. HTTP 502. |
| `302` | `DISPATCH_ERROR` | `Error al comunicarse con el servicio de despacho` | Fallo al enviar al canal (SMS, Email, WhatsApp). HTTP 502. |
| `303` | `STORAGE_ERROR` | `Error al subir el adjunto al almacenamiento` | Fallo en Document Object Storage. HTTP 502. |
| `304` | `CUSTOMER_INFO_ERROR` | `Error al consultar los datos del cliente` | Fallo al consultar el orquestador de datos de persona. HTTP 502. |
| `305` | `CIRCUIT_BREAKER_OPEN` | `El servicio no está disponible temporalmente, intente más tarde` | Circuit breaker abierto en alguna dependencia. HTTP 503. |

#### Rango `9xx` — Errores internos / inesperados

HTTP asociado: `500`.

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `900` | `INTERNAL_ERROR` | `Ha ocurrido un error inesperado. Por favor contacte al soporte técnico.` | Error de runtime no capturado por ningún handler específico. |
| `901` | `CONFIGURATION_ERROR` | `Error en la configuración del sistema` | Parámetro de configuración inválido detectado en tiempo de ejecución. |

### 22.3 Estructura de la clase `ApiResponse<T>`

Todo microservicio debe incluir esta clase en el paquete `dto`. Es el **único** envoltorio de respuesta permitido.

```java
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "Respuesta unificada de API")
@RegisterForReflection
public class ApiResponse<T> {

    @Schema(description = "Mensaje amigable para el usuario o sistema consumidor")
    public String msgUsuario;

    @Schema(description = "Mensaje técnico detallado para soporte")
    public String msgTecnico;

    @Schema(description = "Código de negocio de la operación (ver catálogo, sección 22.2)")
    public String codRespuesta;

    @Schema(description = "Payload de negocio. Presente solo en respuestas exitosas (codRespuesta=000).")
    public T data;

    @Schema(description = "Lista de violaciones de validación. Presente solo cuando codRespuesta=100.")
    public List<Violation> violations;

    public ApiResponse() {}

    public ApiResponse(String msgUsuario, String msgTecnico, String codRespuesta, T data) {
        this.msgUsuario = msgUsuario;
        this.msgTecnico = msgTecnico;
        this.codRespuesta = codRespuesta;
        this.data = data;
    }

    /** Respuesta exitosa. codRespuesta siempre es "000". */
    public static <T> ApiResponse<T> success(T data) {
        return new ApiResponse<>("Operación exitosa", "Procesado correctamente", "000", data);
    }

    /** Respuesta de error de negocio o técnico sin payload. */
    public static <T> ApiResponse<T> error(String msgUsuario, String msgTecnico, String codRespuesta) {
        return new ApiResponse<>(msgUsuario, msgTecnico, codRespuesta, null);
    }

    /** Respuesta de validación. codRespuesta siempre es "100". */
    public static ApiResponse<Void> validationError(String msgTecnico, List<Violation> violations) {
        ApiResponse<Void> response = new ApiResponse<>(
                "Los datos enviados no son válidos", msgTecnico, "100", null);
        response.violations = violations;
        return response;
    }

    @RegisterForReflection
    public static class Violation {
        @Schema(description = "Campo que generó la violación")
        public String field;

        @Schema(description = "Descripción del error de validación")
        public String message;

        public Violation() {}

        public Violation(String field, String message) {
            this.field = field;
            this.message = message;
        }
    }
}
```

### 22.4 Estructura de respuestas por escenario

#### Éxito (HTTP 200 / 201 / 202)
```json
{
  "msgUsuario": "Operación exitosa",
  "msgTecnico": "Procesado correctamente",
  "codRespuesta": "000",
  "data": { ... }
}
```

#### Error de validación (HTTP 400)
```json
{
  "msgUsuario": "Los datos enviados no son válidos",
  "msgTecnico": "Constraint Violation",
  "codRespuesta": "100",
  "violations": [
    { "field": "request.ctl.correo", "message": "El correo debe tener un formato válido." },
    { "field": "request.ctl.celular", "message": "El celular debe tener 10 o 12 dígitos." }
  ]
}
```

#### Error de negocio (HTTP 404)
```json
{
  "msgUsuario": "El recurso solicitado no fue encontrado",
  "msgTecnico": "RecursoNoEncontradoException: Producto con ID 42 no existe",
  "codRespuesta": "200",
  "data": null
}
```

#### Error interno (HTTP 500)
```json
{
  "msgUsuario": "Ha ocurrido un error inesperado. Por favor contacte al soporte técnico.",
  "msgTecnico": "NullPointerException en ProductoService.obtenerPorId()",
  "codRespuesta": "900",
  "data": null
}
```

### 22.5 Reglas de consistencia

- `data` es **siempre `null`** cuando `codRespuesta` es distinto de `"000"`.
- `violations` es **siempre `null`** cuando `codRespuesta` es distinto de `"100"`. El campo `data` no aparece cuando hay `violations`.
- `msgTecnico` puede incluir el mensaje de la excepción para facilitar el soporte, **nunca** el stack trace completo.
- **No crear códigos fuera de los rangos definidos** sin documentarlos y comunicarlos al equipo. El catálogo es un contrato compartido.
- Todos los microservicios del mismo ecosistema deben usar **exactamente el mismo catálogo**. No se permiten variantes por microservicio.

### 22.6 Mapeo entre codRespuesta y HTTP status de referencia

| `codRespuesta` | HTTP status asociado | Justificación |
|----------------|---------------------|---------------|
| `000` | `200`, `201`, `202` | Éxito; el HTTP status comunica la semántica REST (creado, aceptado, etc.) |
| `100` | `400` | Validación de entrada fallida |
| `101`, `102`, `103` | `400` / `422` | Formato o valor inválido |
| `200`, `201` | `404` | Recurso o regla no encontrada |
| `202`, `203` | `422` | Lógica de negocio no puede completarse |
| `301`–`304` | `502` | Dependencia externa falló |
| `305` | `503` | Circuit breaker abierto |
| `900`, `901` | `500` | Error interno |

