# Estándares y Mejores Prácticas para Microservicios con Agentes de IA
### Stack: Quarkus · Mutiny · MicroProfile · Jakarta EE

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

- El endpoint de salud técnica debe residir en `/health` (`HealthController`), **desacoplado** de las rutas de negocio.
- Las rutas de negocio no deben mezclar lógica de monitoreo ni exponer métricas internas.
- Se recomienda implementar verificaciones de liveness y readiness diferenciadas:
  - `/health/live` — el proceso está vivo.
  - `/health/ready` — el servicio está listo para recibir tráfico.

---

## 3. Documentación de API (OpenAPI / Swagger)

### 3.1 Anotaciones en DTOs

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

### 3.2 Documentación de Endpoints

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

## 4. Documentación de Código (Javadoc)

- **Obligatorio** en español para todas las clases y métodos, tanto públicos como privados.
- Las descripciones deben ser cortas y concisas; evitar redundancias con el nombre del método.
- No documentar campos de DTO con Javadoc (ver sección 3.1).

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

## 5. Inyección de Dependencias

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

## 6. Pruebas

### 6.1 Dependencia obligatoria: quarkus-jacoco

Todo proyecto debe incluir `quarkus-jacoco` para la generación del reporte de cobertura:

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jacoco</artifactId>
    <scope>test</scope>
</dependency>
```

> **Importante:** `quarkus-jacoco` se engancha al contexto de Quarkus para instrumentar el código. El reporte de cobertura **solo se genera a partir de clases ejecutadas bajo `@QuarkusTest`**. Las pruebas que usen `@ExtendWith(MockitoExtension.class)` sin `@QuarkusTest` no contribuyen al reporte y quedan fuera de la métrica de cobertura.

### 6.2 Anotación obligatoria: @QuarkusTest

- **Todas** las clases de prueba deben anotarse con `@QuarkusTest` para garantizar que su ejecución quede registrada en el reporte de JaCoCo.
- Para pruebas de servicios que requieran mocks, usar `@InjectMock` (de `quarkus-junit5-mockito`) en lugar de `@Mock` de Mockito puro, ya que este opera dentro del contexto CDI de Quarkus.

```xml
<!-- Dependencia necesaria para @InjectMock dentro de @QuarkusTest -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit-mockito</artifactId>
    <scope>test</scope>
</dependency>
```

### 6.3 Convenciones

- Los nombres de los métodos de prueba deben seguir el patrón `should[ComportamientoEsperado]`, uniforme en todo el codebase.
- Cada prueba debe incluir `@DisplayName` con una descripción breve y clara.
- Cada prueba debe seguir la estructura **Arrange / Act / Assert** (AAA), con comentarios explícitos cuando la prueba tenga complejidad.
- El coverage mínimo esperado es **80%** en lógica de negocio (servicios y casos de uso).

**Prueba de servicio con mock dentro del contexto Quarkus:**
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

**Prueba de endpoint REST:**
```java
@QuarkusTest
class ProductoResourceIT {

    @Test
    @DisplayName("Debe responder 200 al consultar un producto existente")
    void shouldReturn200WhenProductExists() {
        given()
            .when().get("/api/v1/productos/1")
            .then()
            .statusCode(200)
            .body("nombre", equalTo("Laptop Pro"));
    }
}
```

---

## 7. Gestión de Secretos y Configuración

- Las contraseñas y credenciales **nunca** deben estar en texto plano en los archivos de propiedades.
- Deben gestionarse como secretos mediante variables de entorno, con un valor por defecto **solo para entornos de prueba**.
- Formato obligatorio en `application.properties`:

```properties
# Correcto: secreto con valor por defecto para pruebas
db.password=${DB_PASSWORD:default_test_password}
api.key=${API_KEY:default_api_key_test}

# Incorrecto: valor en texto plano
db.password=miPasswordSuperSegura123  # ❌
```

- En producción, la variable de entorno debe estar definida y el valor por defecto nunca debe usarse.

---

## 8. Manejo de Errores y Excepciones

- Definir excepciones de dominio propias (e.g., `RecursoNoEncontradoException`, `ReglaNegocioException`).
- Centralizar el mapeo de excepciones a respuestas HTTP en un `ExceptionMapper` global.
- No propagar excepciones técnicas (e.g., `SQLException`, `NullPointerException`) hacia el cliente.
- Las respuestas de error deben seguir una estructura uniforme:

```json
{
  "codigo": "RECURSO_NO_ENCONTRADO",
  "mensaje": "El producto con ID 42 no existe.",
  "timestamp": "2024-11-01T10:30:00Z"
}
```

---

## 9. Estructura de Paquetes

Seguir una arquitectura por capas o hexagonal, manteniendo separación clara de responsabilidades:

```
com.empresa.servicio
├── api                  # Controladores REST y DTOs de entrada/salida
│   ├── controller
│   └── dto
├── application          # Casos de uso / servicios de aplicación
├── domain               # Entidades, puertos, excepciones de dominio
│   ├── model
│   ├── port
│   └── exception
└── infrastructure       # Adaptadores: repositorios, clientes HTTP, mensajería
    ├── persistence
    └── client
```

---

## 10. Nomenclatura y Convenciones de Código

| Elemento | Convención | Ejemplo |
|---|---|---|
| Clases | `PascalCase` | `ProductoService` |
| Métodos y variables | `camelCase` | `obtenerProducto` |
| Constantes | `UPPER_SNAKE_CASE` | `MAX_REINTENTOS` |
| Paquetes | `lowercase` | `com.empresa.api` |
| Endpoints REST | `kebab-case` en plural | `/api/productos`, `/api/ordenes-compra` |
| Variables de entorno | `UPPER_SNAKE_CASE` | `DB_PASSWORD`, `API_KEY` |

---

## 11. Seguridad

- Validar **todas** las entradas del cliente con Bean Validation (`@NotNull`, `@Size`, `@Pattern`, etc.).
- Nunca registrar en logs datos sensibles: contraseñas, tokens, PII.
- Implementar autenticación con JWT y autorización basada en roles (`@RolesAllowed`).
- Configurar CORS explícitamente; evitar `*` en producción.
- Usar HTTPS obligatoriamente en todos los entornos fuera de desarrollo local.

---

## 12. Logging

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
                return new RecursoNoEncontradoException("Producto", id);
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

## 13. Versionado de API

- Versionar los endpoints desde la primera publicación: `/api/v1/...`
- Nunca eliminar ni romper contratos de versiones activas; deprecar antes de eliminar.
- Indicar la deprecación con `@Deprecated` en el código y en la anotación OpenAPI correspondiente.

---

## 14. Comunicación entre Microservicios

- Usar clientes REST tipados (`@RegisterRestClient`) para comunicación síncrona.
- Para comunicación asíncrona, preferir mensajería (Kafka, RabbitMQ) sobre llamadas directas.
- Implementar **circuit breaker** (`@CircuitBreaker`) y **retry** (`@Retry`) en clientes externos para resiliencia.
- Propagar el ID de correlación (`X-Correlation-ID`) en todas las llamadas inter-servicio.
