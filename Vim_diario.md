## Comandos basicos vim
### Navegación:

h: Izquierda
j: Abajo
k: Arriba
l: Derecha
w: Palabra siguiente
b: Palabra anterior
e: Final de la palabra
0 (cero): Inicio de la línea
$: Final de la línea
gg: Ir al inicio del archivo
G: Ir al final del archivo
Ngg: Ir a la línea N (ej: 10gg va a la línea 10)
N%: Ir al porcentaje N del archivo

### Edición:

i: Insertar texto (antes del cursor)
a: Insertar texto (después del cursor)
o: Abrir una nueva línea debajo y entrar en modo inserción
O: Abrir una nueva línea arriba y entrar en modo inserción
x: Borrar el carácter bajo el cursor
dd: Cortar la línea actual
yy: Copiar la línea actual
yw: Copiar una palabra
p: Pegar después del cursor
P: Pegar antes del cursor
u: Deshacer
Ctrl+r: Rehacer
:: Entrar en modo comando (para comandos como guardar, salir, etc.)

### Comandos en modo comando (después de :):

:w: Guardar el archivo
:w nombre_archivo.txt: Guardar con un nombre diferente
:wq: Guardar y salir
:x Guardar y salir
:q: Salir (solo si no se han hecho cambios)
:q!: Salir sin guardar cambios (¡usa con cuidado!)
:set number: Mostrar números de línea
:set nonumber: Ocultar números de línea
/patron: Buscar un patrón
n: Buscar la siguiente coincidencia
N: Buscar la coincidencia anterior
:%d Borrar todo el contenido del archivo

### Consejos:

Escapar: Presiona la tecla Esc para salir del modo inserción y volver al modo normal.
Ayuda: :help o :help comando para obtener ayuda sobre un comando específico.

---

### Copiar varias lineas de texto y pegar
En Vim, copiar se conoce como **"yank"** (por eso se usa la letra `y`) y pegar se conoce como **"put"** (letra `p`).

Tienes tres formas clásicas de hacerlo, desde la más fácil hasta la más precisa. Elige la que mejor se adapte a lo que necesitas en el momento:

---

### Método 1: El modo Visual (El más intuitivo)

Es el equivalente a seleccionar texto con el mouse.

1. Coloca el cursor al inicio de la primera línea que quieres copiar.
2. Presiona **`V`** (letra V mayúscula) para entrar en el modo **Visual Línea**. Verás que se selecciona toda la línea actual.
3. Muévete hacia abajo con las flechas o la tecla `j` hasta seleccionar todas las líneas que quieres.
4. Presiona **`y`** para copiar (el resaltado desaparecerá).
5. Ve a donde quieres pegar el texto y presiona **`p`** (minúscula) para pegarlo **debajo** de la línea actual, o **`P`** (mayúscula) para pegarlo **arriba**.

---

### Método 2: Usando un contador (El más rápido)

Si sabes exactamente cuántas líneas quieres copiar, no necesitas seleccionarlas visualmente.

1. Coloca el cursor en la primera línea que quieres copiar.
2. Escribe **`[Número]yy`**. Por ejemplo, para copiar 5 líneas escribes: **`5yy`**.
3. Ve a donde quieres pegar y presiona **`p`**.

---

### Método 3: La línea de comandos (Para distancias largas)

Si quieres copiar un bloque que está muy lejos de donde estás editando, puedes usar los comandos de la parte inferior (`:`).

1. Escribe `:` seguido del rango de líneas y la letra `t` (que significa *to* o copiar en modo comando), y luego el número de línea **debajo de la cual** quieres pegar.

> **Ejemplo:** `:10,15t20`
> Esto toma las líneas de la 10 a la 15, las copia y las pega justo **debajo** de la línea 20.

---

**Tip extra:** Si te equivocas de líneas al pegar, solo presiona **`u`** en modo normal para deshacer el cambio (*undo*).