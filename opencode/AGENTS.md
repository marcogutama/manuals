# Reglas Globales

## Versiones de Java y Maven en esta máquina

Esta máquina Linux tiene varias versiones de Java y Maven instaladas. El switch se hace
con funciones definidas en `~/.bashrc`. Cuando un proyecto requiera una versión específica
de Java (revisa `pom.xml`, `.java-version`, `maven.compiler.release`, etc.), usa el
`JAVA_HOME` correspondiente antes de compilar o ejecutar Maven.

Rutas de instalación:

| Versión   | JAVA_HOME                                          |
|-----------|----------------------------------------------------|
| Java 8    | `/home/marco/Applications/openjdk1.8.0.412`        |
| Java 17   | `/home/marco/Applications/jdk-17.0.12`             |
| Java 21   | `/home/marco/Applications/graalvm-jdk-21.0.10+8.1` |
| Java 25   | `/home/marco/Applications/graalvm-jdk-25.0.3+9.1`  |

| Maven     | M2_HOME                                            |
|-----------|----------------------------------------------------|
| Maven 3.6 | `/home/marco/Applications/apache-maven-3.6.3`      |
| Maven 3.9 | `/home/marco/Applications/apache-maven-3.9.9`      |

Default de la máquina: Java 25 + Maven 3.9.

### Cómo cambiar de versión en un comando

Como cada comando de la herramienta corre en una shell no interactiva, las funciones
`setjava8/17/21/25` del `.bashrc` no están disponibles. Para forzar una versión, exporta
`JAVA_HOME` inline en el mismo comando. Ejemplos:

```bash
# Java 21 (ej. proyectos Quarkus como service-managementswift)
JAVA_HOME=/home/marco/Applications/graalvm-jdk-21.0.10+8.1 ./mvnw compile

# Java 17
JAVA_HOME=/home/marco/Applications/jdk-17.0.12 ./mvnw test

# Java 8 + Maven 3.6
JAVA_HOME=/home/marco/Applications/openjdk1.8.0.412 \
  /home/marco/Applications/apache-maven-3.6.3/bin/mvn package
```

Si el `pom.xml` declara `release`/`source`/`target` que no coincide con el `JAVA_HOME`
del entorno, pasa `-Dmaven.compiler.release=<versión>` para forzar el nivel correcto.
