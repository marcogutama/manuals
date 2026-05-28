# Guía: Corrección de Saltos de Línea en Archivos Properties
**Microservicios Quarkus — OpenShift ConfigMaps**

---

## 1. El Problema

Cuando el archivo `application.properties` tiene saltos de línea en formato Windows (**CRLF**), al desplegar el microservicio en OpenShift el ConfigMap almacena el contenido como un string escapado en una sola línea:

**❌ Formato INCORRECTO (CRLF) — se ve en una sola línea al editar el ConfigMap:**
```yaml
data:
  service.properties: "# ORQUESTADOR DE ONBOARDING\r\nquarkus.application.name=...\r\n..."
```
> Los caracteres `\r\n` son los saltos de línea Windows escapados.

**✅ Formato CORRECTO (LF) — se ve multilínea al editar el ConfigMap:**
```yaml
data:
  service.properties: |
    # ORQUESTADOR DE ONBOARDING
    quarkus.application.name=...
    ...
```
> El operador `|` (bloque literal YAML) preserva los saltos de línea reales.

---

## 2. Diagnóstico: Verificar si el archivo tiene CRLF

Ejecutar en la terminal desde la raíz del proyecto:

```bash
cat -A src/main/resources/application.properties | head -5
```

**Interpretar el resultado:**

| Salida del comando | Interpretación |
|---|---|
| `# CONFIGURACION^M$` | Tiene `^M` = CRLF ❌ **HAY QUE CORREGIR** |
| `# CONFIGURACION$` | Solo `$` = LF ✅ **CORRECTO** |

---

## 3. Corrección del Archivo

### Paso 1 — Convertir CRLF a LF

Ejecutar en la raíz del proyecto Quarkus:

```bash
sed -i 's/\r//' src/main/resources/application.properties
```

Verificar que quedó correcto:

```bash
cat -A src/main/resources/application.properties | head -5
```

Ahora debe mostrar solo `$` al final de cada línea, **sin `^M`**.

---

### Paso 2 — Configurar IntelliJ IDEA

Para evitar que IntelliJ vuelva a guardar con CRLF:

1. Ir a: `File → Settings → Editor → Code Style`
2. Buscar: **Line separator**
3. Seleccionar: **Unix and macOS (`\n`)**
4. Aplicar y guardar

También agregar un archivo `.editorconfig` en la raíz del proyecto:

```ini
# .editorconfig
root = true

[*]
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

---

### Paso 3 — Configurar Git con `.gitattributes`

Crear o editar el archivo `.gitattributes` en la raíz del repositorio:

```gitattributes
# .gitattributes
* text=auto eol=lf
*.properties text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
```

Esto garantiza que Git siempre versione con LF sin importar el sistema operativo del desarrollador.

---

### Paso 4 — Aplicar cambios a archivos ya versionados

Si ya había archivos con CRLF en el repositorio, normalizarlos:

```bash
git add --renormalize .
git commit -m "fix: normalize line endings to LF"
git push
```

---

## 4. Resumen del Flujo Correcto

| # | Etapa | Resultado |
|---|---|---|
| 1 | IntelliJ guarda con LF | Archivo `.properties` sin `^M` |
| 2 | Git versiona con LF (`.gitattributes`) | Repositorio limpio de CRLF |
| 3 | OpenShift crea ConfigMap | Formato bloque literal `\|` (multilínea) |
| 4 | Edición en consola OpenShift | Se ve multilínea y legible |

---

> **Nota:** Esta corrección es solo de formato, no afecta el funcionamiento del microservicio.
> El ConfigMap con CRLF y el ConfigMap con LF son funcionalmente idénticos para Quarkus.
> La ventaja del LF es que el YAML queda legible y editable directamente en la consola de OpenShift.

---

*Equipo de Desarrollo — Microservicios Quarkus / OpenShift*
