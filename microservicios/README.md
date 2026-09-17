# Estándar de Microservicios

Estándar de ingeniería para microservicios Quarkus reactivos. Java 25 · Mutiny · MicroProfile · Jakarta EE ·
despliegue en OpenShift.

**Empieza por [flujo-trabajo-ia.md](flujo-trabajo-ia.md)** si es tu primera vez: explica cómo
encajan estos documentos con las skills y el subagente de revisión, y cómo arrancar un microservicio nuevo.

## Documentos

| Documento | Rol | Cuándo consultarlo |
|---|---|---|
| [flujo-trabajo-ia.md](flujo-trabajo-ia.md) | Guía del flujo de trabajo con IA | Al empezar, o al dudar de qué archivo hace qué |
| [microservices-ai-rules.md](microservices-ai-rules.md) | Norma canónica (~3200 líneas) | Referencia; para el detalle de una regla concreta |
| [RESPONSE_CODES.md](RESPONSE_CODES.md) | Catálogo maestro de `codRespuesta` | Antes de definir cualquier código de negocio |
| [PORT_MANAGEMENT.md](PORT_MANAGEMENT.md) | Inventario de puertos locales | Al crear un servicio; **actualizar en el mismo PR** |
| [AGENTS.template.md](AGENTS.template.md) | Plantilla de `AGENTS.md` | Al crear un repositorio nuevo |

La norma es extensa a propósito: sirve de referencia consultable. **No se carga entera en una sesión de IA** —
para eso están las skills en [`../opencode/skills/`](../opencode/skills/), que contienen las reglas accionables
por dominio.

## Requisitos de seguridad

Las secciones **17**, **18.9** y **18.10** de la norma son requisitos del departamento de seguridad y no
admiten excepción por conveniencia técnica ni por plazo de entrega:

- Los logs permiten trazar las acciones de los usuarios (**quién**, qué, desde dónde, cuándo, con qué resultado).
- Los logs **no almacenan** información confidencial de tarjetas.
- Se cumple la estructura estándar de log:
  ```
  [fecha/hora] [tipo de evento] [sesión – IP – usuario] Descripción del evento, resultado del evento
  ```

## Herramientas asociadas

En [`../opencode/`](../opencode/):

- **Skills**: `quarkus-microservice-scaffold`, `quarkus-logging-audit`, `quarkus-rest-contract`,
  `quarkus-resilience`, `quarkus-testing`. Se cargan automáticamente según el tema del trabajo.
- **Subagente** `quarkus-reviewer`: revisa un cambio contra el estándar antes del PR. Solo lectura.

## Mantener actualizado

Al añadir una regla, evaluar primero si es **automatizable** (ArchUnit, SpotBugs, `jacoco:check`, script de
CI). Si lo es, va a la sección 27 de la norma y al pipeline: una regla ejecutable se cumple siempre; una regla
en Markdown se cumple cuando alguien la recuerda.

El procedimiento completo está en la sección 7 de
[flujo-trabajo-ia.md](flujo-trabajo-ia.md#7-mantenimiento).
