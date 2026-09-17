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

### 10.1 Umbral de cobertura — requisito no negociable

| Escenario | Umbral | Métrica |
|---|---|---|
| Desarrollo nuevo (microservicio o módulo nuevo) | **90%** líneas **y 80%** ramas | Sobre todo el módulo |
| Trabajo sobre legacy con cobertura < 90% | **90%** líneas **y 80%** ramas | Sobre el **código nuevo/modificado** únicamente |

Dos precisiones sobre por qué no basta con el porcentaje de líneas:

- **Cobertura de ramas obligatoria.** Un servicio reactivo con `.onFailure()`, `.onItem().ifNull()` o un
  `switch` sin probar puede alcanzar 90% de líneas con **cero** caminos de error ejercitados. El 90% de
  líneas sin ramas es una métrica que se cumple sin probar nada de lo que realmente falla en producción.
- **El umbral debe romper el build.** Un porcentaje escrito en un documento no es un control. Se materializa
  con `jacoco:check`, y el pipeline debe fallar si no se cumple.

#### Cobertura sobre código nuevo en legacy

JaCoCo por sí solo **no** sabe qué líneas son nuevas: mide el módulo completo. Para exigir 90% solo sobre lo
agregado hace falta una de estas tres vías, en orden de preferencia:

1. **SonarQube** — métrica nativa *Coverage on New Code*, con el quality gate sobre el *New Code Period*.
   Es la opción correcta si ya existe Sonar en la organización.
2. **`diff-cover`** — herramienta que cruza el reporte XML de JaCoCo con el diff de git. No requiere Sonar:
   ```bash
   diff-cover target/site/jacoco/jacoco.xml --compare-branch=origin/develop --fail-under=90
   ```
3. **Regla de revisión de PR** — si no hay ninguna de las anteriores, el revisor verifica manualmente que las
   clases y métodos tocados tengan test. Es la más débil y la menos recomendable: no es auditable.

**No** bajar el umbral global del módulo para "que pase el build" en un repositorio legacy. Eso convierte el
gate en decorativo. Se excluyen clases del cálculo (ver más abajo) o se usa cobertura sobre diff, nunca se
relaja el número.

### 10.2 Dependencias y configuración de cobertura

```xml
<!-- Contexto Quarkus para @QuarkusTest -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit5</artifactId>
    <scope>test</scope>
</dependency>

<!-- Mocks dentro del contexto CDI de Quarkus -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-junit-mockito</artifactId>
    <scope>test</scope>
</dependency>

<!-- Cobertura: instrumentación offline de las clases de la aplicación -->
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-jacoco</artifactId>
    <scope>test</scope>
</dependency>

<!-- Aserciones fluidas y pruebas del flujo reactivo -->
<dependency>
    <groupId>org.assertj</groupId>
    <artifactId>assertj-core</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.smallrye.reactive</groupId>
    <artifactId>mutiny-test</artifactId>
    <scope>test</scope>
</dependency>

<!-- Tests de endpoint REST -->
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>

<!-- Simulación de dependencias HTTP externas (sección 10.9) -->
<dependency>
    <groupId>org.wiremock</groupId>
    <artifactId>wiremock-standalone</artifactId>
    <scope>test</scope>
</dependency>
```

`quarkus-jacoco` usa **instrumentación offline** (modifica el bytecode en tiempo de build), mientras que
`jacoco-maven-plugin` usa el **agente en runtime**. Combinarlos sin cuidado produce el síntoma conocido de
reportar 0%, o de contar solo los `@QuarkusTest` e ignorar los tests unitarios planos. La configuración que
funciona: dejar que `quarkus-jacoco` produzca el archivo de ejecución unificado y delegar `report` y `check`
al plugin Maven.

```xml
<properties>
    <!-- Delega el reporte al plugin Maven para poder aplicar el gate con jacoco:check -->
    <quarkus.jacoco.report>false</quarkus.jacoco.report>
    <quarkus.jacoco.data-file>${project.build.directory}/jacoco-quarkus.exec</quarkus.jacoco.data-file>
</properties>

<build>
    <plugins>
        <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>0.8.13</version>
            <executions>
                <!-- Agente para los tests JUnit planos (sin @QuarkusTest).
                     Escribe en el MISMO .exec que quarkus-jacoco para consolidar. -->
                <execution>
                    <id>prepare-agent</id>
                    <goals><goal>prepare-agent</goal></goals>
                    <configuration>
                        <destFile>${project.build.directory}/jacoco-quarkus.exec</destFile>
                        <append>true</append>
                    </configuration>
                </execution>
                <execution>
                    <id>report</id>
                    <phase>verify</phase>
                    <goals><goal>report</goal></goals>
                    <configuration>
                        <dataFile>${project.build.directory}/jacoco-quarkus.exec</dataFile>
                    </configuration>
                </execution>
                <!-- Gate: rompe el build si no se cumple el umbral de la sección 10.1 -->
                <execution>
                    <id>check</id>
                    <phase>verify</phase>
                    <goals><goal>check</goal></goals>
                    <configuration>
                        <dataFile>${project.build.directory}/jacoco-quarkus.exec</dataFile>
                        <haltOnFailure>true</haltOnFailure>
                        <rules>
                            <rule>
                                <element>BUNDLE</element>
                                <limits>
                                    <limit>
                                        <counter>LINE</counter>
                                        <value>COVEREDRATIO</value>
                                        <minimum>0.90</minimum>
                                    </limit>
                                    <limit>
                                        <counter>BRANCH</counter>
                                        <value>COVEREDRATIO</value>
                                        <minimum>0.80</minimum>
                                    </limit>
                                </limits>
                            </rule>
                        </rules>
                        <excludes>
                            <!-- Código sin lógica: DTOs, records, enums simples y clases generadas.
                                 Excluir solo esto; nunca excluir servicios para alcanzar el umbral. -->
                            <exclude>**/dto/**</exclude>
                            <exclude>**/*Dto.class</exclude>
                            <exclude>**/enums/**</exclude>
                        </excludes>
                    </configuration>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

> **Verificar, no asumir.** El comportamiento de la interacción `quarkus-jacoco` + `jacoco-maven-plugin` ha
> cambiado entre versiones de Quarkus. Tras configurarlo, correr `./mvnw verify` y **abrir**
> `target/site/jacoco/index.html` para confirmar que aparecen tanto las clases cubiertas por tests unitarios
> planos como las cubiertas por `@QuarkusTest`. Si una de las dos familias sale en 0%, la consolidación no
> está funcionando y el gate es falso.

### 10.3 Estrategia por tipo de clase

`@QuarkusTest` **no** es obligatorio en todas las clases de prueba. Arranca el contenedor CDI completo
(segundos por clase) y no aporta nada a una clase sin dependencias. La regla es usar el nivel más liviano
que permita probar la clase:

| Clase a probar | Tipo de test | Razón |
|---|---|---|
| Utilidades, mappers, enums, validadores puros | JUnit plano | Sin dependencias; arranca en milisegundos |
| Servicios con dependencias | JUnit + `@Mock` de Mockito, inyección por constructor | La regla de la sección 9 (constructor obligatorio) hace innecesario el contexto CDI |
| Servicio que depende de infraestructura Quarkus real (`@ConfigMapping`, cliente REST inyectado, emisor AMQP) | `@QuarkusTest` + `@InjectMock` | Requiere el contenedor para resolver la infraestructura |
| Endpoints REST | `@QuarkusTest` + REST Assured | Verifica el contrato HTTP completo, serialización y mappers de excepción |
| Verificación del artefacto empaquetado / nativo | `@QuarkusIntegrationTest` | Corre contra el jar o la imagen, no contra el contexto de test |

La inyección por constructor obligatoria (sección 9) es precisamente lo que permite instanciar cualquier
servicio en un test plano con `new`. Si una clase *solo* puede probarse con `@QuarkusTest`, suele ser señal de
que tiene una dependencia oculta que debería estar en el constructor.

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

**Prohibido** instanciar servicios con dependencias `null` en tests. Toda dependencia debe mockearse
explícitamente: con `@Mock` de Mockito en tests planos, o con `@InjectMock` bajo `@QuarkusTest`.

```java
// Incorrecto
new MiServicio(null, "bucket", "prefix");  // ❌ NPE silencioso en extensiones futuras

// Correcto — test plano
@Mock MiClienteRest clienteRest;

// Correcto — bajo @QuarkusTest
@InjectMock MiClienteRest clienteRest;
```

### 10.6 Convenciones de pruebas

- Los nombres de los métodos deben seguir el patrón `should[ComportamientoEsperado]`.
- Cada prueba debe incluir `@DisplayName` con descripción breve y clara.
- Seguir la estructura **Arrange / Act / Assert** (AAA), con comentarios explícitos en pruebas complejas.
- Umbral de cobertura: ver sección 10.1 (**90%** líneas, **80%** ramas, aplicado con `jacoco:check`).
- Cada rama de error del flujo reactivo (`.onFailure()`, `.ifNull()`) necesita su propio test: es lo que
  exige el contador de ramas y es donde se concentran los defectos en producción.

```java
// Test unitario puro: sin @QuarkusTest, dependencias por constructor. Arranca en milisegundos.
@ExtendWith(MockitoExtension.class)
class ProductoServiceTest {

    @Mock
    ProductoRepository productoRepository;

    ProductoService productoService;

    @BeforeEach
    void setUp() {
        productoService = new ProductoService(productoRepository, new ProductoMapper());
    }

    @Test
    @DisplayName("Debe retornar el producto cuando existe el ID")
    void shouldReturnProductWhenIdExists() {
        // Arrange
        Long id = 1L;
        Producto producto = new Producto(id, "Laptop Pro");
        when(productoRepository.findById(id)).thenReturn(Uni.createFrom().item(producto));

        // Act — timeout acotado: nunca await().indefinitely() (ver 10.7)
        ProductoResponseDto resultado = productoService.obtenerPorId(id)
                .await().atMost(Duration.ofSeconds(5));

        // Assert — accessor de record, no getter (sección 6.3)
        assertThat(resultado.nombre()).isEqualTo("Laptop Pro");
    }
}
```

### 10.7 Nunca `await().indefinitely()` en pruebas

`await().indefinitely()` cuelga la suite para siempre si el `Uni` no completa —un mock sin `when(...)`
configurado devuelve `null`, y una cadena que nunca emite deja el build corriendo hasta el timeout del
runner de CI, sin dar ninguna pista de qué test falló.

```java
// Prohibido
Resultado r = servicio.ejecutar().await().indefinitely();  // ❌

// Correcto — falla rápido y con mensaje claro
Resultado r = servicio.ejecutar().await().atMost(Duration.ofSeconds(5));

// Preferible para aserciones sobre el flujo reactivo (éxito, fallo, ítems emitidos)
UniAssertSubscriber<Resultado> subscriber = servicio.ejecutar()
        .subscribe().withSubscriber(UniAssertSubscriber.create());

subscriber.awaitItem(Duration.ofSeconds(5)).assertItem(esperado);

// Verificar la rama de error explícitamente: es donde se esconden los bugs
servicio.ejecutar()
        .subscribe().withSubscriber(UniAssertSubscriber.create())
        .awaitFailure(Duration.ofSeconds(5))
        .assertFailedWith(ResourceNotFoundException.class, "Producto con ID 42 no existe");
```

`UniAssertSubscriber` viene en `mutiny-test`. Es la forma correcta de probar `.onFailure()`,
`.onItem().ifNull()` y los operadores de recuperación, que con `await()` quedan sin cubrir y son
justamente los caminos que el gate de cobertura de ramas (sección 10.1) exige ejercitar.

### 10.8 Aislamiento de configuración con `@TestProfile`

**Prohibido** que un test dependa de un servicio externo real. El perfil `test` de Quarkus debe apuntar a
stubs locales. Cuando un test necesita configuración distinta de la del perfil `test` por defecto, usar
`@TestProfile` en lugar de mutar `application.properties`:

```java
public class CircuitBreakerTestProfile implements QuarkusTestProfile {
    @Override
    public Map<String, String> getConfigOverrides() {
        return Map.of(
            "quarkus.rest-client.x-service.read-timeout", "300",
            "ec.fin.baustro.client.XClient/getData/Retry/maxRetries", "1"
        );
    }
}

@QuarkusTest
@TestProfile(CircuitBreakerTestProfile.class)
class XClientResilienceIT { ... }
```

> Cada `@TestProfile` distinto fuerza un reinicio del contexto de Quarkus. Agrupar los tests que comparten
> perfil en la misma clase para no multiplicar el tiempo de la suite.

### 10.9 Dependencias externas: WireMock obligatorio

Los clientes REST externos deben probarse contra un stub HTTP real, no contra un mock del cliente. Un mock de
Mockito sobre la interfaz `@RegisterRestClient` **no ejercita** la serialización, los timeouts, los códigos de
estado ni las anotaciones de Fault Tolerance — es decir, no prueba nada de lo que realmente falla.

Esto es lo que exige la sección 20.3 al verificar qué excepción concreta se lanza en un timeout: solo un
socket real lo revela.

```java
// Verificación del contrato de resiliencia: retraso mayor al read-timeout configurado
wireMock.stubFor(get(urlEqualTo("/rules?cevento=1"))
        .willReturn(aResponse().withFixedDelay(6000).withStatus(200)));

// Confirma que el timeout produce ProcessingException y no otra cosa
assertThatThrownBy(() -> client.getRules("1", "2").await().atMost(Duration.ofSeconds(30)))
        .isInstanceOf(ProcessingException.class);

// Y que un 4xx NO se reintenta (regla de la sección 20.3)
wireMock.verify(1, getRequestedFor(urlEqualTo("/rules?cevento=bad")));
```

Tests obligatorios por cada cliente REST externo:

- Respuesta exitosa con deserialización del body real.
- 5xx del remoto: se reintenta el número de veces configurado.
- 4xx del remoto: **no** se reintenta y no abre el circuito.
- Timeout: se propaga como el tipo de excepción esperado.

---

## 11. Gestión de Secretos y Configuración

- Las contraseñas y credenciales **nunca** deben estar en texto plano en los archivos de propiedades.
- Deben gestionarse como secretos mediante variables de entorno inyectadas desde un `Secret` de OpenShift.

### 11.1 Un secreto nunca lleva valor por defecto global

**Prohibido** declarar un secreto con fallback sin prefijo de perfil. Un default global significa que si la
variable de entorno falta en producción —`Secret` mal montado, typo en el `DeploymentConfig`, rotación
incompleta— la aplicación **arranca en silencio** con una credencial conocida y publicada en el repositorio.
El fallo se descubre cuando alguien la usa, no cuando se despliega.

Un secreto sin valor debe **impedir el arranque**. Quarkus falla el startup si una propiedad requerida no
resuelve, y eso es exactamente el comportamiento deseado: mejor un pod en `CrashLoopBackOff` con un error
claro que un pod `Running` autenticándose con `default_test_password`.

```properties
# Correcto — sin default: si falta la variable, la app no arranca
db.password=${DB_PASSWORD}
api.key=${API_KEY}

# El valor de conveniencia para desarrollo local va con prefijo de perfil.
# %dev nunca se activa en el clúster, así que no puede filtrarse a qa/prod.
%dev.db.password=${DB_PASSWORD:local_dev_only}
%dev.api.key=${API_KEY:local_dev_only}

# Incorrecto — default global: arranca en prod con la credencial del repo
db.password=${DB_PASSWORD:default_test_password}  # ❌
api.key=${API_KEY:default_api_key_test}           # ❌

# Incorrecto — valor en texto plano
db.password=miPasswordSuperSegura123  # ❌
```

### 11.2 Distinción entre secreto y configuración

La regla anterior aplica **solo a secretos** (contraseñas, API keys, tokens, certificados). La configuración
no sensible —URLs, timeouts, tamaños de lote— **sí** debe llevar default, porque un valor razonable evita
un fallo de arranque por una variable opcional ausente:

```properties
# Correcto — configuración no sensible con default
quarkus.rest-client.x-service.read-timeout=${X_SERVICE_TIMEOUT_MS:5000}
%qa.quarkus.rest-client.x-service.url=${X_SERVICE_URL:https://qa.interno/x}
```

### 11.3 Verificación

- Antes de cerrar el PR, confirmar que ningún secreto tiene fallback fuera de `%dev`.
- El repositorio no debe contener valores reales ni siquiera en historial: si se filtró uno, rotarlo, no
  solo borrarlo del archivo.
- Los `Secret` de OpenShift se referencian por `secretKeyRef` en el manifiesto, nunca se escriben en el
  `application.properties` ni en el `Dockerfile`.

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
    INVALID_FORMAT("102"),
    UNSUPPORTED_VALUE("103"),
    RESOURCE_NOT_FOUND("200"),
    BUSINESS_RULE_VIOLATION("203"),
    DOWNSTREAM_ERROR("300"),
    PERSISTENCE_ERROR("301"),
    DISPATCH_ERROR("302"),
    UNAUTHENTICATED("600"),
    ACCESS_DENIED("601"),
    INTERNAL_ERROR("900");
    // ... catálogo completo y versionado en RESPONSE_CODES.md (sección 22.2)

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

// Mapper genérico — captura todo lo que no tiene mapper específico.
// Nota el tipo: ExceptionMapper<Throwable>, no <RuntimeException>. Con RuntimeException se escapan
// las excepciones checked y los Error (OutOfMemoryError, StackOverflowError), y el cliente recibe
// la página HTML de error por defecto de Quarkus en lugar del ApiResponse del contrato.
@Provider
public class GlobalExceptionMapper implements ExceptionMapper<Throwable> {

    private static final Logger LOG = Logger.getLogger(GlobalExceptionMapper.class);

    @Override
    public Response toResponse(Throwable exception) {
        return switch (exception) {
            case ResourceNotFoundException rnfe -> buildResponse(Response.Status.NOT_FOUND,
                    "El recurso solicitado no fue encontrado", rnfe.getMessage(),
                    ResponseCode.RESOURCE_NOT_FOUND);

            // WebApplicationException cubre los errores HTTP nativos de JAX-RS (404, 405, 406, 401...),
            // generados p.ej. por un escáner DAST o por una ruta inexistente. Se preserva el status
            // original y se deriva el ResponseCode del status: NO todos son "recurso no encontrado".
            case WebApplicationException wae -> {
                int status = wae.getResponse().getStatus();
                LOG.debugf("[HTTP_ERROR] status=%d msg=%s", status, wae.getMessage());
                yield buildResponse(Response.Status.fromStatusCode(status),
                        msgUsuarioPorStatus(status), wae.getMessage(), responseCodePorStatus(status));
            }

            // Único punto donde se loguea a ERROR con stacktrace. El correlationId viene del MDC.
            default -> {
                LOG.error("[UNHANDLED_ERROR] Excepción no controlada", exception);
                yield buildResponse(Response.Status.INTERNAL_SERVER_ERROR,
                        "Ha ocurrido un error inesperado. Por favor contacte al soporte técnico.",
                        detalleTecnico(exception), ResponseCode.INTERNAL_ERROR);
            }
        };
    }

    /**
     * Deriva el código de negocio del status HTTP real. Mapear todo WebApplicationException a
     * RESOURCE_NOT_FOUND haría que un 401 o un 405 respondan "recurso no encontrado", lo cual
     * es incorrecto y confunde al consumidor.
     */
    private ResponseCode responseCodePorStatus(int status) {
        return switch (status) {
            case 400 -> ResponseCode.INVALID_FORMAT;          // 102
            case 401 -> ResponseCode.UNAUTHENTICATED;         // 600, ver 22.2 rango 6xx
            case 403 -> ResponseCode.ACCESS_DENIED;           // 601
            case 404 -> ResponseCode.RESOURCE_NOT_FOUND;      // 200
            case 405, 406, 415 -> ResponseCode.UNSUPPORTED_VALUE;  // 103
            default -> status >= 500 ? ResponseCode.INTERNAL_ERROR : ResponseCode.VALIDATION_ERROR;
        };
    }

    private String msgUsuarioPorStatus(int status) {
        return switch (status) {
            case 401 -> "No autenticado";
            case 403 -> "No tiene permisos para realizar esta operación";
            case 404 -> "El recurso solicitado no fue encontrado";
            case 405 -> "Método HTTP no permitido para este recurso";
            case 406, 415 -> "Tipo de contenido no soportado";
            default -> "La petición no pudo ser procesada";
        };
    }

    /**
     * En prod no se expone el mensaje de la excepción: puede contener valores de entrada
     * (incluido un PAN) interpolados por Jackson o Hibernate Validator. Ver sección 18.10.
     */
    private String detalleTecnico(Throwable exception) {
        return LaunchMode.current() == LaunchMode.NORMAL && ProfileManager.getActiveProfile().equals("prod")
                ? "Consulte el log del servidor con el correlationId de la respuesta"
                : exception.getClass().getSimpleName();
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

> **Regla de logging en los mappers:** todo 5xx se loguea **exactamente una vez**, a nivel `ERROR`, con
> stacktrace, y ese único lugar es el mapper genérico. Los 4xx se loguean a `DEBUG` (o `WARN` si son de
> autorización, ver sección 18.9). **Prohibido** re-loguear la misma excepción en el servicio y en el mapper:
> duplica el ruido y hace imposible contar incidentes reales.

El mapper (o mappers) es el **único punto** que conoce JAX-RS y traduce a HTTP. Las capas de servicio y cliente nunca deben conocer `Response` ni códigos HTTP — pero sí pueden (y deben) referenciar `ResponseCode` cuando necesiten expresar un resultado de negocio, ya que es un código de dominio, no un detalle de transporte HTTP.

> **Nota de ubicación:** `ResponseCode` es consumido por capas de dominio, adaptadores de proveedores externos y la capa REST por igual. Para no crear una dependencia inversa (dominio → presentación), el enum debe vivir en un paquete neutral compartido (ej. `util` o `common`), nunca dentro del paquete `resource`/`rest` de la capa de presentación.

> **Sobre la precedencia con `ConstraintViolationException`:** al tener su propio mapper (`ValidationExceptionMapper implements ExceptionMapper<ConstraintViolationException>`), JAX-RS lo selecciona automáticamente por ser más específico que `ExceptionMapper<RuntimeException>` — no hace falta ningún `instanceof` ni orden manual para este caso.

### 12.3 Prioridad de los ExceptionMapper de la aplicación sobre el handler de Quarkus

Quarkus registra su propio mapper para las excepciones de validación
(`ResteasyReactiveViolationExceptionMapper`), que produce una respuesta con estructura distinta a la de
`ApiResponse`. Para que gane el mapper de la aplicación, la palanca es la **especificidad del tipo**, no
una propiedad de configuración.

> **`quarkus.hibernate-validator.fail-fast` NO controla esto.** Esa propiedad decide si la validación se
> detiene en la primera violación o recolecta todas; no tiene relación con la selección de mappers. Además
> su valor por defecto ya es `false`, así que declararla no produce ningún efecto. Si la ves en un
> `application.properties` con el comentario "desactiva el handler de Quarkus", es un error: bórrala.

Reglas:

1. Declarar el mapper sobre el tipo **más específico** que aplique. `ExceptionMapper<ConstraintViolationException>`
   es más específico que el built-in de Quarkus, que está registrado sobre `ValidationException`.
2. Si el mapper propio no se dispara, la causa suele ser que Quarkus envuelve la excepción en
   `ResteasyReactiveViolationException` (subclase de `ValidationException`). En ese caso, declarar el
   mapper sobre `ValidationException` y desempaquetar dentro.
3. `@Priority` sobre el mapper **no** es una solución fiable para sobrescribir mappers de extensión: JAX-RS
   resuelve primero por especificidad de tipo y solo usa la prioridad para desempatar entre mappers del
   mismo tipo.

**El comportamiento de wrapping ha cambiado entre versiones de Quarkus.** No asumirlo de memoria: verificarlo
con un test de integración contra la versión exacta del proyecto. Es el mismo criterio que la sección 20.3
aplica a `ProcessingException`.

```java
@QuarkusTest
class ValidationExceptionMapperIT {

    @Test
    @DisplayName("Debe responder con la estructura ApiResponse y no con la de Quarkus")
    void shouldUseApplicationMapperForValidationErrors() {
        given().contentType(ContentType.JSON).body("{}")
            .when().post("/v1/productos")
            .then()
            .statusCode(400)
            .body("codRespuesta", equalTo("100"))   // estructura propia
            .body("violations", notNullValue())
            .body("parameterViolations", nullValue()); // estructura de Quarkus ausente
    }
}
```

Sin este test, la respuesta de validación puede cambiar de forma silenciosa en el siguiente upgrade de
Quarkus y romper a todos los consumidores.

### 12.4 No propagar excepciones técnicas al cliente

`SQLException`, `NullPointerException`, stack traces y mensajes internos de la JVM **nunca** deben llegar al
cuerpo de la respuesta. El `GlobalExceptionMapper` debe capturarlos en el caso `default` y devolver siempre el
mensaje neutro con `codRespuesta: "900"`.

**El riesgo no es solo el stacktrace.** El *mensaje* de la excepción también filtra datos:

- Jackson incluye el valor rechazado en los errores de deserialización
  (`Cannot deserialize value "4111111111111111"...`).
- Hibernate Validator interpola `${validatedValue}` si el mensaje del constraint lo referencia.
- Los drivers de BD incluyen fragmentos de la sentencia y a veces los parámetros.

Por eso, en el perfil `prod`:

- `msgTecnico` **no** debe contener `exception.getMessage()`. Debe contener una referencia al log
  (`correlationId`), y el detalle queda solo del lado del servidor.
- `violations[].message` debe provenir de un catálogo de mensajes propio, nunca interpolar el valor recibido.
  **Prohibido** usar `${validatedValue}` en cualquier mensaje de constraint.

Ver la sección 18.10 para el tratamiento completo de datos sensibles y de tarjetas.

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

### 17.1 Controles obligatorios

- Validar **todas** las entradas del cliente con Bean Validation (`@NotNull`, `@Size`, `@Pattern`, etc.).
- Nunca registrar en logs datos sensibles: contraseñas, tokens, PII, **datos de tarjeta**.
  El tratamiento completo está en la **sección 18.10**, que es requisito del departamento de seguridad.
- Implementar autenticación con JWT y autorización basada en roles (`@RolesAllowed`).
- Configurar CORS explícitamente; evitar `*` en producción.
- Usar HTTPS obligatoriamente en todos los entornos fuera de desarrollo local.
- Registrar los eventos de auditoría que exige la **sección 18.9** (quién hizo qué, desde dónde y con qué
  resultado).

### 17.2 Validación del JWT

Declarar `@RolesAllowed` no es suficiente: hay que verificar que el token sea legítimo. Configurar
explícitamente y **nunca** aceptar valores por defecto permisivos:

```properties
mp.jwt.verify.publickey.location=${JWT_PUBLIC_KEY_LOCATION}
mp.jwt.verify.issuer=${JWT_ISSUER}
mp.jwt.verify.audiences=${JWT_AUDIENCE}
# Algoritmo fijo: evita el ataque de sustitución de algoritmo y rechaza alg=none
mp.jwt.verify.algorithm=RS256
smallrye.jwt.time-to-live=900
```

- **Prohibido** aceptar `alg: none` o permitir que el token declare su propio algoritmo.
- `issuer` y `audiences` son obligatorios: sin ellos, un token válido emitido para otro sistema es aceptado.
- **Prohibido** loguear el JWT completo, ni siquiera a `DEBUG`. Para trazabilidad se usa el claim `jti`
  (identificador del token) o `sub`, nunca el token.

### 17.3 Límites de request

Sin límites explícitos, un solo request puede agotar la memoria del pod. Configurar en todos los servicios:

```properties
quarkus.http.limits.max-body-size=1M
quarkus.http.limits.max-header-size=8K
quarkus.http.limits.max-initial-line-length=4096
quarkus.http.limits.max-form-attribute-size=2048
```

Ajustar `max-body-size` al tamaño real del contrato. Si el servicio recibe adjuntos, dimensionarlo al máximo
documentado, nunca dejarlo abierto.

### 17.4 Cabeceras de seguridad

```properties
quarkus.http.header."X-Content-Type-Options".value=nosniff
quarkus.http.header."X-Frame-Options".value=DENY
quarkus.http.header."Cache-Control".value=no-store
quarkus.http.header."Strict-Transport-Security".value=max-age=31536000; includeSubDomains
```

`Cache-Control: no-store` es especialmente relevante en respuestas que contienen datos de cliente: evita que
un proxy intermedio o el navegador conserven copia.

### 17.5 Datos sensibles en la URL

**Prohibido** transportar identificadores de tarjeta, documentos de identidad, tokens o cualquier dato
sensible como *path param* o *query param*. Las URLs se registran en el access log, en los logs del proxy, en
el historial del navegador y en la telemetría del balanceador — todos ellos fuera del control del servicio.

```
# Incorrecto
GET /v1/cards?pan=4111111111111111        # ❌ queda en el access log y en el proxy
GET /v1/clientes/1712345678/movimientos   # ❌ cédula en la ruta

# Correcto — el dato sensible va en el body de un POST
POST /v1/cards/queries
{ "pan": "4111111111111111" }
```

Esta regla es la que hace seguro el patrón de access log de la sección 18.5.

---

## 18. Logging y Trazabilidad Distribuida

### 18.1 Principio general y requisito de seguridad

El log tiene dos objetivos, y ambos son obligatorios:

1. **Trazabilidad técnica** — seguir un mismo request a través de varios microservicios con un único
   identificador (`correlationId`).
2. **Trazabilidad de auditoría** — poder responder *quién* hizo *qué*, *desde dónde*, *cuándo* y con *qué
   resultado*. Este es un requisito explícito del departamento de seguridad, no una mejora opcional.

> **Requisito del departamento de seguridad (normativo):**
> *Los logs deben permitir la trazabilidad de las acciones realizadas por los usuarios en el aplicativo. No
> deben almacenar información confidencial de tarjetas. Adicional a lo indicado, se debe cumplir con la
> estructura estándar de log:*
> ```
> [fecha/hora] [tipo de evento] [sesión – IP – usuario] Descripción del evento, resultado del evento
> ```

Ese formato se implementa en la **sección 18.5**, los campos de identidad en la **18.9**, y la prohibición de
datos de tarjeta en la **18.10**. Las tres son de cumplimiento obligatorio y auditable.

La implementación se apoya en cuatro piezas:

- Un **Correlation ID** resuelto en el borde y propagado a toda llamada saliente.
- El **MDC** poblado una sola vez, en el filtro de entrada, con el contexto completo de auditoría
  (`eventType`, `sessionId`, `clientIp`, `user`, `outcome`).
- Un **formato de log** que renderiza esos campos en posiciones fijas, de modo que el mensaje cumpla el
  estándar sin que cada desarrollador tenga que recordarlo.
- Un **sanitizador** que impide que datos de tarjeta o saltos de línea lleguen al log.

Que los campos vivan en el MDC y no incrustados en el mensaje es lo que permite cambiar entre texto plano y
JSON con una línea de configuración, sin tocar una sola clase.

**Sobre trazas distribuidas:** no se adopta OpenTelemetry, Jaeger ni Zipkin. Son útiles solo si existe un
backend que recoja las trazas, y actualmente no hay ninguno desplegado. Introducirlos sin colector añade
dependencias y overhead sin ningún beneficio. Ver la nota de la sección 18.3 sobre compatibilidad con W3C
Trace Context, que deja la puerta abierta sin costo.

### 18.2 API de logging

- Usar el mecanismo idiomático de Quarkus según la versión del proyecto:
  - **Quarkus 3.x (recomendado):** anotación `@io.quarkus.logging.Log`.
  - **Alternativa compatible:** `org.jboss.logging.Logger` instanciado manualmente.
- **Prohibido** usar `System.out.println`, `e.printStackTrace()`, o loggers de otras librerías.
- Elegir una sola API de logging por proyecto y mantenerla consistente en todas las clases.
- Al usar `Logger.warnf`/`errorf` con una excepción, el `Throwable` va como **primer** argumento: `LOG.errorf(e, "mensaje %s", valor)`, nunca `LOG.errorf("mensaje %s", valor, e)`.

```java
// Correcto — el Throwable primero; el correlationId lo aporta el MDC vía formato de log
LOG.warnf(e, "[WARN-SKIP] No se pudo cerrar la respuesta");

// Incorrecto — el stacktrace se descarta silenciosamente (queda como argumento de formato sobrante)
LOG.warnf("[WARN-SKIP] No se pudo cerrar la respuesta", e);  // ❌

// Incorrecto — interpolar el correlationId a mano; ya está en el MDC y en el formato (sección 18.5)
LOG.warnf(e, "[WARN-SKIP] No se pudo cerrar la respuesta (correlationId=%s)",
        CorrelationContext.getCorrelationId());  // ❌
```

- Niveles recomendados: `DEBUG` (flujo interno), `INFO` (eventos de negocio y auditoría), `WARN` (anomalías
  no críticas y denegaciones de acceso), `ERROR` (fallos que requieren atención).

- **Todo valor de origen externo que se interpole en un log debe sanearse** con `LogSanitizer`
  (sección 18.10.4). Aplica a nombres, descripciones, mensajes de error de terceros y cualquier campo del
  request. Sin esto, un `\n` en la entrada permite fabricar líneas de log falsas.

### 18.3 Contexto de log — propagación end-to-end

Todas las claves viven en el MDC y se siembran **una sola vez**, en el filtro de entrada.

| Elemento | Valor estándar |
|---|---|
| Header HTTP de correlación | `X-Correlation-Id` |
| Header HTTP de sesión | `X-Session-Id` |
| Claves MDC | `correlationId`, `service`, `eventType`, `sessionId`, `clientIp`, `user`, `outcome` |
| Clase utilitaria | `util/CorrelationContext.java` |
| Filtro JAX-RS (servidor) | `filter/CorrelationFilter.java` |
| Filtro de cliente REST (saliente) | `filter/CorrelationClientFilter.java` |
| Sanitizador | `util/LogSanitizer.java` (sección 18.10.4) |

**`CorrelationContext`** — única fuente de las claves MDC:
```java
/**
 * Contexto de log por request. Centraliza las claves del MDC y su ciclo de vida.
 * Se siembra exclusivamente en el borde (CorrelationFilter o consumidor AMQP).
 */
public final class CorrelationContext {

    public static final String HEADER_NAME = "X-Correlation-Id";
    public static final String SESSION_HEADER_NAME = "X-Session-Id";

    public static final String MDC_KEY = "correlationId";
    public static final String MDC_SERVICE_KEY = "service";
    public static final String MDC_EVENT_TYPE_KEY = "eventType";
    public static final String MDC_SESSION_KEY = "sessionId";
    public static final String MDC_CLIENT_IP_KEY = "clientIp";
    public static final String MDC_USER_KEY = "user";
    public static final String MDC_OUTCOME_KEY = "outcome";

    /** Valor de relleno: el formato de log debe tener todas las posiciones ocupadas. */
    public static final String NOT_AVAILABLE = "-";
    public static final String ANONYMOUS = "anonymous";

    private static final List<String> ALL_KEYS = List.of(
            MDC_KEY, MDC_SERVICE_KEY, MDC_EVENT_TYPE_KEY,
            MDC_SESSION_KEY, MDC_CLIENT_IP_KEY, MDC_USER_KEY, MDC_OUTCOME_KEY);

    private CorrelationContext() {}

    /**
     * Resuelve el correlationId entrante o genera uno nuevo, y lo deja en el MDC.
     *
     * @param incomingCorrelationId valor del header X-Correlation-Id, puede ser nulo
     * @return el identificador efectivo
     */
    public static String initCorrelation(String incomingCorrelationId) {
        String id = (incomingCorrelationId != null && !incomingCorrelationId.isBlank())
                ? LogSanitizer.sanitizeId(incomingCorrelationId)
                : UUID.randomUUID().toString();
        MDC.put(MDC_KEY, id);
        return id;
    }

    /** Registra el tipo de evento en curso (catálogo de secciones 18.7 y 18.9). */
    public static void setEventType(String eventType) {
        MDC.put(MDC_EVENT_TYPE_KEY, eventType);
    }

    /** Registra el resultado del evento: SUCCESS, FAILURE o DENIED. */
    public static void setOutcome(Outcome outcome) {
        MDC.put(MDC_OUTCOME_KEY, outcome.name());
    }

    public static String getCorrelationId() {
        Object val = MDC.get(MDC_KEY);
        return val != null ? val.toString() : null;
    }

    /**
     * Copia el contexto completo para restaurarlo tras un salto de hilo (ver 18.4.1).
     * Copiar clave por clave pierde la identidad del usuario y rompe la auditoría.
     */
    public static Map<String, String> capture() {
        Map<String, String> snapshot = new HashMap<>();
        for (String key : ALL_KEYS) {
            Object value = MDC.get(key);
            if (value != null) {
                snapshot.put(key, value.toString());
            }
        }
        return snapshot;
    }

    /** Restaura un contexto capturado en el hilo actual. */
    public static void restore(Map<String, String> snapshot) {
        if (snapshot != null) {
            snapshot.forEach(MDC::put);
        }
    }

    /** Limpia todas las claves. Obligatorio en finally: el MDC se hereda entre hilos del pool. */
    public static void clear() {
        ALL_KEYS.forEach(MDC::remove);
    }
}
```

**`Outcome`** — enum del resultado del evento, requerido por el formato estándar:
```java
/** Resultado de un evento de log, conforme al estándar de la sección 18.1. */
public enum Outcome {
    /** La acción se completó correctamente. */
    SUCCESS,
    /** La acción falló por un error técnico o de negocio. */
    FAILURE,
    /** La acción fue rechazada por falta de autenticación o autorización. */
    DENIED
}
```

**`CorrelationFilter`** — único lugar donde se siembra el MDC en el flujo HTTP:
```java
@Provider
public class CorrelationFilter implements ContainerRequestFilter, ContainerResponseFilter {

    private static final Logger LOG = Logger.getLogger(CorrelationFilter.class);
    private static final String REQUEST_START_TIME = "X-Request-Start-Time";

    private final String serviceName;
    private final SecurityIdentity identity;   // de quarkus-security; anónima si no hay autenticación

    @Context
    HttpServerRequest httpRequest;             // acceso a la IP real del cliente

    public CorrelationFilter(
            @ConfigProperty(name = "quarkus.application.name") String serviceName,
            SecurityIdentity identity) {
        this.serviceName = serviceName;
        this.identity = identity;
    }

    @Override
    public void filter(ContainerRequestContext req) {
        CorrelationContext.initCorrelation(req.getHeaderString(CorrelationContext.HEADER_NAME));
        MDC.put(CorrelationContext.MDC_SERVICE_KEY, serviceName);
        MDC.put(CorrelationContext.MDC_SESSION_KEY, resolveSessionId(req));
        MDC.put(CorrelationContext.MDC_CLIENT_IP_KEY, resolveClientIp());
        MDC.put(CorrelationContext.MDC_USER_KEY, resolveUser());
        CorrelationContext.setEventType("REQUEST_IN");
        CorrelationContext.setOutcome(Outcome.SUCCESS);

        req.setProperty(REQUEST_START_TIME, System.currentTimeMillis());

        // Solo método y path. NUNCA getRequestUri(): incluye el query string (ver 17.5 y 18.10).
        LOG.infof("Petición recibida method=%s path=%s",
                req.getMethod(), req.getUriInfo().getPath());
    }

    @Override
    public void filter(ContainerRequestContext req, ContainerResponseContext res) {
        String correlationId = CorrelationContext.getCorrelationId();
        if (correlationId != null) {
            res.getHeaders().add(CorrelationContext.HEADER_NAME, correlationId);
        }

        Long startTime = (Long) req.getProperty(REQUEST_START_TIME);
        long latencyMs = startTime != null ? System.currentTimeMillis() - startTime : -1;

        CorrelationContext.setEventType("REQUEST_OUT");
        CorrelationContext.setOutcome(outcomeFor(res.getStatus()));

        try {
            LOG.infof("Petición finalizada status=%d latencyMs=%d", res.getStatus(), latencyMs);
        } finally {
            CorrelationContext.clear();   // en finally: si el log falla, el MDC no contamina el próximo request
        }
    }

    /** Deriva el resultado del evento a partir del status HTTP. */
    private Outcome outcomeFor(int status) {
        if (status == 401 || status == 403) return Outcome.DENIED;
        return status >= 400 ? Outcome.FAILURE : Outcome.SUCCESS;
    }

    /**
     * Identificador de sesión. Se prefiere el claim jti del JWT sobre el header,
     * porque el header lo controla el cliente y es falsificable.
     */
    private String resolveSessionId(ContainerRequestContext req) {
        if (identity != null && identity.getPrincipal() instanceof JsonWebToken jwt) {
            String jti = jwt.getClaim(Claims.jti.name());
            if (jti != null && !jti.isBlank()) {
                return jti;
            }
        }
        String header = req.getHeaderString(CorrelationContext.SESSION_HEADER_NAME);
        return header != null && !header.isBlank()
                ? LogSanitizer.sanitizeId(header)
                : CorrelationContext.NOT_AVAILABLE;
    }

    /**
     * IP real del cliente. Requiere proxy-address-forwarding=true y trusted-proxies configurados
     * (ver 18.9.3): leer X-Forwarded-For a mano permite que el cliente falsifique su propia IP.
     */
    private String resolveClientIp() {
        if (httpRequest == null || httpRequest.remoteAddress() == null) {
            return CorrelationContext.NOT_AVAILABLE;
        }
        return httpRequest.remoteAddress().hostAddress();
    }

    /** Usuario autenticado, o "anonymous". Nunca el token completo. */
    private String resolveUser() {
        if (identity == null || identity.isAnonymous() || identity.getPrincipal() == null) {
            return CorrelationContext.ANONYMOUS;
        }
        return LogSanitizer.sanitizeId(identity.getPrincipal().getName());
    }
}
```

**`CorrelationClientFilter`** — propaga el ID a toda llamada REST saliente:
```java
@Provider
public class CorrelationClientFilter implements ClientRequestFilter {

    @Override
    public void filter(ClientRequestContext requestContext) {
        String correlationId = CorrelationContext.getCorrelationId();
        if (correlationId != null) {
            requestContext.getHeaders().putSingle(CorrelationContext.HEADER_NAME, correlationId);
        }
    }
}
```

> **Compatibilidad con W3C Trace Context (opcional, sin costo).** Si el request entrante trae un header
> `traceparent` (`00-<trace-id>-<span-id>-01`), extraer el `trace-id` y usarlo como `correlationId` en lugar
> de generar un UUID. Son pocas líneas en `initCorrelation`, no añade dependencias, y hace que los
> identificadores ya coincidan si en el futuro aparece un service mesh o un colector de trazas. No se adopta
> OpenTelemetry: solo se respeta el formato del identificador.

**Regla no negociable: el MDC se siembra solo en el borde, nunca en el código de negocio.**

```java
// Correcto — el código de negocio no toca el MDC ni interpola contexto
Log.infof("Notificación persistida cNotificacion=%d", notificacion.getId());

// Incorrecto — reintroduce dependencia manual y duplica lo que ya aporta el formato
Log.infof("Notificación persistida cNotificacion=%d correlationId=%s",
        notificacion.getId(), CorrelationContext.getCorrelationId());  // ❌
```

Las dos únicas excepciones, ambas acotadas:

- `CorrelationContext.setEventType(...)` / `setOutcome(...)` al registrar un evento de auditoría
  (sección 18.9).
- `capture()` / `restore()` para cruzar un salto de hilo (sección 18.4.1) — que **restaura** un contexto
  existente, no lo siembra.

### 18.4 Correlation ID a través de colas AMQP (asíncrono)

El Correlation ID viaja **dentro del body del mensaje** como un campo del DTO:

```java
public record WhatsappDeliveryMessage(
        @JsonProperty("cnotificacion") Long cNotificacion,
        @JsonProperty("correlationId") String correlationId
) {}
```

El consumidor es un **borde**, igual que el filtro HTTP: es el lugar donde se siembra el MDC. Además del
`correlationId`, debe propagar la identidad del usuario que originó la acción, o la traza de auditoría se
corta al cruzar la cola.

```java
public record WhatsappDeliveryMessage(
        @JsonProperty("cnotificacion") Long cNotificacion,
        @JsonProperty("correlationId") String correlationId,
        // Identidad del originador: sin esto no se sabe quién pidió el envío (requisito 18.9)
        @JsonProperty("originUser") String originUser,
        @JsonProperty("originSessionId") String originSessionId
) {}
```

```java
@Incoming("whatsapp-in")
public Uni<Void> consume(JsonObject jsonMessage) {
    WhatsappDeliveryMessage message = jsonMessage.mapTo(WhatsappDeliveryMessage.class);

    // Borde asíncrono: se siembra el contexto completo, igual que en CorrelationFilter
    CorrelationContext.initCorrelation(message.correlationId());
    MDC.put(CorrelationContext.MDC_SERVICE_KEY, serviceName);
    MDC.put(CorrelationContext.MDC_USER_KEY,
            message.originUser() != null ? LogSanitizer.sanitizeId(message.originUser())
                                         : CorrelationContext.ANONYMOUS);
    MDC.put(CorrelationContext.MDC_SESSION_KEY,
            message.originSessionId() != null ? LogSanitizer.sanitizeId(message.originSessionId())
                                             : CorrelationContext.NOT_AVAILABLE);
    // Origen AMQP: no hay IP de cliente, se marca explícitamente
    MDC.put(CorrelationContext.MDC_CLIENT_IP_KEY, "amqp");
    CorrelationContext.setEventType("AMQ_CONSUMED");
    CorrelationContext.setOutcome(Outcome.SUCCESS);

    LOG.infof("Mensaje consumido queue=whatsapp-in cNotificacion=%d", message.cNotificacion());

    return service.process(message.cNotificacion())
            .invoke(() -> {
                CorrelationContext.setEventType("AMQ_PROCESSED");
                CorrelationContext.setOutcome(Outcome.SUCCESS);
                LOG.infof("Mensaje procesado cNotificacion=%d", message.cNotificacion());
            })
            .onFailure().invoke(e -> {
                CorrelationContext.setEventType("AMQ_FAILED");
                CorrelationContext.setOutcome(Outcome.FAILURE);
                LOG.errorf(e, "Fallo al procesar el mensaje cNotificacion=%d", message.cNotificacion());
            })
            // eventually se ejecuta tanto en éxito como en fallo: garantiza la limpieza del MDC
            .eventually(() -> {
                CorrelationContext.clear();
                return Uni.createFrom().voidItem();
            });
}
```

El productor debe poblar esos campos desde su propio MDC al construir el mensaje, de modo que la identidad
viaje sin que el código de negocio la consulte a mano.

#### 18.4.1 MDC y saltos de hilo en código reactivo (Mutiny)

En una cadena `Uni<T>`, cada operador puede ejecutarse en un hilo distinto. Capturar el correlationId **antes del salto** y restaurarlo dentro del callback:

```java
// Correcto — se captura el contexto antes del salto de hilo y se restaura dentro del callback.
// Este es el ÚNICO caso en que el código de negocio toca el MDC: restaurar un contexto que ya existía,
// no sembrarlo. Y el correlationId sigue sin interpolarse en el mensaje: lo aporta el formato de log.
Map<String, String> logContext = CorrelationContext.capture();

emitter.send(message).whenComplete((result, failure) -> {
    CorrelationContext.restore(logContext);
    try {
        if (failure != null) {
            LOG.errorf(failure, "[AMQ_PUBLISH_FAILED] destino=%s", destino);
        } else {
            LOG.infof("[AMQ_PUBLISH] destino=%s", destino);
        }
    } finally {
        CorrelationContext.clear();   // en finally: si el log lanza, el MDC no queda contaminado
    }
});
```

`capture()`/`restore()` mueven **todas** las claves del contexto de una vez. Copiar clave por clave
(`MDC.put("correlationId", ...)`) pierde `user`, `sessionId` y `clientIp`, y los logs emitidos tras el salto
de hilo quedan sin la identidad que exige la sección 18.9.

> **`clear()` siempre en `finally`.** En un pool de hilos el MDC se hereda del hilo reutilizado: un MDC sin
> limpiar hace que el siguiente request loguee con el usuario del anterior. Eso no es solo ruido, es una
> traza de auditoría incorrecta que atribuye acciones al usuario equivocado.

### 18.5 Formato de log estándar y configuración por perfil

#### 18.5.1 El formato exigido

El departamento de seguridad exige esta estructura:

```
[fecha/hora] [tipo de evento] [sesión – IP – usuario] Descripción del evento, resultado del evento
```

Se implementa con un único `quarkus.log.console.format`, idéntico en los tres perfiles. Los campos provienen
del MDC, así que **ninguna clase necesita conocer el formato**:

```properties
# ============================================================
# LOGGING — formato estándar exigido por seguridad (sección 18.1)
# [fecha/hora] [tipo de evento] [sesión - IP - usuario] Descripción, resultado
# ============================================================
quarkus.log.console.format=%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} [%X{eventType}] [%X{sessionId} - %X{clientIp} - %X{user}] %s, outcome=%X{outcome} [cid=%X{correlationId}]%e%n

# Zona horaria fija: sin esto, cada pod loguea en la zona del contenedor y los
# eventos de distintos pods no se pueden ordenar entre sí.
quarkus.log.console.timezone=America/Guayaquil
```

Ejemplo de salida real:

```
2026-09-16T10:32:14.882-05:00 [DATA_UPDATE] [a3f9c1 - 10.42.8.19 - jperez] Producto actualizado id=42, outcome=SUCCESS [cid=8b1d...]
2026-09-16T10:32:15.104-05:00 [ACCESS_DENIED] [a3f9c1 - 10.42.8.19 - jperez] Acceso denegado al recurso /v1/admin/config, outcome=DENIED [cid=8b1d...]
```

Notas sobre el formato:

- **`yyyy-MM-dd'T'HH:mm:ss.SSSXXX`** — ISO-8601 con offset. El formato anterior (`HH:mm:ss.SSS`) no incluía
  fecha, lo que hace imposible auditar un evento de hace dos días.
- **Posiciones fijas.** Todos los campos se rellenan con `-` cuando no aplican
  (`CorrelationContext.NOT_AVAILABLE`), de modo que la línea siempre tiene la misma forma y se puede procesar
  con `awk` o una expresión regular estable.
- **El `eventType` es un campo, no un prefijo del mensaje.** Esto reemplaza el patrón `[REQUEST_IN] ...`
  incrustado en el texto: el prefijo del catálogo (secciones 18.7 y 18.9) va al MDC.
- **`%e` al final** para el stacktrace, sin `%t` ni `%c`: en un microservicio de un solo propósito el nombre
  de la clase y el hilo aportan poco frente al costo de longitud de línea. Añadir `[%c{2.}]` en `%dev` si
  ayuda al desarrollo local.

#### 18.5.2 Niveles por perfil

```properties
# --- DEV: verboso en el código propio ---
%dev.quarkus.log.level=INFO
%dev.quarkus.log.category."ec.fin.baustro".level=DEBUG

# --- QA ---
%qa.quarkus.log.level=INFO
%qa.quarkus.log.category."ec.fin.baustro".level=INFO

# --- PROD: ruido de frameworks reducido, código propio en INFO ---
%prod.quarkus.log.level=WARN
%prod.quarkus.log.category."ec.fin.baustro".level=INFO

# La categoría de auditoría NUNCA baja de INFO en ningún perfil (ver 18.9.4)
quarkus.log.category."audit".level=INFO
quarkus.log.category."audit".min-level=INFO
```

> **Cuidado con `quarkus.log.min-level`.** Es una propiedad **fijada en tiempo de build**: si el mínimo global
> queda en `WARN`, ningún ajuste en runtime logra que se emitan los `INFO` de auditoría, y el requisito de
> trazabilidad queda incumplido sin ningún error visible. Declarar `min-level=INFO` explícitamente para la
> categoría `audit`.

#### 18.5.3 Texto plano por defecto; JSON solo con backend que lo consuma

**El formato por defecto es texto plano en los tres perfiles.** El JSON estructurado solo tiene sentido si un
backend indexa los campos; si nadie lo consume, únicamente dificulta la lectura con `oc logs`.

Como los campos viven en el MDC, migrar a JSON es un cambio de configuración, no de código.

```properties
# --- JSON estructurado: DESACTIVADO ---
# Activar SOLO si el ClusterLogForwarder de OpenShift tiene 'parse: json' habilitado
# y un structuredTypeKey/structuredTypeName definido. Confirmar con el equipo de
# plataforma antes de habilitarlo: con el forwarder sin configurar, el JSON llega
# como texto sin indexar y se pierde toda la legibilidad sin ganar nada.
#
# Requiere la dependencia io.quarkiverse.loggingjson:quarkus-logging-json
#
#%prod.quarkus.log.console.json.enabled=true
#%prod.quarkus.log.console.json.additional-field.env.value=prod
#%prod.quarkus.log.console.json.additional-field.env.type=string
#%prod.quarkus.log.console.json.additional-field.eventType.value=%X{eventType}
#%prod.quarkus.log.console.json.additional-field.eventType.type=string
#%prod.quarkus.log.console.json.additional-field.sessionId.value=%X{sessionId}
#%prod.quarkus.log.console.json.additional-field.sessionId.type=string
#%prod.quarkus.log.console.json.additional-field.clientIp.value=%X{clientIp}
#%prod.quarkus.log.console.json.additional-field.clientIp.type=string
#%prod.quarkus.log.console.json.additional-field.user.value=%X{user}
#%prod.quarkus.log.console.json.additional-field.user.type=string
#%prod.quarkus.log.console.json.additional-field.outcome.value=%X{outcome}
#%prod.quarkus.log.console.json.additional-field.outcome.type=string
#%prod.quarkus.log.console.json.additional-field.correlationId.value=%X{correlationId}
#%prod.quarkus.log.console.json.additional-field.correlationId.type=string
#%prod.quarkus.log.console.json.additional-field.service.value=%X{service}
#%prod.quarkus.log.console.json.additional-field.service.type=string
```

Dos detalles de sintaxis que suelen fallar:

- La forma correcta es `.additional-field.<nombre>.value` + `.additional-field.<nombre>.type` (singular, dos
  líneas). La forma `additional-fields` (plural, una línea) **no es válida**.
- La propiedad `quarkus.log.console.json` (sin `.enabled`) está **deprecada** desde Quarkus 3.19 en favor de
  `quarkus.log.console.json.enabled`. Verificar cuál aplica según la versión del proyecto.

**Condición de adopción:** cuando plataforma confirme que el `ClusterLogForwarder` tiene `parse: json`, se
descomenta el bloque en `%prod` y se deja `%dev`/`%qa` en texto plano para no perder legibilidad local.

#### 18.5.4 Tramas de REST Client — nunca en qa ni prod

```properties
# --- Tramas REST Client salientes: SOLO en dev local ---
# Loguea headers y body completos. En qa el riesgo es real: los datos de prueba
# suelen incluir tarjetas con PAN válido (ver 18.10).
%dev.quarkus.rest-client.logging.scope=request-response
%dev.quarkus.rest-client.logging.body-limit=4096
%qa.quarkus.rest-client.logging.scope=none
%prod.quarkus.rest-client.logging.scope=none
```

Cambio respecto a la versión anterior de este documento: **`%qa` pasa de `request-response` a `none`**. El
gate solo existía para `prod`, dejando el body completo de las tramas en el log de QA, donde con frecuencia se
usan datos productivos o tarjetas de prueba con PAN que pasa Luhn.

Si un servicio maneja datos de tarjeta, `scope=none` aplica **también en `%dev`**: usar el debugger, no el log.

#### 18.5.5 Access log

```properties
# --- Access log HTTP entrante ---
# %m método, %U path SIN query string, %s status, %b bytes, %D duración ms
# PROHIBIDO %r (línea de request completa: incluye el query string) y %q.
# Ver 17.5: los datos sensibles no viajan en la URL, y el access log es una de las razones.
%dev.quarkus.http.access-log.enabled=true
%dev.quarkus.http.access-log.pattern=%m %U %s %b ms=%D
%qa.quarkus.http.access-log.enabled=true
%qa.quarkus.http.access-log.pattern=%m %U %s %b ms=%D
%prod.quarkus.http.access-log.enabled=false
```

`%prod` lo mantiene desactivado porque `[REQUEST_IN]`/`[REQUEST_OUT]` de `CorrelationFilter` ya cubren la
misma información **con** el contexto de auditoría, que el access log no tiene.

#### 18.5.6 Sin log a archivo

```properties
# En contenedores se escribe a stdout: el recolector del clúster lo levanta.
# Un archivo dentro del pod se pierde al reiniciar y no es auditable.
quarkus.log.file.enable=false
```

La retención y la inmutabilidad de los logs de auditoría son responsabilidad del `ClusterLogForwarder` de
OpenShift, no del microservicio (ver 18.9.5).

### 18.6 PII en categorías de log de librerías de infraestructura

Algunas extensiones de Quarkus loguean PII a niveles que parecen inofensivos (`quarkus-mailer` imprime
destinatario y cuerpo a nivel `INFO`). Siempre revisar antes de subir el nivel de una categoría externa y
aplicar gate por perfil.

```properties
%dev.quarkus.log.category."io.quarkus.mailer".level=DEBUG
%qa.quarkus.log.category."io.quarkus.mailer".level=WARN
%prod.quarkus.log.category."io.quarkus.mailer".level=WARN

# Tramas HTTP de bajo nivel: nunca por encima de WARN fuera de dev
%qa.quarkus.log.category."io.vertx.core.http".level=WARN
%prod.quarkus.log.category."io.vertx.core.http".level=WARN

# SQL con parámetros: solo en dev
%dev.quarkus.hibernate-orm.log.bind-parameters=true
%qa.quarkus.hibernate-orm.log.bind-parameters=false
%prod.quarkus.hibernate-orm.log.bind-parameters=false
```

Categorías a revisar en cada servicio antes de desplegar: `io.quarkus.mailer`, `io.vertx.core.http`,
`org.hibernate.SQL`, `org.apache.http.wire`, `io.netty.handler.logging` y la del SDK de cualquier proveedor
externo (pasarelas de pago, buró, mensajería).

### 18.7 Catálogo de eventos técnicos

El `eventType` va al MDC vía `CorrelationContext.setEventType(...)`, no como prefijo del texto del mensaje
(el formato de la sección 18.5.1 ya lo renderiza entre corchetes).

| `eventType` | Cuándo se usa |
|---|---|
| `REQUEST_IN` | Entrada a un endpoint HTTP |
| `REQUEST_OUT` | Salida de un endpoint HTTP, con status code y latencia |
| `AMQ_CONSUMED` | Mensaje recibido desde una cola AMQP |
| `AMQ_PROCESSED` | Mensaje procesado correctamente |
| `AMQ_PUBLISH` | Mensaje publicado exitosamente en una cola AMQP |
| `AMQ_PUBLISH_FAILED` / `AMQ_FAILED` | Falla al publicar o procesar un mensaje AMQP |
| `AMQ_DLQ` | Mensaje enviado a la cola de mensajes muertos |
| `DELIVERY_SENDING` / `DELIVERY_SENT` | Envío iniciado / aceptado por un proveedor externo |
| `DELIVERY_FAILED_TEMP` / `DELIVERY_FAILED_PERM` | Falla temporal / permanente en la entrega |
| `DOWNSTREAM_CALL` / `DOWNSTREAM_ERROR` | Llamada a dependencia externa y su fallo |
| `CIRCUIT_OPEN` / `CIRCUIT_CLOSED` | Cambio de estado de un circuit breaker |
| `UNHANDLED_ERROR` | Excepción no controlada capturada por el mapper genérico |
| `WARN_SKIP` | Situación anómala no crítica que se omite sin interrumpir el flujo |

### 18.8 Checklist de implementación para un microservicio nuevo

1. Crear `util/CorrelationContext.java`, `util/Outcome.java` y `util/LogSanitizer.java`.
2. Crear `filter/CorrelationFilter.java` (siembra el MDC completo) y `filter/CorrelationClientFilter.java`.
3. Configurar `quarkus.log.console.format` con el formato estándar de la sección 18.5.1, más la zona horaria.
4. Declarar la categoría `audit` con `level` y `min-level` en `INFO` (sección 18.9.4).
5. Crear `service/AuditLogger.java` e instrumentar los eventos de usuario del catálogo 18.9.2.
6. Configurar `proxy-address-forwarding` y `trusted-proxies` para que la IP registrada sea la real (18.9.3).
7. Verificar los gates de perfil: `rest-client.logging.scope=none` en qa y prod, access log sin `%r`.
8. Revisar las categorías de logging de librerías con datos del cliente (sección 18.6).
9. Si consume colas AMQP: propagar `correlationId`, `originUser` y `originSessionId` en el DTO; sembrar y
   limpiar el MDC en `@Incoming`.
10. Si maneja datos de tarjeta: aplicar la sección 18.10 completa y añadir el control de CI del punto 18.10.6.
11. Añadir el test de la sección 18.11 que verifica el formato de log y el enmascaramiento.
12. **No** llamar `CorrelationContext.getCorrelationId()` desde el código de negocio.

### 18.9 Trazabilidad de acciones de usuario (auditoría)

Esta sección cubre el primer requisito del departamento de seguridad: *poder trazar las acciones realizadas
por los usuarios en el aplicativo*. El `correlationId` por sí solo no lo cumple — permite reconstruir un
request, pero no decir **quién** lo ejecutó.

#### 18.9.1 Campos obligatorios del contexto de auditoría

| Clave MDC | Origen | Valor si no aplica |
|---|---|---|
| `user` | `SecurityIdentity.getPrincipal().getName()` o claim `sub` del JWT | `anonymous` |
| `sessionId` | Claim `jti` del JWT; alternativamente header `X-Session-Id` | `-` |
| `clientIp` | `HttpServerRequest.remoteAddress()` con proxy forwarding configurado | `-` |
| `eventType` | Catálogo de 18.7 (técnico) o 18.9.2 (auditoría) | — obligatorio |
| `outcome` | `SUCCESS` / `FAILURE` / `DENIED` | — obligatorio |
| `correlationId` | Header `X-Correlation-Id` o UUID generado | — obligatorio |

**Prohibido** loguear el JWT completo, la cookie de sesión o cualquier credencial como valor de `sessionId`.
El `jti` identifica el token sin permitir reutilizarlo; el token en sí es una credencial válida y un log con
tokens es un vector de suplantación.

#### 18.9.2 Catálogo de eventos de auditoría

Estos eventos son distintos de los técnicos de 18.7: registran **intención del usuario**, no mecánica del
transporte. Todo endpoint que lea o modifique datos de cliente debe emitir uno.

| `eventType` | Cuándo se registra | Nivel |
|---|---|---|
| `AUTH_SUCCESS` | Autenticación exitosa | INFO |
| `AUTH_FAILURE` | Credenciales inválidas o token rechazado | WARN |
| `ACCESS_DENIED` | Autenticado pero sin permisos (403) | WARN |
| `DATA_READ` | Consulta de datos de cliente o de negocio | INFO |
| `DATA_CREATE` | Creación de un recurso | INFO |
| `DATA_UPDATE` | Modificación de un recurso | INFO |
| `DATA_DELETE` | Eliminación de un recurso | INFO |
| `CONFIG_CHANGE` | Cambio de parámetro operativo o de configuración | INFO |
| `EXPORT` | Descarga o exportación masiva de datos | INFO |
| `BUSINESS_ACTION` | Acción de negocio relevante (envío de notificación, autorización) | INFO |

Reglas de contenido del mensaje:

- Identificar el recurso afectado por su **identificador técnico** (`id=42`, `cNotificacion=13`), nunca por
  datos personales o de tarjeta.
- En `DATA_UPDATE`, registrar **qué campos** cambiaron, no sus valores:
  `campos=[direccion, telefono]`, jamás `telefono: 0999... -> 0988...`.
- El resultado va en `outcome`, no repetido en el texto.

#### 18.9.3 IP real del cliente detrás del router de OpenShift

En OpenShift el tráfico llega por el router, así que `remoteAddress()` devuelve la IP del router y no la del
cliente. Hay que habilitar el forwarding **y** declarar los proxies de confianza:

```properties
quarkus.http.proxy.proxy-address-forwarding=true
quarkus.http.proxy.enable-forwarded-host=true
# Obligatorio: sin trusted-proxies, cualquier cliente puede falsificar X-Forwarded-For
# y la IP registrada en la auditoría deja de ser evidencia válida.
quarkus.http.proxy.trusted-proxies=${TRUSTED_PROXY_CIDR:10.0.0.0/8}
```

**Prohibido** leer `X-Forwarded-For` manualmente desde el código: sin validación de proxy de confianza es un
header controlado por el cliente y la IP resultante es falsificable a voluntad.

#### 18.9.4 Implementación: `AuditLogger`

Los eventos de auditoría van a una categoría dedicada (`audit`), separada del log de aplicación, para poder
enrutarla y retenerla de forma independiente.

```java
/**
 * Registro de eventos de auditoría. Categoría dedicada "audit" para permitir
 * retención y enrutamiento independientes del log de aplicación.
 */
@ApplicationScoped
public class AuditLogger {

    private static final Logger AUDIT = Logger.getLogger("audit");

    /**
     * Registra una acción de usuario.
     *
     * @param eventType   evento del catálogo 18.9.2
     * @param outcome     resultado de la acción
     * @param descripcion descripción del evento; sin datos sensibles ni de tarjeta
     */
    public void log(AuditEvent eventType, Outcome outcome, String descripcion) {
        CorrelationContext.setEventType(eventType.name());
        CorrelationContext.setOutcome(outcome);
        String safe = LogSanitizer.sanitize(descripcion);
        if (outcome == Outcome.SUCCESS) {
            AUDIT.info(safe);
        } else {
            AUDIT.warn(safe);
        }
    }
}
```

Uso desde el recurso o el servicio de aplicación:

```java
return productoService.actualizar(id, request)
        .invoke(p -> auditLogger.log(AuditEvent.DATA_UPDATE, Outcome.SUCCESS,
                "Producto actualizado id=%d campos=%s".formatted(p.id(), request.camposModificados())))
        .onFailure().invoke(e -> auditLogger.log(AuditEvent.DATA_UPDATE, Outcome.FAILURE,
                "Fallo al actualizar el producto id=%d".formatted(id)));
```

**La auditoría nunca puede silenciarse por configuración:**

```properties
quarkus.log.category."audit".level=INFO
quarkus.log.category."audit".min-level=INFO
```

`min-level` se fija en tiempo de build. Si queda por debajo de `INFO`, ningún cambio en runtime consigue que
los eventos se emitan y el requisito queda incumplido **sin ningún error visible**. Es la falla más fácil de
introducir en esta sección.

#### 18.9.5 Retención e integridad

Responsabilidad de plataforma, pero de cumplimiento obligatorio y por tanto documentada aquí:

- Los logs se escriben a **stdout**; el `ClusterLogForwarder` de OpenShift los reenvía al almacén central.
- El almacén debe ser **append-only**: ni la aplicación ni el equipo de desarrollo pueden alterar o borrar
  registros de auditoría.
- Retención mínima recomendada para entornos con datos de tarjeta: **12 meses**, con los **3 meses** más
  recientes disponibles para consulta inmediata.
- **Prohibido** escribir logs a archivo dentro del pod (`quarkus.log.file.enable=false`): se pierden al
  reiniciar y no son auditables.

### 18.10 Datos sensibles y de tarjetas — prohibición absoluta

Esta sección cubre el segundo requisito del departamento de seguridad: *los logs no deben almacenar
información confidencial de tarjetas*. **Un log es almacenamiento.** Todo lo que aquí se prohíbe, se prohíbe
en cualquier nivel (`TRACE` incluido), en cualquier perfil (`%dev` incluido) y en cualquier entorno.

#### 18.10.1 Qué no puede aparecer nunca

| Dato | Regla | Nota |
|---|---|---|
| PAN completo (número de tarjeta) | **Prohibido** | Solo enmascarado, ver 18.10.2 |
| CVV / CVC2 / CID / CVV2 | **Prohibido, ni enmascarado** | No se almacena tras la autorización |
| PIN y PIN block | **Prohibido, ni enmascarado** | — |
| Track 1 / Track 2 / banda magnética / datos de chip | **Prohibido, ni enmascarado** | — |
| Fecha de expiración | Prohibido salvo justificación funcional documentada | — |
| Nombre del titular junto al PAN | Prohibido | La combinación agrava la exposición |
| Contraseñas, tokens, JWT, API keys, claves privadas | **Prohibido** | Ver 17.2 |

**Distinción crítica que suele pasarse por alto:** el PAN admite enmascaramiento, pero los *datos sensibles de
autenticación* (CVV, PIN, track) **no se almacenan nunca después de la autorización, ni siquiera
enmascarados**. Escribir `cvv=***` en el log ya es un error de diseño: implica que el valor pasó por el
formateador de log y que alguien consideró aceptable registrarlo.

#### 18.10.2 Enmascaramiento del PAN

Cuando exista justificación funcional documentada, el PAN se registra con un máximo de los **primeros 6** y
los **últimos 4** dígitos:

```
Correcto:   411111******1111        Correcto:   ************1111
Incorrecto: 4111111111111111        ❌ PAN completo
Incorrecto: 411111*****11111        ❌ más de 4 dígitos finales
```

Si no hay una necesidad funcional concreta, lo correcto es no registrar el PAN en absoluto: usar el
identificador interno de la tarjeta (`cardId`, token) que no es un dato de tarjeta.

#### 18.10.3 Rutas de fuga a revisar en cada servicio

Estas son las vías por las que un PAN llega al log sin que nadie lo haya escrito a propósito:

1. **Tramas de REST client** con `logging.scope=request-response` — cerrado en 18.5.4 para qa y prod.
2. **Mensajes de excepción.** Jackson incluye el valor rechazado al fallar la deserialización; Hibernate
   Validator interpola `${validatedValue}`. Cerrado en 12.4: **prohibido** `${validatedValue}` en cualquier
   mensaje de constraint, y `msgTecnico` sin mensaje de excepción en prod.
3. **Access log con `%r` o `%q`** — cerrado en 18.5.5, más la prohibición de datos sensibles en la URL (17.5).
4. **`toString()` de DTOs.** Un `record` genera `toString()` con **todos** los campos. Loguear el objeto
   completo (`LOG.infof("request=%s", request)`) publica el PAN. Ver 18.10.5.
5. **SQL con parámetros** (`bind-parameters=true`) — cerrado en 18.6 para qa y prod.
6. **Volcado de excepción del proveedor externo.** El SDK de la pasarela puede incluir el request completo en
   el mensaje de error. Sanear siempre lo que venga de un tercero.
7. **Body completo en un `ExceptionMapper`** al intentar dar contexto del error.

#### 18.10.4 `LogSanitizer` — utilitario obligatorio

```java
/**
 * Saneamiento de valores antes de escribirlos en el log.
 * Cubre dos riesgos: exposición de datos de tarjeta e inyección de líneas de log falsas.
 */
public final class LogSanitizer {

    /** Secuencias de 13 a 19 dígitos, con separadores opcionales: rango de longitud de un PAN. */
    private static final Pattern CANDIDATO_PAN =
            Pattern.compile("\\b(?:\\d[ -]?){13,19}\\b");

    /** Caracteres de control y saltos de línea: permiten fabricar entradas de log falsas. */
    private static final Pattern CARACTERES_CONTROL =
            Pattern.compile("[\\r\\n\\t\\p{Cntrl}]");

    private static final int MAX_LONGITUD = 512;

    private LogSanitizer() {}

    /**
     * Sanea un texto libre destinado al log: enmascara posibles PAN y neutraliza
     * los caracteres que permiten inyectar líneas.
     */
    public static String sanitize(String value) {
        if (value == null) return null;
        String sinControl = CARACTERES_CONTROL.matcher(value).replaceAll("_");
        String enmascarado = maskPanCandidates(sinControl);
        return enmascarado.length() > MAX_LONGITUD
                ? enmascarado.substring(0, MAX_LONGITUD) + "...[truncado]"
                : enmascarado;
    }

    /**
     * Sanea un identificador que se renderiza en un campo posicional del formato de log
     * (usuario, sesión, correlationId). Restringe el alfabeto para que no rompa el parseo.
     */
    public static String sanitizeId(String value) {
        if (value == null || value.isBlank()) return CorrelationContext.NOT_AVAILABLE;
        String limpio = value.replaceAll("[^A-Za-z0-9._@:-]", "");
        return limpio.isBlank() ? CorrelationContext.NOT_AVAILABLE
                : limpio.substring(0, Math.min(limpio.length(), 64));
    }

    /**
     * Enmascara un PAN dejando como máximo los primeros 6 y los últimos 4 dígitos.
     *
     * @param pan número de tarjeta; puede ser nulo
     * @return el PAN enmascarado, o null si la entrada era nula
     */
    public static String maskPan(String pan) {
        if (pan == null) return null;
        String digitos = pan.replaceAll("\\D", "");
        if (digitos.length() < 13) return "****";           // no parece un PAN: se oculta completo
        String bin = digitos.substring(0, 6);
        String ultimos = digitos.substring(digitos.length() - 4);
        return bin + "*".repeat(digitos.length() - 10) + ultimos;
    }

    /** Enmascara toda secuencia que parezca un PAN y valide Luhn, para reducir falsos positivos. */
    private static String maskPanCandidates(String value) {
        Matcher m = CANDIDATO_PAN.matcher(value);
        StringBuilder sb = new StringBuilder();
        while (m.find()) {
            String candidato = m.group();
            String digitos = candidato.replaceAll("\\D", "");
            String reemplazo = passesLuhn(digitos) ? maskPan(digitos) : candidato;
            m.appendReplacement(sb, Matcher.quoteReplacement(reemplazo));
        }
        m.appendTail(sb);
        return sb.toString();
    }

    /** Algoritmo de Luhn: distingue un PAN real de un identificador numérico cualquiera. */
    private static boolean passesLuhn(String digitos) {
        int suma = 0;
        boolean alternar = false;
        for (int i = digitos.length() - 1; i >= 0; i--) {
            int d = digitos.charAt(i) - '0';
            if (alternar) {
                d *= 2;
                if (d > 9) d -= 9;
            }
            suma += d;
            alternar = !alternar;
        }
        return suma % 10 == 0;
    }
}
```

`LogSanitizer` es una **red de seguridad**, no una licencia para loguear datos de tarjeta. El diseño correcto
es que el PAN nunca llegue al log; el sanitizador existe para el caso en que un campo de texto libre lo
contenga sin que el desarrollador lo previera.

#### 18.10.5 `toString()` en DTOs con datos sensibles

Un `record` genera automáticamente un `toString()` con todos los campos. Cualquier log del objeto completo, o
un mensaje de excepción que lo incluya, publica el PAN. Sobrescribirlo es obligatorio:

```java
public record CardPaymentRequest(
        @Schema(description = "Número de tarjeta", examples = {"4111111111111111"}) String pan,
        @Schema(description = "Código de verificación", examples = {"123"}) String cvv,
        @Schema(description = "Monto de la transacción", examples = {"150.00"}) BigDecimal monto
) {
    /**
     * toString() sobrescrito: el generado por el record expondría el PAN y el CVV
     * en cualquier log o mensaje de excepción que incluya este objeto.
     */
    @Override
    public String toString() {
        return "CardPaymentRequest[pan=%s, cvv=***, monto=%s]"
                .formatted(LogSanitizer.maskPan(pan), monto);
    }
}
```

Regla general: **prohibido** loguear un DTO completo (`LOG.infof("request=%s", request)`). Loguear campos
concretos y no sensibles. La revisión de PR debe rechazar cualquier interpolación de un objeto de request
completo.

#### 18.10.6 Control automatizado en CI

La regla necesita un control que no dependa de la memoria del desarrollador. Añadir al pipeline un paso que
inspeccione los logs producidos por la suite de tests:

```bash
#!/usr/bin/env bash
# scripts/check-log-leaks.sh — falla el build si un PAN de prueba aparece en los logs de test
set -euo pipefail

LOG_DIR="${1:-target/surefire-reports}"
PATRON_PAN='[^0-9*][0-9]{13,19}[^0-9*]'

if grep -rElq "$PATRON_PAN" "$LOG_DIR" 2>/dev/null; then
  echo "ERROR: posible PAN sin enmascarar en los logs de test:"
  grep -rEn "$PATRON_PAN" "$LOG_DIR" | head -20
  exit 1
fi

# Nombres de campo que nunca deben aparecer seguidos de un valor
for campo in cvv cvc pin track password token secret; do
  if grep -rEiq "${campo}[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9]" "$LOG_DIR" 2>/dev/null; then
    echo "ERROR: campo sensible '${campo}' con valor en los logs de test"
    exit 1
  fi
done

echo "OK: sin fugas detectadas en $LOG_DIR"
```

Complementos recomendados: usar tarjetas de prueba con PAN que pase Luhn en los tests (para que el control
tenga algo que detectar), y correr el script también sobre una muestra de los logs de QA como verificación
periódica.

### 18.11 Verificación del cumplimiento

El cumplimiento debe demostrarse con tests, no con una revisión visual. Tests obligatorios:

```java
@QuarkusTest
class LoggingComplianceIT {

    @Test
    @DisplayName("El formato de log debe incluir fecha, tipo de evento, sesión, IP, usuario y resultado")
    void shouldEmitLogInSecurityStandardFormat() {
        // Captura la salida del logger y verifica la estructura completa exigida en 18.1
    }

    @Test
    @DisplayName("Debe enmascarar el PAN dejando máximo 6 primeros y 4 últimos dígitos")
    void shouldMaskPan() {
        assertThat(LogSanitizer.maskPan("4111111111111111")).isEqualTo("411111******1111");
    }

    @Test
    @DisplayName("Debe enmascarar un PAN embebido en texto libre")
    void shouldMaskPanInsideFreeText() {
        assertThat(LogSanitizer.sanitize("Error al procesar la tarjeta 4111111111111111 del cliente"))
                .doesNotContain("4111111111111111")
                .contains("411111******1111");
    }

    @Test
    @DisplayName("No debe enmascarar identificadores numéricos que no son PAN")
    void shouldNotMaskNonPanNumbers() {
        assertThat(LogSanitizer.sanitize("cNotificacion=1234567890123")).contains("1234567890123");
    }

    @Test
    @DisplayName("Debe neutralizar saltos de línea para evitar inyección de logs")
    void shouldPreventLogInjection() {
        String malicioso = "usuario\n2026-01-01T00:00:00.000-05:00 [AUTH_SUCCESS] [x - y - admin] Falso";
        assertThat(LogSanitizer.sanitize(malicioso)).doesNotContain("\n");
    }

    @Test
    @DisplayName("El toString() de un DTO con datos de tarjeta no debe exponer PAN ni CVV")
    void shouldNotExposeCardDataInToString() {
        var request = new CardPaymentRequest("4111111111111111", "123", new BigDecimal("150.00"));
        assertThat(request.toString())
                .doesNotContain("4111111111111111")
                .doesNotContain("123")
                .contains("411111******1111");
    }

    @Test
    @DisplayName("Debe registrar el evento de auditoría con usuario y resultado al modificar un recurso")
    void shouldEmitAuditEventOnDataUpdate() {
        // Verifica eventType=DATA_UPDATE, user presente y outcome=SUCCESS en la categoría "audit"
    }
}
```

Adicionalmente, la revisión de PR debe verificar:

- [ ] Ningún log interpola un DTO de request completo.
- [ ] `rest-client.logging.scope=none` en `%qa` y `%prod`.
- [ ] El access log no usa `%r` ni `%q`.
- [ ] Ningún mensaje de constraint usa `${validatedValue}`.
- [ ] `msgTecnico` no contiene `exception.getMessage()` en `%prod`.
- [ ] La categoría `audit` tiene `min-level=INFO`.
- [ ] Todo endpoint que lee o modifica datos de cliente emite un evento de auditoría.

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
# Puerto local del inventario de PORT_MANAGEMENT.md; en OpenShift siempre 8080
%dev.quarkus.http.port=1XXXX

# ============================================================
# HTTP — límites y seguridad (sección 17.3, 17.4)
# ============================================================
quarkus.http.limits.max-body-size=1M
quarkus.http.limits.max-header-size=8K
# IP real del cliente detrás del router de OpenShift (sección 18.9.3)
quarkus.http.proxy.proxy-address-forwarding=true
quarkus.http.proxy.trusted-proxies=${TRUSTED_PROXY_CIDR:10.0.0.0/8}

# ============================================================
# REST CLIENTS — <Nombre del servicio externo>
# ============================================================
%dev.quarkus.rest-client.x-service.url=...
%qa.quarkus.rest-client.x-service.url=...
%prod.quarkus.rest-client.x-service.url=...
quarkus.rest-client.x-service.connect-timeout=3000
quarkus.rest-client.x-service.read-timeout=5000
# Tramas: solo dev (sección 18.5.4)
%dev.quarkus.rest-client.logging.scope=request-response
%qa.quarkus.rest-client.logging.scope=none
%prod.quarkus.rest-client.logging.scope=none

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
# LOGGING — formato estándar de seguridad (sección 18.5)
# ============================================================
quarkus.log.console.format=%d{yyyy-MM-dd'T'HH:mm:ss.SSSXXX} [%X{eventType}] [%X{sessionId} - %X{clientIp} - %X{user}] %s, outcome=%X{outcome} [cid=%X{correlationId}]%e%n
quarkus.log.console.timezone=America/Guayaquil
quarkus.log.file.enable=false
# La auditoría nunca se silencia (sección 18.9.4)
quarkus.log.category."audit".level=INFO
quarkus.log.category."audit".min-level=INFO

# ============================================================
# SECRETOS (sección 11) — sin default fuera de %dev
# ============================================================
```

> **Los secretos van al final y en su propio bloque**, para que una revisión rápida pueda verificar de un
> vistazo que ninguno tiene fallback fuera de `%dev`.

### 21.2 Una dependencia externa, un bloque

Todo lo relacionado a una misma dependencia externa va junto: las 3 URLs por perfil, los timeouts y cualquier configuración propia. No separar URLs y timeouts en secciones distintas del archivo.

### 21.3 Perfiles y entornos de despliegue

- `%dev` — desarrollo local.
- `%qa` / `%prod` — despliegues en clúster, usando variables de entorno con fallback (`${VARIABLE:valor-default}`), nunca URLs hardcodeadas. **Excepción: los secretos no llevan fallback** (sección 11.1).
- El log a archivo (`quarkus.log.file.*`) **no es el patrón por defecto** en entornos containerizados — escribir a stdout y dejar que el recolector del clúster lo levante.
- **Prohibido** un perfil `%test` que apunte a servicios externos reales: los tests usan WireMock (sección 10.9).

### 21.4 Configuración tipada con `@ConfigMapping`

**Prohibido** dispersar `@ConfigProperty` por los beans para agrupar configuración relacionada. Una interfaz
`@ConfigMapping` valida en el arranque: si falta un valor requerido, el pod no arranca y el error indica la
propiedad exacta. Con `@ConfigProperty` esparcido, el fallo aparece en runtime la primera vez que se ejecuta
ese camino de código, potencialmente semanas después del despliegue.

```java
/**
 * Configuración del proveedor de mensajería. Se valida en el arranque:
 * una propiedad requerida ausente impide el startup.
 */
@ConfigMapping(prefix = "dispatch.provider")
public interface DispatchProviderConfig {

    /** URL base del proveedor. Sin default: es obligatoria. */
    String url();

    /** Reintentos ante fallo transitorio. */
    @WithDefault("3")
    int maxRetries();

    /** Ventana de tiempo del batch, en milisegundos. */
    @WithDefault("500")
    @Min(100)
    long batchWindowMs();

    /** Configuración anidada de credenciales. */
    Credentials credentials();

    interface Credentials {
        String clientId();
        String clientSecret();
    }
}
```

```java
// Uso: inyección por constructor, igual que cualquier dependencia
@ApplicationScoped
public class DispatchService {

    private final DispatchProviderConfig config;

    public DispatchService(DispatchProviderConfig config) {
        this.config = config;
    }
}
```

Se sigue usando `@ConfigProperty` para valores aislados sin relación con otros (ej.
`quarkus.application.name`). El criterio: **tres o más propiedades con el mismo prefijo van en un
`@ConfigMapping`**.

---

## 22. Catálogo de Códigos de Respuesta de Negocio

> **Catálogo maestro:** el contenido completo, versionado y con procedimiento de gobierno está en
> **`RESPONSE_CODES.md`** (mismo directorio). Las tablas de 22.2 son un resumen de referencia rápida; ante
> discrepancia, manda `RESPONSE_CODES.md`.

### 22.1 Principio fundamental

`codRespuesta` es un **código de negocio**, no un espejo del HTTP status. El código HTTP lo transporta el protocolo; `codRespuesta` expresa el resultado desde la perspectiva del dominio de la aplicación.

- **El éxito siempre es `"000"`**, independientemente del HTTP status (`200`, `201`, `202`).
- Cualquier valor distinto de `"000"` indica una condición anómala específica.
- Los códigos son cadenas de tres dígitos (`String`) para compatibilidad con sistemas legados y para permitir sub-rangos futuros.
- **Prohibido** devolver el HTTP status como valor de `codRespuesta` (ej. `"200"`, `"404"`, `"500"`). Por eso los rangos `4xx` y `5xx` están reservados y no se usan.
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

#### Rango `6xx` — Autenticación y autorización

HTTP asociado: `401`, `403`.

Estos códigos son **obligatorios**. Sin ellos, el mapper genérico termina asignando `RESOURCE_NOT_FOUND` a un
401 o un 403, y el consumidor recibe "recurso no encontrado" cuando el problema es de credenciales o permisos.

Se eligió el rango `6xx` deliberadamente para **no** usar `4xx`: un `codRespuesta` de `"401"` sería
indistinguible del HTTP status y contradice el principio de 22.1.

| Código | Constante sugerida | `msgUsuario` estándar | Escenario |
|--------|-------------------|----------------------|-----------|
| `600` | `UNAUTHENTICATED` | `No autenticado` | Token ausente, mal firmado, o con issuer/audience inválido. HTTP 401. |
| `601` | `ACCESS_DENIED` | `No tiene permisos para realizar esta operación` | Autenticado pero sin el rol requerido. HTTP 403. |
| `602` | `TOKEN_EXPIRED` | `La sesión ha expirado, vuelva a autenticarse` | Token válido pero vencido; permite al cliente renovar en lugar de reautenticar. HTTP 401. |

Dos reglas asociadas:

- Todo evento de este rango debe emitir el evento de auditoría correspondiente (`AUTH_FAILURE` o
  `ACCESS_DENIED`, sección 18.9.2) con `outcome=DENIED`.
- **`msgTecnico` debe ser genérico.** No revelar si el usuario existe, si la contraseña era incorrecta ni qué
  rol faltaba: eso permite enumerar usuarios y permisos. El detalle va al log de auditoría, nunca a la
  respuesta.

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
| `600`, `602` | `401` | No autenticado o token expirado |
| `601` | `403` | Autenticado sin permisos suficientes |
| `900`, `901` | `500` | Error interno |

### 22.7 Catálogo compartido entre microservicios

El catálogo completo y versionado vive en **`RESPONSE_CODES.md`**, en este mismo directorio. Ese archivo es la
única fuente de verdad; las tablas de la sección 22.2 son un resumen de referencia rápida.

Antes de crear o modificar un código, consultar `RESPONSE_CODES.md` y seguir su procedimiento de gobierno. Un
código inventado localmente rompe el contrato compartido de la sección 22.5.

> **Limitación reconocida.** Un archivo Markdown replicado a mano en cada repositorio deriva con el tiempo. La
> solución correcta a mediano plazo es publicar un artefacto Maven compartido (`commons-response`) en Nexus con
> el enum `ResponseCode` y la clase `ApiResponse<T>`, versionado y consumido como dependencia. Mientras eso no
> exista, `RESPONSE_CODES.md` es el mecanismo vigente y su consulta es obligatoria.

---

## 23. Documentos de Referencia Obligatorios

Estos documentos acompañan a este estándar y **deben consultarse** en los momentos indicados. No son material
opcional de lectura.

| Documento | Cuándo consultarlo | Qué contiene |
|---|---|---|
| `RESPONSE_CODES.md` | Al definir cualquier `codRespuesta` o crear el enum `ResponseCode` | Catálogo maestro versionado de códigos de negocio y su gobierno |
| `PORT_MANAGEMENT.md` | Al crear un microservicio nuevo, **antes** de asignar `%dev.quarkus.http.port` | Rangos semánticos por tipo de servicio e inventario de puertos asignados |

Reglas de uso:

- **`PORT_MANAGEMENT.md` se actualiza en el mismo PR** en que se crea el microservicio, no después. El
  inventario solo sirve si está al día; los conflictos de puerto documentados en ese archivo son consecuencia
  de haberlo actualizado tarde.
- El puerto elegido debe pertenecer al rango del tipo de servicio (worker, core, domain, orquestador, etc.) y
  no estar ocupado por otro servicio del inventario.
- En OpenShift el puerto interno es siempre `8080`. La asignación del inventario aplica **solo** al perfil
  `%dev` para permitir levantar varios servicios en paralelo en la máquina del desarrollador.

```properties
# Puerto local del inventario de PORT_MANAGEMENT.md; en el clúster se usa 8080
%dev.quarkus.http.port=15090
```

---

## 24. Bloqueo del Event Loop

Esta es la causa más frecuente de incidentes en Quarkus reactivo, y la más grave: un bloqueo no degrada un
request, **degrada el pod completo**.

### 24.1 El problema

RESTEasy Reactive atiende los requests en un número reducido de hilos de I/O (típicamente `2 × núcleos`). Una
operación bloqueante dentro de un operador Mutiny congela ese hilo, y con él **todos** los requests que tenía
asignados. Con 4 hilos de I/O, cuatro llamadas bloqueantes concurrentes dejan el servicio sin atender nada:
health checks incluidos, con lo que OpenShift reinicia el pod.

Operaciones bloqueantes que aparecen por descuido dentro de una cadena reactiva:

- JDBC clásico (`java.sql.*`), incluido cualquier ORM no reactivo.
- `File`, `Files`, `InputStream.read()` sobre disco o red.
- `HttpClient` síncrono, `RestTemplate`, SDKs de terceros que no exponen API reactiva.
- `Thread.sleep()`, `CountDownLatch.await()`, `Future.get()`, `synchronized` con contención.
- `await().indefinitely()` / `await().atMost(...)` en código de producción.

### 24.2 Reglas

```java
// Prohibido — bloquea el event loop
@GET
public Uni<List<Producto>> listar() {
    return Uni.createFrom().item(() -> jdbcRepository.findAll());  // ❌ JDBC en el hilo de I/O
}

// Correcto (a) — @Blocking: Quarkus mueve el método al worker pool
@GET
@Blocking
public List<Producto> listar() {
    return jdbcRepository.findAll();
}

// Correcto (b) — aislar solo la parte bloqueante dentro de una cadena reactiva
@GET
public Uni<List<Producto>> listar() {
    return Uni.createFrom().item(() -> jdbcRepository.findAll())
            .runSubscriptionOn(Infrastructure.getDefaultWorkerPool());
}
```

- **Prohibido** `await()` en cualquier forma en código de producción. Solo en tests, y con timeout (10.7).
- Todo método que ejecute una operación bloqueante debe llevar `@Blocking` **o** desplazarse explícitamente
  con `runSubscriptionOn`.
- Un método anotado `@Blocking` **no** debe retornar `Uni`/`Multi`: si es bloqueante, retorna el tipo directo.
  Mezclar ambos indica confusión sobre dónde se ejecuta el código.
- **Prohibido** mezclar `@RunOnVirtualThread` con cadenas Mutiny. Los hilos virtuales resuelven el bloqueo en
  código imperativo; combinarlos con operadores reactivos añade dos modelos de concurrencia al mismo método sin
  beneficio. Elegir uno: reactivo con `Uni`, o imperativo con `@RunOnVirtualThread`.

### 24.3 Detección obligatoria

Quarkus incluye un detector de bloqueo. **Debe estar activo en dev y qa**, donde el problema se descubre
gratis, en lugar de en producción:

```properties
%dev.quarkus.vertx.warning-exception-time=2s
%qa.quarkus.vertx.warning-exception-time=2s
# En prod se deja el valor por defecto para no añadir ruido; el bloqueo ya debió detectarse antes.
```

Cuando salta, el log muestra `Thread blocked` con el stacktrace del punto exacto. **Un `Thread blocked` en el
log es un defecto, no una advertencia informativa.**

### 24.4 Verificación

Añadir un test de carga mínimo que confirme que el servicio atiende requests concurrentes sin degradarse. Un
test funcional pasa igual con un servicio bloqueante: el bloqueo solo se manifiesta bajo concurrencia.

---

## 25. Idempotencia y Entrega de Mensajes

### 25.1 Por qué es obligatorio

La sección 20 exige `@Retry` en todos los clientes externos, y la 18.4 consume colas AMQP con semántica
*at-least-once*. **La combinación garantiza operaciones duplicadas.** Escenario concreto: el proveedor de SMS
recibe el envío, responde y la respuesta se pierde por timeout; `@Retry` reintenta; el cliente recibe dos SMS.

Para un delivery worker esto no es un detalle técnico, es un defecto funcional visible para el cliente final.

### 25.2 Clave de idempotencia en endpoints

Todo endpoint `POST` que produzca un efecto externo no reversible (enviar, cobrar, autorizar) debe aceptar una
clave de idempotencia:

```java
@POST
@Operation(summary = "Iniciar entrega de notificación")
public Uni<Response> createDelivery(
        @HeaderParam("Idempotency-Key")
        @Schema(description = "Clave única de la operación; permite reintentar sin duplicar")
        String idempotencyKey,
        @Valid DeliveryRequest request) { ... }
```

Comportamiento requerido:

- Misma clave con mismo payload → se devuelve el resultado original, con `codRespuesta` `700`
  (`DUPLICATE_REQUEST`) y **sin** repetir el efecto.
- Misma clave con payload distinto → `409 Conflict`.
- Sin clave → se procesa normalmente, y se documenta que el reintento puede duplicar.
- La clave se almacena con TTL (24 h es un valor razonable) junto al resultado de la operación.

### 25.3 Deduplicación en consumidores de cola

El consumidor debe ser idempotente por diseño, no por confianza en el broker:

```java
@Incoming("whatsapp-in")
public Uni<Void> consume(JsonObject json) {
    var message = json.mapTo(WhatsappDeliveryMessage.class);

    return deduplicationStore.alreadyProcessed(message.cNotificacion())
            .flatMap(procesado -> {
                if (procesado) {
                    CorrelationContext.setEventType("AMQ_DUPLICATE");
                    LOG.infof("Mensaje ya procesado, se descarta cNotificacion=%d",
                            message.cNotificacion());
                    return Uni.createFrom().voidItem();
                }
                return service.process(message.cNotificacion())
                        .flatMap(r -> deduplicationStore.markProcessed(message.cNotificacion()));
            });
}
```

Si no hay almacén de deduplicación disponible, la alternativa aceptable es verificar el **estado del recurso**
antes de actuar: si la notificación ya está en estado `ENVIADA`, no reenviar. Debe quedar documentado como la
estrategia elegida.

### 25.4 Mensajes fallidos: DLQ obligatoria

Sin límite de reintentos, un mensaje que siempre falla (*poison message*) se reencola indefinidamente,
consumiendo capacidad y llenando el log con el mismo error para siempre.

Todo consumidor debe definir:

- **Límite de reintentos** explícito, con backoff.
- **Dead Letter Queue** a la que va el mensaje al agotar los reintentos.
- Un log `AMQ_DLQ` a nivel `ERROR` al enviar a la DLQ, con el identificador del mensaje y la causa.
- Un procedimiento documentado de revisión y reproceso de la DLQ. Una DLQ que nadie revisa es pérdida
  silenciosa de datos.

```properties
mp.messaging.incoming.whatsapp-in.failure-strategy=dead-letter-queue
mp.messaging.incoming.whatsapp-in.dead-letter-queue.name=whatsapp-dlq
mp.messaging.incoming.whatsapp-in.max-retries=3
```

**Distinguir fallo transitorio de permanente.** Un `nack` sobre un error de validación reintenta algo que
nunca va a funcionar: eso va directo a la DLQ. Solo se reintenta lo transitorio (red, 5xx, timeout), con el
mismo criterio de la sección 20.3.

### 25.5 Publicar y persistir de forma consistente

Cuando una operación persiste y publica un mensaje, ambas acciones pueden divergir: se persiste y falla la
publicación, o al revés.

- Documentar explícitamente qué ocurre en cada caso.
- Si la consistencia es crítica, usar el patrón **outbox**: persistir el mensaje en la misma transacción que el
  dato, y publicarlo con un proceso aparte que lee la tabla outbox.
- Como mínimo, **nunca** publicar antes de persistir: un mensaje que referencia un registro inexistente falla
  en el consumidor y es más difícil de diagnosticar que un registro pendiente de publicar.

---

## 26. Observabilidad Operativa

### 26.1 Health checks y probes

La sección 2 cubre la extensión; aquí el cableado con OpenShift, que es donde suele quedar incompleto:

```yaml
readinessProbe:
  httpGet:
    path: /q/health/ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  httpGet:
    path: /q/health/live
    port: 8080
  initialDelaySeconds: 15
  periodSeconds: 20
```

- `readiness` debe verificar las dependencias **críticas**. Un servicio que no puede operar sin su BD debe
  reportarse *not ready* para que el router deje de enviarle tráfico.
- `liveness` **no** debe verificar dependencias externas. Si lo hace, una caída del proveedor externo provoca
  el reinicio en cascada de todos los pods, convirtiendo una degradación en una caída total. Es un error común
  y de consecuencias graves.
- **Prohibido** exponer `/q/health` a través del `Route` público: revela el estado interno y las dependencias
  del servicio.

### 26.2 Shutdown ordenado

Sin drenado, cada despliegue descarta los requests en vuelo y produce errores visibles para el cliente:

```properties
quarkus.shutdown.timeout=30S
# Rechaza nuevas conexiones pero termina las que están en curso
quarkus.shutdown.delay-enabled=true
```

El `terminationGracePeriodSeconds` del pod debe ser **mayor** que `quarkus.shutdown.timeout`; si es menor,
OpenShift mata el proceso antes de que termine de drenar y la configuración de Quarkus no sirve de nada.

Para consumidores de cola: dejar de aceptar mensajes nuevos y terminar los en proceso antes de cerrar.

### 26.3 Métricas — recomendado, no obligatorio

**Estado actual:** no se adopta por defecto. Se documenta la decisión y su condición de salida.

OpenShift incluye Prometheus en la stack de monitoreo; habilitar métricas de aplicación requiere que
plataforma active *User Workload Monitoring* (`enableUserWorkload: true`) y que exista un `ServiceMonitor` en
el namespace. No hay que instalar ni licenciar nada, pero sí coordinar con plataforma.

Lo que se obtiene sin escribir código, solo añadiendo la dependencia:

- Latencia y contadores por endpoint HTTP (p50/p95/p99).
- **Estado de los circuit breakers** — hoy solo observable leyendo logs, pese a que la sección 20 los exige en
  todos los clientes.
- Métricas de pools de conexión y del event loop, que es donde se manifiesta el problema de la sección 24.
- Base para un **HPA** que escale por una señal útil. Sin métricas de aplicación, el HPA solo puede usar CPU y
  memoria, que son indicadores pobres para servicios reactivos I/O-bound: un pod esperando a un proveedor
  externo está al 3% de CPU con la cola saturada.

```xml
<dependency>
    <groupId>io.quarkus</groupId>
    <artifactId>quarkus-micrometer-registry-prometheus</artifactId>
</dependency>
```

```properties
quarkus.micrometer.export.prometheus.enabled=true
# /q/metrics NUNCA se expone en el Route público: revela estructura interna y volúmenes de negocio
quarkus.micrometer.export.prometheus.path=/q/metrics
```

Costo real: una dependencia y unos pocos MB de RSS.

**Condición de adopción:** cuando plataforma confirme *User Workload Monitoring* habilitado, o cuando un
servicio necesite autoescalado por una señal distinta de CPU.

**Mientras no se adopte**, los logs de `[REQUEST_OUT]` con `latencyMs` (sección 18.3) son la única fuente de
latencia disponible. Es una razón adicional para no desactivarlos.

---

## 27. Puertas de Calidad en CI

Una regla que valida el compilador o el pipeline se cumple siempre. Una regla escrita en un documento se
cumple cuando alguien la recuerda. **Toda regla de este estándar que pueda automatizarse, debe automatizarse.**

### 27.1 Reglas ya automatizables

| Regla del estándar | Herramienta | Falla el build |
|---|---|---|
| Cobertura 90% líneas / 80% ramas (10.1) | `jacoco:check` | Sí |
| Sin `System.out.println` ni `printStackTrace` (18.2) | SpotBugs / Error Prone | Sí |
| Sin `@Inject` en campos (9) | ArchUnit | Sí |
| Estructura de paquetes y sentido de dependencias (13) | ArchUnit | Sí |
| Servicios sin dependencia de `jakarta.ws.rs` (12.1) | ArchUnit | Sí |
| Sin datos de tarjeta en logs de test (18.10.6) | `check-log-leaks.sh` | Sí |
| Secretos sin default fuera de `%dev` (11.1) | Script de revisión de properties | Sí |
| Vulnerabilidades en dependencias | Snyk / `dependency-check` | Según severidad |
| Formato de código consistente | Spotless | Sí |

### 27.2 ArchUnit — reglas arquitectónicas ejecutables

```java
@AnalyzeClasses(packages = "ec.fin.baustro")
class ArchitectureTest {

    @ArchTest
    static final ArchRule sinInyeccionEnCampos = noFields()
            .should().beAnnotatedWith(Inject.class)
            .because("la inyección debe ser por constructor (sección 9)");

    @ArchTest
    static final ArchRule serviciosSinJaxRs = noClasses()
            .that().resideInAPackage("..service..")
            .should().dependOnClassesThat().resideInAPackage("jakarta.ws.rs..")
            .because("los códigos y tipos HTTP pertenecen a la capa de presentación (sección 12.1)");

    @ArchTest
    static final ArchRule dominioSinPresentacion = noClasses()
            .that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAPackage("..resource..")
            .because("el dominio no depende de la capa de presentación (sección 13)");

    @ArchTest
    static final ArchRule sinLoggersDeOtrasLibrerias = noClasses()
            .should().dependOnClassesThat().resideInAnyPackage("org.slf4j..", "org.apache.commons.logging..")
            .because("una sola API de logging por proyecto (sección 18.2)");
}
```

### 27.3 Orden del pipeline

```bash
./mvnw clean verify          # compila, tests, jacoco:report, jacoco:check, ArchUnit
./scripts/check-log-leaks.sh # fugas de datos sensibles en logs de test
./mvnw spotless:check        # formato
snyk test                    # vulnerabilidades de dependencias
```

Cualquier paso que falle detiene el pipeline. Un gate que se puede saltar no es un gate.

### 27.4 Dependencias

- **Versiones fijas**, nunca rangos abiertos ni `LATEST`. Los rangos hacen que dos builds del mismo commit
  produzcan artefactos distintos.
- Las versiones gestionadas por el BOM de Quarkus **no** se sobrescriben: rompe la compatibilidad probada.
- Antes de añadir una dependencia nueva: verificar mantenimiento activo, y confirmar que el nombre es el
  correcto y no una variante de *typosquatting*.

---

## 28. Cómo Consumir Este Documento

Este documento es la **referencia normativa canónica**, no material de lectura secuencial. Con más de 2000
líneas, cargarlo completo en cada sesión de IA degrada el cumplimiento: las reglas del medio del documento se
atienden menos que las del inicio.

### 28.1 Estructura de consumo recomendada

| Capa | Artefacto | Alcance |
|---|---|---|
| Siempre en contexto | `AGENTS.md` en la raíz del repo (~60 líneas) | Comandos de build, versión de Java, las reglas no negociables, punteros a esta referencia |
| Carga bajo demanda | Skills por dominio (`quarkus-logging-audit`, `quarkus-rest-contract`, `quarkus-resilience`, `quarkus-testing`) | Solo la sección relevante a la tarea en curso |
| Revisión | Subagente de revisión con este documento completo | Corre en contexto propio; valida el PR contra el estándar |
| Ejecutable | Sección 27 (CI) | Lo que no depende de que nadie recuerde nada |

### 28.2 Precedencia

1. Lo que verifica el **build o el CI** (sección 27) manda sobre lo escrito aquí. Si hay contradicción, el
   documento está desactualizado.
2. `RESPONSE_CODES.md` manda sobre la sección 22.2.
3. `PORT_MANAGEMENT.md` es la única fuente de asignación de puertos.
4. Las secciones 17, 18.9 y 18.10 son **requisitos del departamento de seguridad**: no admiten excepción por
   conveniencia técnica ni por plazo de entrega.

### 28.3 Al escribir reglas nuevas

- **Regla imperativa primero, justificación después.** El orden inverso (explicar 8 líneas y luego decir qué
  hacer) reduce el cumplimiento cuando el consumidor es un modelo de lenguaje.
- Toda regla debe indicar **cómo verificarla**. Una regla sin verificación es una recomendación.
- Preferir mover la regla a la sección 27 (automatizable) antes que añadir prosa aquí.

