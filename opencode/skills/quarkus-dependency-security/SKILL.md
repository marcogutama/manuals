---
name: quarkus-dependency-security
description: Detecta y corrige vulnerabilidades de dependencias (CVEs transitivos de Quarkus, CXF, Netty, Jackson, etc.) con `snyk test` antes de hacer push, para no depender únicamente del pipeline de GitLab. Cubre cuándo correr el escaneo, cómo priorizar entre upgrade directo y forzar una versión transitiva vía dependencyManagement/BOM, y cómo verificar que el fix no rompe el build. Úsalo cuando se actualice una versión en pom.xml (Quarkus, una extensión, o cualquier dependencia), antes de cerrar un cambio que toque el pom, o cuando el usuario reporte vulnerabilidades o pida correr snyk.
---

# Seguridad de Dependencias — Quarkus

El pipeline de GitLab (`validate-vulnerabilities`) ya escanea vulnerabilidades en cada push. **No lo
sustituye ni lo duplica esta skill**: el objetivo aquí es detectar y corregir *antes* del push, para no
gastar un ciclo de pipeline en algo que se resuelve localmente en segundos. No se modifica `.gitlab-ci.yml`
para esto.

## Cuándo correr `snyk test`

- Después de cualquier cambio de versión en `pom.xml` (Quarkus platform, `quarkus-cxf`, o cualquier
  extensión o dependencia directa).
- Antes de cerrar un PR/commit que tocó el `pom.xml`, aunque el cambio no haya sido motivado por seguridad
  (subir Quarkus por una feature nueva también arrastra transitivas).
- Cuando el usuario reporta vulnerabilidades detectadas por su cuenta o pide "corregir vulnerabilidades" /
  "correr snyk".

No es necesario correrlo en cada commit del día a día que no toca dependencias.

## Comando

```bash
cd CodigoFuente
snyk test
```

Requiere sesión autenticada (`snyk auth`) hecha una vez por el desarrollador; no se gestiona por proyecto ni
se mete el token en el repositorio.

## Cómo leer la salida y priorizar el fix

Snyk separa los hallazgos en dos grupos. El orden de intento es siempre el mismo:

### 1. "Upgrade X to Y" — hay un fix directo

Es el caso simple: subir la versión de la dependencia (normalmente la extensión de Quarkus, no la
transitiva) resuelve la cadena completa.

```
Upgrade io.quarkiverse.cxf:quarkus-cxf@3.38.0 to io.quarkiverse.cxf:quarkus-cxf@3.39.0 to fix
✗ XML External Entity (XXE) Injection ... in org.apache.cxf:cxf-rt-wsdl@4.2.2
```

Acción: subir la propiedad de versión en `pom.xml` (ej. `<quarkus-cxf.version>`), no fijar la transitiva
a mano. Un BOM/extensión coordina un conjunto de versiones compatibles entre sí; forzar solo la hoja del
árbol sin subir el padre puede introducir incompatibilidades binarias que el BOM ya resolvió.

### 2. "Issues with no direct upgrade or patch" — hay que forzar la transitiva

Cuando ni siquiera el upgrade del padre resuelve porque el BOM sigue fijando una versión vulnerable de la
transitiva:

```
✗ Allocation of Resources Without Limits or Throttling ... in org.apache.neethi:neethi@3.2.2
  This issue was fixed in versions: 3.2.3
```

Acción: forzar la versión de la transitiva en `dependencyManagement`, **sin quitar el BOM** (el
`dependencyManagement` del propio proyecto tiene precedencia sobre el de un BOM importado más arriba en el
mismo `pom.xml`):

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>${quarkus.platform.group-id}</groupId>
            <artifactId>${quarkus.platform.artifact-id}</artifactId>
            <version>${quarkus.platform.version}</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <!-- Fuerza neethi por encima de lo que trae el BOM de quarkus-cxf: 3.2.2 tiene N CVEs de DoS
             (Snyk SNYK-JAVA-...), corregidos en 3.2.3. -->
        <dependency>
            <groupId>org.apache.neethi</groupId>
            <artifactId>neethi</artifactId>
            <version>${neethi.version}</version>
        </dependency>
    </dependencies>
</dependencyManagement>
```

Comentario obligatorio con el ID de Snyk y el motivo: sin él, un año después nadie sabe por qué esa
dependencia transitiva está fijada a mano y alguien la "limpia" reintroduciendo el CVE.

Verificar con `mvn dependency:tree -Dincludes=<groupId>` que la versión forzada es la que realmente se
resuelve en el árbol (un `dependencyManagement` mal ubicado, o una dependencia directa que ya fija su propia
versión, puede ignorar el override).

## Después de aplicar el fix

1. `snyk test` de nuevo — confirmar 0 vulnerabilidades o al menos que las corregidas ya no aparecen.
2. `./mvnw verify` — el gate de cobertura y los tests no deben romperse por el upgrade. Un salto de versión de
   extensión puede relocar artifactIds (ej. `quarkus-junit5-mockito` → `quarkus-junit-mockito` desde Quarkus
   3.31) o cambiar comportamiento por defecto; revisar los warnings del build, no solo el resultado final.
3. Si el proyecto empaqueta nativo, un `./mvnw package -Dnative` de verificación cuando el upgrade toca una
   extensión con soporte nativo delicado (CXF/JAXB es el caso típico de este ecosistema): un CVE corregido que
   rompe el build nativo no es un fix aceptable sin evaluar alternativas.

## Qué no hacer

- No bajar el umbral de severidad de Snyk ni ignorar el hallazgo (`.snyk` ignore policy) como primera opción.
  Es el equivalente a bajar el umbral de JaCoCo: convierte el control en decorativo. Se usa solo si el equipo
  de seguridad aprueba explícitamente una excepción documentada con fecha de revisión.
- No fijar una transitiva a una versión **inferior** a la que ya resuelve el BOM para "probar algo distinto".
  Si Snyk no ofrece upgrade directo, es porque ninguna versión posterior del padre lo arregla todavía; forzar
  hacia abajo no ayuda.
- No mezclar en el mismo commit un upgrade de seguridad con cambios de feature no relacionados: dificulta
  revertir el upgrade aislado si algo falla en producción.
