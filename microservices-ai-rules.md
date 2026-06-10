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
@Path("/api/v1/productos")
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
@Path("/api/v1/productos")
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
- Los posibles códigos de respuesta deben documentarse con `@APIResponse`.

```java
@Operation(
    summary = "Obtener producto por ID",
    description = "Retorna el detalle de un producto dado su identificador único."
)
@APIResponse(responseCode = "200", description = "Producto encontrado")
@APIResponse(responseCode = "404", description = "Producto no encontrado")
public Uni<ProductoDTO> obtenerProducto(@PathParam("id") Long id) { ... }
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
    <artifactId>quarkus-junit5-mockito</artifactId>
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

**Todas** las clases de prueba deben anotarse con `@QuarkusTest`. Para mocks, usar `@InjectMock` (de `quarkus-junit5-mockito`) ya que opera dentro del contexto CDI de Quarkus.

### 10.3 Estrategia por tipo de clase

| Clase | Anotación | Razón |
|---|---|---|
| Servicios con dependencias CDI | `@QuarkusTest` + `@InjectMock` | Requiere contexto CDI para inyección |
| Mappers y utilidades | `@QuarkusTest` | Contribuye a JaCoCo; sin mocks necesarios |
| Tests de endpoint REST | `@QuarkusTest` + REST Assured | Verifica el contrato HTTP completo |

### 10.4 Tests de endpoint obligatorios

Todo endpoint nuevo debe tener al menos tres tests de integración:

- **Flujo feliz:** verifica `200` con el body esperado.
- **Validación fallida:** verifica `400` con el `ValidationExceptionMapper` activo (campo obligatorio ausente).
- **Recurso no encontrado:** verifica `404` con el body del `ExceptionMapper` de dominio.

```java
@QuarkusTest
class ProductoResourceIT {

    @Test
    @DisplayName("Debe responder 200 al consultar un producto existente")
    void shouldReturn200WhenProductExists() {
        // Arrange / Act / Assert
        given()
            .when().get("/api/v1/productos/1")
            .then()
            .statusCode(200)
            .body("nombre", equalTo("Laptop Pro"));
    }

    @Test
    @DisplayName("Debe retornar 400 con detalle de violaciones cuando falta el campo nombre")
    void shouldReturn400WhenNombreIsMissing() {
        given()
            .contentType(ContentType.JSON)
            .body("{}")
            .when().post("/api/v1/productos")
            .then()
            .statusCode(400)
            .body("violations.field", hasItem("nombre"));
    }

    @Test
    @DisplayName("Debe retornar 404 cuando el producto no existe")
    void shouldReturn404WhenProductDoesNotExist() {
        given()
            .when().get("/api/v1/productos/9999")
            .then()
            .statusCode(404)
            .body("status", equalTo(404));
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

### 12.2 ExceptionMappers

Cada excepción de dominio debe tener su `ExceptionMapper` registrado con `@Provider`. El mapper es el **único punto** que conoce JAX-RS y traduce a HTTP.

```java
@Provider
public class RecursoNoEncontradoExceptionMapper
        implements ExceptionMapper<RecursoNoEncontradoException> {

    @Override
    public Response toResponse(RecursoNoEncontradoException e) {
        return Response.status(Response.Status.NOT_FOUND)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of(
                        "status", 404,
                        "error", "Not Found",
                        "message", e.getMessage()))
                .build();
    }
}
```

### 12.3 ValidationExceptionMapper obligatorio

Todo proyecto debe registrar un `ValidationExceptionMapper` para `ConstraintViolationException`. Sin él, las violaciones de `@Valid` devuelven `400` con cuerpo vacío o texto plano.

```java
@Provider
public class ValidationExceptionMapper implements ExceptionMapper<ConstraintViolationException> {

    @Override
    public Response toResponse(ConstraintViolationException e) {
        List<Map<String, String>> violations = e.getConstraintViolations().stream()
                .map(v -> {
                    String path = v.getPropertyPath().toString();
                    String field = path.contains(".")
                            ? path.substring(path.lastIndexOf('.') + 1) : path;
                    return Map.of("field", field, "message", v.getMessage());
                }).toList();

        return Response.status(Response.Status.BAD_REQUEST)
                .type(MediaType.APPLICATION_JSON)
                .entity(Map.of("status", 400, "error", "Bad Request", "violations", violations))
                .build();
    }
}
```

### 12.4 Estructura uniforme de respuestas de error

```json
{
  "status": 404,
  "error": "Not Found",
  "message": "El producto con ID 42 no existe."
}
```

Para errores de validación:

```json
{
  "status": 400,
  "error": "Bad Request",
  "violations": [
    { "field": "nombre", "message": "Field 'nombre' is required." }
  ]
}
```

No propagar excepciones técnicas (`SQLException`, `NullPointerException`) hacia el cliente.

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

## 14. Nomenclatura y Convenciones de Código

| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | `PascalCase` | `ProductoService` |
| Métodos y variables | `camelCase` | `obtenerProducto` |
| Constantes | `UPPER_SNAKE_CASE` | `MAX_REINTENTOS` |
| Paquetes | `lowercase` | `ec.fin.baustro.api` |
| Endpoints REST | `kebab-case` en plural | `/api/v1/productos`, `/api/v1/ordenes-compra` |
| Variables de entorno | `UPPER_SNAKE_CASE` | `DB_PASSWORD`, `API_KEY` |
| Excepciones de dominio | `PascalCase` + sufijo `Exception` | `RecursoNoEncontradoException` |
| ExceptionMappers | mismo nombre + sufijo `Mapper` | `RecursoNoEncontradoExceptionMapper` |
| Clases utilitarias | `PascalCase` + sufijo `Utils` | `StringUtils`, `DateUtils` |
| Enums de dominio | `PascalCase` singular | `NotificationChannel`, `EstadoNotificacion` |
| Tests de servicio | sufijo `Test` | `ProductoServiceTest` |
| Tests de integración REST | sufijo `IT` | `ProductoResourceIT` |

---

## 15. Seguridad

- Validar **todas** las entradas del cliente con Bean Validation (`@NotNull`, `@Size`, `@Pattern`, etc.).
- Nunca registrar en logs datos sensibles: contraseñas, tokens, PII.
- Implementar autenticación con JWT y autorización basada en roles (`@RolesAllowed`).
- Configurar CORS explícitamente; evitar `*` en producción.
- Usar HTTPS obligatoriamente en todos los entornos fuera de desarrollo local.

---

## 16. Logging

- Usar el mecanismo idiomático de Quarkus según la versión del proyecto:
  - **Quarkus 3.x (recomendado):** anotación `@io.quarkus.logging.Log` — el compilador genera el logger estático automáticamente.
  - **Alternativa compatible:** `org.jboss.logging.Logger` instanciado manualmente.
- **Prohibido** usar `System.out.println`, `e.printStackTrace()`, o loggers de otras librerías (Log4j directo, `java.util.logging`) salvo que el proyecto lo establezca explícitamente.
- Los logs deben incluir contexto relevante (ID de correlación, ID del recurso afectado).
- Niveles recomendados:
  - `DEBUG`: flujo interno de ejecución.
  - `INFO`: eventos relevantes de negocio.
  - `WARN`: situaciones anómalas que no interrumpen el flujo.
  - `ERROR`: fallos que requieren atención operacional.

**Quarkus 3.x — forma preferida:**
```java
import io.quarkus.logging.Log;

@ApplicationScoped
public class ProductoService {

    public Uni<ProductoDTO> obtenerPorId(Long id) {
        Log.infof("Buscando producto con ID: %d", id);
        return productoRepository.findById(id)
            .onItem().ifNull().failWith(() -> {
                Log.warnf("Producto no encontrado. ID: %d", id);
                return new RecursoNoEncontradoException("Producto con ID " + id + " no existe.");
            })
            .map(productoMapper::toDTO);
    }
}
```

**Alternativa con JBoss Logger:**
```java
private static final Logger LOG = Logger.getLogger(ProductoService.class);

LOG.infof("Producto creado exitosamente. ID: %d", producto.getId());
LOG.errorf(e, "Error al obtener el producto con ID: %d", id);
```

---

## 17. Versionado de API

- Versionar los endpoints desde la primera publicación: `/api/v1/...`
- Nunca eliminar ni romper contratos de versiones activas; deprecar antes de eliminar.
- Indicar la deprecación con `@Deprecated` en el código y en la anotación OpenAPI correspondiente.

---

## 18. Comunicación entre Microservicios

- Usar clientes REST tipados (`@RegisterRestClient`) para comunicación síncrona.
- Para comunicación asíncrona, preferir mensajería (Kafka, RabbitMQ) sobre llamadas directas.
- Implementar `@CircuitBreaker`, `@Retry` y `@Timeout` en todos los clientes externos para resiliencia.

### 18.1 Externalizar parámetros de resiliencia en properties

**Prohibido** hardcodear los valores de `@Retry`, `@CircuitBreaker` y `@Timeout` directamente en las anotaciones. Deben externalizarse en `application.properties` para poder ajustarse sin recompilar.

Las anotaciones se mantienen en el código **únicamente como documentación de intención** y con valores de fallback para desarrollo local:

```java
// La anotación documenta la intención; los valores reales vienen de properties
@GET
@CircuitBreaker(requestVolumeThreshold = 4)
@Retry(maxRetries = 3, delay = 1000)
@Timeout(value = 5000)
Uni<List<ReglaConfigDto>> getRules(@QueryParam("cevento") String cEvento,
                                   @QueryParam("corigen") String cOrigen);
```

```properties
# Formato: fully-qualified-class/method/annotation/parameter
ec.fin.baustro.client.PersistenceClient/getRules/Retry/maxRetries=${PERSISTENCE_RETRY_MAX:3}
ec.fin.baustro.client.PersistenceClient/getRules/Retry/delay=${PERSISTENCE_RETRY_DELAY_MS:1000}
ec.fin.baustro.client.PersistenceClient/getRules/Timeout/value=${PERSISTENCE_TIMEOUT_MS:5000}

# Aplicar a todos los métodos de un cliente (alternativa por clase)
ec.fin.baustro.client.DispatchClient/Retry/maxRetries=${DISPATCH_RETRY_MAX:3}
ec.fin.baustro.client.DispatchClient/Timeout/value=${DISPATCH_TIMEOUT_MS:5000}
```

Los valores de las variables de entorno deben seguir la convención de secretos de la sección 11.

### 18.2 Propagación de ID de correlación

Propagar un ID de correlación entre microservicios mediante el header `X-Request-ID` en todas las llamadas inter-servicio. En ausencia de OpenTelemetry, incluirlo manualmente en los clientes REST registrados. Los logs deben incluir este ID como contexto en cada entrada relevante.
