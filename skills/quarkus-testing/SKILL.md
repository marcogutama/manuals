---
name: quarkus-testing
description: Escribe o revisa pruebas de microservicios Quarkus según el estándar corporativo, incluyendo la configuración correcta de JaCoCo y el gate obligatorio de cobertura (90% líneas, 80% ramas). Cubre cuándo usar @QuarkusTest frente a JUnit plano, pruebas de flujos reactivos con Mutiny, WireMock para dependencias externas, y cobertura sobre código nuevo en repositorios legacy. Úsalo cuando el trabajo involucre tests, cobertura, JaCoCo, mocks, o verificación de código Quarkus.
---

# Pruebas y Cobertura — Quarkus

Referencia normativa: `/home/marco/Documents/manuals/microservices-ai-rules.md`, sección 10 (vive fuera del
repositorio; ruta absoluta).

## Umbral obligatorio

| Escenario | Umbral |
|---|---|
| Desarrollo nuevo | **90% líneas** y **80% ramas** sobre el módulo |
| Legacy con cobertura < 90% | **90% líneas** y **80% ramas** sobre el **código nuevo/modificado** |

Dos razones por las que el porcentaje de líneas no basta:

- **Ramas obligatorias.** Un servicio reactivo con `.onFailure()` o `.ifNull()` sin probar alcanza 90% de
  líneas con **cero** caminos de error ejercitados. Es la métrica que se cumple sin probar lo que falla.
- **Debe romper el build.** Un número en un documento no es un control. Se aplica con `jacoco:check`.

### Cobertura sobre código nuevo en legacy

JaCoCo mide el módulo completo, no sabe qué es nuevo. Tres vías, en orden de preferencia:

1. **SonarQube** — métrica nativa *Coverage on New Code* con quality gate sobre el New Code Period.
2. **`diff-cover`** — cruza el XML de JaCoCo con el diff de git:
   ```bash
   diff-cover target/site/jacoco/jacoco.xml --compare-branch=origin/develop --fail-under=90
   ```
3. **Revisión de PR manual** — la más débil, no auditable.

**Nunca** bajar el umbral global para que pase el build: eso convierte el gate en decorativo. Se excluyen
clases sin lógica (DTOs, enums) o se usa cobertura sobre diff.

## Configuración de JaCoCo

`quarkus-jacoco` usa **instrumentación offline** (bytecode en build); `jacoco-maven-plugin` usa el **agente en
runtime**. Combinarlos sin cuidado produce el síntoma conocido: 0%, o solo cuentan los `@QuarkusTest` y los
tests unitarios planos se ignoran.

Configuración que funciona: `quarkus-jacoco` produce el `.exec` unificado, el plugin Maven hace `report` y
`check`.

```xml
<properties>
    <quarkus.jacoco.report>false</quarkus.jacoco.report>
    <quarkus.jacoco.data-file>${project.build.directory}/jacoco-quarkus.exec</quarkus.jacoco.data-file>
</properties>
```

El `jacoco-maven-plugin` necesita tres ejecuciones: `prepare-agent` (con `destFile` al mismo `.exec` y
`append=true`), `report` y `check` (con `haltOnFailure=true`, `LINE` 0.90 y `BRANCH` 0.80).

Excluir del cálculo solo código sin lógica: `**/dto/**`, `**/*Dto.class`, `**/enums/**`. Nunca servicios.

> **Verificar, no asumir.** La interacción entre ambos plugins ha cambiado entre versiones de Quarkus. Tras
> configurar, correr `./mvnw verify` y **abrir** `target/site/jacoco/index.html` para confirmar que aparecen
> tanto las clases cubiertas por tests planos como las cubiertas por `@QuarkusTest`. Si una familia sale en 0%,
> la consolidación no funciona y el gate es falso.

## `@QuarkusTest` no es obligatorio

Arranca el contenedor CDI completo (segundos por clase) y no aporta nada a una clase sin dependencias. Usar el
nivel más liviano que permita probar:

| Clase a probar | Tipo de test |
|---|---|
| Utilidades, mappers, enums, validadores puros | JUnit plano |
| Servicios con dependencias | JUnit + `@Mock` de Mockito, inyección por constructor |
| Servicio que depende de infraestructura Quarkus real (`@ConfigMapping`, cliente REST, emisor AMQP) | `@QuarkusTest` + `@InjectMock` |
| Endpoints REST | `@QuarkusTest` + REST Assured |
| Artefacto empaquetado / nativo | `@QuarkusIntegrationTest` |

La inyección por constructor obligatoria es lo que permite instanciar cualquier servicio con `new`. Si una
clase *solo* puede probarse con `@QuarkusTest`, suele indicar una dependencia oculta que debería estar en el
constructor.

```java
@ExtendWith(MockitoExtension.class)
class ProductoServiceTest {
    @Mock ProductoRepository productoRepository;
    ProductoService productoService;

    @BeforeEach
    void setUp() {
        productoService = new ProductoService(productoRepository, new ProductoMapper());
    }
}
```

## Flujos reactivos

**Prohibido `await().indefinitely()`.** Cuelga la suite si el `Uni` no completa —un mock sin `when(...)`
devuelve `null`— y el build corre hasta el timeout del CI sin indicar qué test falló.

```java
// Aceptable: timeout acotado
Resultado r = servicio.ejecutar().await().atMost(Duration.ofSeconds(5));

// Preferible: UniAssertSubscriber (de mutiny-test)
servicio.ejecutar().subscribe().withSubscriber(UniAssertSubscriber.create())
        .awaitItem(Duration.ofSeconds(5)).assertItem(esperado);

// La rama de error, explícita: es donde se esconden los bugs
servicio.ejecutar().subscribe().withSubscriber(UniAssertSubscriber.create())
        .awaitFailure(Duration.ofSeconds(5))
        .assertFailedWith(ResourceNotFoundException.class, "Producto con ID 42 no existe");
```

`UniAssertSubscriber` es la forma correcta de probar `.onFailure()`, `.onItem().ifNull()` y los operadores de
recuperación — justo los caminos que el contador de ramas exige ejercitar.

## Dependencias externas: WireMock obligatorio

Un mock de Mockito sobre una interfaz `@RegisterRestClient` **no ejercita** serialización, timeouts, códigos de
estado ni las anotaciones de Fault Tolerance. No prueba nada de lo que realmente falla.

Solo un socket real revela qué excepción concreta lanza un timeout, que es lo que exige verificar la sección
20.3 del estándar.

Tests obligatorios por cliente REST externo:

- Respuesta exitosa con deserialización del body real.
- 5xx del remoto: se reintenta el número de veces configurado.
- 4xx del remoto: **no** se reintenta y no abre el circuito.
- Timeout: se propaga como el tipo esperado.

```java
wireMock.stubFor(get(urlEqualTo("/rules?cevento=1"))
        .willReturn(aResponse().withFixedDelay(6000).withStatus(200)));

assertThatThrownBy(() -> client.getRules("1", "2").await().atMost(Duration.ofSeconds(30)))
        .isInstanceOf(ProcessingException.class);

wireMock.verify(1, getRequestedFor(urlEqualTo("/rules?cevento=bad")));  // 4xx no reintenta
```

## Endpoints REST

Todo endpoint nuevo, al menos tres tests:

- Flujo feliz: 2xx correcto (`200`/`201`/`202`) con `codRespuesta: "000"`.
- Validación fallida: `400` con `codRespuesta: "100"` y array `violations`.
- No encontrado: `404` con el `codRespuesta` de dominio.

Añadir uno que confirme que la estructura de validación es la propia (`violations`) y no la de Quarkus
(`parameterViolations`): sin él, un upgrade la cambia en silencio.

## Aislamiento de configuración

**Prohibido** que un test dependa de un servicio externo real. Para configuración distinta de la del perfil
`test`, usar `@TestProfile` con `getConfigOverrides()`, no mutar `application.properties`.

Cada `@TestProfile` distinto fuerza un reinicio del contexto: agrupar los tests que comparten perfil.

## Convenciones

- Nombres `should[ComportamientoEsperado]`.
- `@DisplayName` en cada test, descripción breve y clara.
- Estructura Arrange / Act / Assert, con comentarios en pruebas complejas.
- Mocks explícitos: **prohibido** `new MiServicio(null, "bucket", "prefix")`.
- Accessors de record en las aserciones (`resultado.nombre()`), no getters.
- Cada rama de error del flujo reactivo necesita su propio test.

## Dependencias de test

`quarkus-junit5`, `quarkus-junit-mockito`, `quarkus-jacoco`, `assertj-core`, `mutiny-test`, `rest-assured`,
`wiremock-standalone`.

## Verificación del cumplimiento de seguridad

Si el servicio maneja datos sensibles, la suite debe incluir los tests de la skill `quarkus-logging-audit`:
enmascarado de PAN, ausencia de log injection, `toString()` que no expone tarjeta, y el script
`check-log-leaks.sh` sobre los logs de test en el pipeline.
