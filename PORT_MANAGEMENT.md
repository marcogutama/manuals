# Gestión de Puertos - Microservicios

Este documento establece la estrategia de asignación de puertos para el desarrollo local de microservicios, asegurando que no existan conflictos al levantar múltiples servicios simultáneamente.

## Estrategia de Asignación (Rangos Semánticos)

Para mantener el orden, los puertos se asignan según la capa arquitectónica del microservicio:

| Rango | Tipo de Servicio | Descripción |
| :--- | :--- | :--- |
| **80xx** | Simuladores / Workers | Servicios de apoyo o procesos en segundo plano. |
| **15xxx** | Core / Utility Services | Servicios básicos y de utilidad (Buro, Catálogos, Tokens). |
| **16xxx** | Business Domain Services | Servicios con lógica de dominio de negocio. |
| **17xxx** | Aggregators / GraphQL | Capas de agregación de datos y APIs GraphQL. |
| **18xxx** | Adapters / Integrators | Integraciones con sistemas externos o legacy. |
| **28xxx** | Orchestrators (L1) | Orquestadores de servicios core. |
| **29xxx** | Orchestrators (L2 / BFF) | Orquestadores de alto nivel para canales. |

---

## Inventario de Puertos Actual

| Microservicio | Puerto Local | Tipo |
| :--- | :---: | :--- |
| **anyway-simulator** | **8081** | Simulador |
| **dispatch-notification** | **8083** | Worker |
| **sms-delivery** | **8084** | Worker |
| **whatsapp-delivery** | **8085** | Worker |
| **email-delivery** | **8090** | Worker |
| **service-notificador** | **15025** | Utility |
| **fusenotificador** | **15040** | Utility |
| **servicioburo** | **15050** | Core |
| **serviciopersonasnaturales** | **15060** | Core |
| **serviciolistascontrol** | **15075** | Core |
| **servicedatalopdp** | **15080** | Core |
| **serviciocatalogos** | **15080** | Core (**Conflicto!**) |
| **serviciogestiondocumental** | **15085** | Core |
| **notification-hub-persistence** | **15090** | Core |
| **service-document-producer** | **15100** | Core |
| **service-document-consumer** | **15200** | Core |
| **servicemanagetoken** | **15867** | Core |
| **serviceproducts** | **16020** | Domain |
| **servicioregistrocivilonline** | **16020** | Domain (**Conflicto!**) |
| **fusecustomerinfographql** | **17000** | GraphQL |
| **channel-corebank-integrator** | **18002** | Integrator |
| **documentobjectstorage** | **18002** | Adapter (**Conflicto!**) |
| **svc-swifttrf-gqlorch** | **18002** | Integrator (**Conflicto!**) |
| **custmgt-documentaxentria** | **18300** | Adapter |
| **channelpartyauthorch** | **28083** | Orchestrator |
| **customermanagement-adapter** | **28088** | Adapter |
| **complaincevalidation-orchestrator** | **28089** | Orchestrator |
| **extcompsrvprovops** | **28092** | Orchestrator |
| **servicing-appsecuritymgmt** | **28093** | Orchestrator |
| **notification-flow-orchestrator** | **28095** | Orchestrator |
| **channelpartyonboardingorch** | **29080** | Orchestrator |
| **accountdatamgmtorch** | **29083** | Orchestrator |

---

## Lineamientos para Nuevos Microservicios

1. **Consultar este archivo** antes de asignar un puerto.
2. **Asignar un puerto libre** dentro del rango correspondiente a su tipo.
3. **Usar perfiles de Quarkus** para configuraciones locales si es posible:
   - `%dev.quarkus.http.port=XXXXX`
4. **Actualizar este inventario** inmediatamente después de la creación del servicio.

> **Nota sobre OpenShift:** En el despliegue de OpenShift, los servicios suelen usar el puerto 8080 internamente. Estas asignaciones son estrictamente para facilitar el **desarrollo y pruebas locales**.

En caso de asignar un nuevo puerto a un microservicio, el puerto asignado debe registrarse en este archivo para mantener actualizado el inventario.
