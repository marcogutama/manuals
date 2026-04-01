# Gemini CLI - Referencia de Comandos

## Gestión de Memoria

| Comando | Descripción |
|--------|-------------|
| `/memory refresh` | Refresca la memoria en caso de haber cambiado `gemini.md` |
| `/memory <instrucción>` | Agrega una instrucción al archivo `gemini.md` |

**Ejemplo:**
```
/memory usar mvn en vez del wrapper del project
```

---

## Gestión del Chat

| Comando | Descripción |
|--------|-------------|
| `/chat list` | Lista los chats guardados |
| `/chat save <tag>` | Guarda el chat actual con un tag |

**Ejemplo:**
```
/chat save project-tab
```

---

## Utilidades

| Comando | Descripción |
|--------|-------------|
| `/stats model` | Muestra estadísticas del modelo |
| `/compress` | Comprime todo el historial del chat a un contexto más pequeño |

---

## Comandos Personalizados

Los comandos personalizados se definen en `.gemini/commands/<nombre>.toml` y se invocan con `/<nombre>`.

**Ejemplo:** Para ejecutar el comando `component` definido en `.gemini/commands/component.toml`:
```
/component agregar un nuevo botón
```

---

## Shell Mode

Para habilitar el modo shell, usa el prefijo `!`:
```bash
! ls   # Lista los archivos del directorio actual
```

---

## Cancelar un Comando en Ejecución

Si un comando está procesando y deseas cancelarlo:

1. Presiona `Ctrl + F`
2. Luego presiona `Q`