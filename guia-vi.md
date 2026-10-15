# Guía rápida de vi

Vi funciona por **modos**. Cada tecla hace algo distinto según el modo en que estés.

> **Regla de oro:** si algo no funciona, presiona `Esc` dos veces y vuelve a intentar.

## Los 3 modos

| Modo | Para qué sirve | Cómo entrar | Cómo volver |
|---|---|---|---|
| **Normal** | Moverte, borrar, copiar, pegar | Es el modo por defecto | `Esc` desde cualquier modo |
| **Insert** | Escribir texto | `i`, `a`, `o` (desde Normal) | `Esc` |
| **Comando** | Guardar, salir, buscar, reemplazar | `:` (desde Normal) | `Enter` ejecuta, `Esc` cancela |

## Abrir un archivo

```bash
vi archivo.conf        # abrir (o crear) archivo
vi +42 archivo.conf    # abrir en la línea 42
vi -R archivo.conf     # abrir en solo lectura
vimtutor es            # tutorial interactivo (~30 min)
```

## Guardar y salir (desde modo Normal)

| Comando | Acción |
|---|---|
| `:w` | Guardar |
| `:q` | Salir (falla si hay cambios sin guardar) |
| `:wq` | Guardar y salir (siempre escribe) |
| `:x` o `ZZ` | Guardar solo si hubo cambios, y salir |
| `:x!` | Como `:x`, ignorando la opción `readonly` de vi |
| `:q!` | Salir sin guardar (descarta cambios) |
| `:w!` | Forzar guardado |
| `:w otro.txt` | Guardar copia con otro nombre |
| `:w !sudo tee %` | Guardar un archivo que abriste sin sudo |

> `:x!` no salta permisos reales del sistema de archivos. Si el archivo pertenece a root, usa `:w !sudo tee %`.

## Entrar a modo Insert (desde Normal)

| Tecla | Acción |
|---|---|
| `i` | Insertar antes del cursor |
| `a` | Insertar después del cursor |
| `I` | Insertar al inicio de la línea |
| `A` | Insertar al final de la línea |
| `o` | Nueva línea debajo |
| `O` | Nueva línea arriba |

## Moverse (modo Normal)

| Tecla | Acción |
|---|---|
| `h` `j` `k` `l` | Izquierda, abajo, arriba, derecha |
| `w` / `b` | Palabra siguiente / anterior |
| `e` | Final de la palabra |
| `0` / `$` | Inicio / final de línea |
| `^` | Primer carácter no vacío de la línea |
| `gg` / `G` | Inicio / final del archivo |
| `42G` o `:42` | Ir a la línea 42 |
| `Ctrl+f` / `Ctrl+b` | Página abajo / arriba |
| `Ctrl+d` / `Ctrl+u` | Media página abajo / arriba |
| `%` | Saltar al paréntesis o llave pareja |

## Editar (modo Normal)

| Tecla | Acción |
|---|---|
| `x` | Borrar carácter |
| `dd` | Cortar línea |
| `dw` | Borrar palabra |
| `D` | Borrar hasta el final de la línea |
| `cw` | Cambiar palabra (borra y entra a Insert) |
| `cc` | Cambiar línea completa |
| `r` + carácter | Reemplazar un carácter |
| `yy` | Copiar línea |
| `p` / `P` | Pegar después / antes |
| `u` | Deshacer |
| `Ctrl+r` | Rehacer |
| `.` | Repetir la última acción |
| `J` | Unir línea siguiente con la actual |
| `>>` / `<<` | Indentar / desindentar línea |

### Multiplicar con números

Casi todo acepta un número delante:

| Ejemplo | Acción |
|---|---|
| `3dd` | Borra 3 líneas |
| `5j` | Baja 5 líneas |
| `2dw` | Borra 2 palabras |
| `4yy` | Copia 4 líneas |
| `10x` | Borra 10 caracteres |

## Buscar y reemplazar

| Comando | Acción |
|---|---|
| `/texto` + `Enter` | Buscar hacia adelante |
| `?texto` + `Enter` | Buscar hacia atrás |
| `n` / `N` | Siguiente / anterior resultado |
| `*` | Buscar la palabra bajo el cursor |
| `:%s/viejo/nuevo/g` | Reemplazar en todo el archivo |
| `:%s/viejo/nuevo/gc` | Igual, pidiendo confirmación |
| `:s/viejo/nuevo/g` | Reemplazar solo en la línea actual |
| `:10,20s/viejo/nuevo/g` | Reemplazar entre las líneas 10 y 20 |
| `:noh` | Quitar el resaltado de la búsqueda |

## Selección visual (modo Normal)

| Tecla | Acción |
|---|---|
| `v` | Seleccionar por caracteres |
| `V` | Seleccionar líneas completas |
| `Ctrl+v` | Seleccionar por bloque (columnas) |

Con la selección activa: `d` corta, `y` copia, `>` indenta, `c` cambia, `~` alterna mayúsculas.

## Útiles en el día a día

| Comando | Acción |
|---|---|
| `:set number` | Mostrar números de línea |
| `:set nonumber` | Ocultar números de línea |
| `:set paste` | Evitar indentación rara al pegar texto |
| `:!comando` | Ejecutar un comando de shell (ej. `:!ls`) |
| `:r archivo` | Insertar el contenido de otro archivo |
| `:%d` | Borrar todo el contenido |
| `gg=G` | Reindentar todo el archivo |
| `:e!` | Recargar el archivo descartando cambios |

## Flujo típico en un servidor

1. `vi archivo.conf`
2. Busca lo que quieres editar con `/palabra` + `Enter`
3. Presiona `i` para insertar y escribe
4. Presiona `Esc`
5. Escribe `:wq` (o `:x`) y `Enter`

**Si te equivocaste:** `Esc`, luego `:q!` para salir sin guardar.

## Situaciones comunes

| Problema | Solución |
|---|---|
| "No puedo escribir nada" | Estás en modo Normal: presiona `i` |
| "Las teclas hacen cosas raras" | Estás en modo Normal: presiona `i` antes de escribir |
| "No puedo salir" | `Esc` y luego `:q!` |
| "Archivo de solo lectura" | `:w !sudo tee %` y luego `:q!` |
| "Pegué texto y se desordenó" | Antes de pegar usa `:set paste` |
| "Mensaje de archivo `.swp`" | Otro vi tiene abierto el archivo, o se cerró mal. Elige `(R)ecover` o `(D)elete` |

## Plan de práctica

1. Ejecuta `vimtutor es` y completa las lecciones 1 y 2.
2. Edita un archivo de configuración real (una copia de seguridad) usando solo vi, sin flechas ni mouse.
3. Practica `dd`, `yy`, `p`, `cw` y `:%s///g` hasta que salgan sin pensar.
