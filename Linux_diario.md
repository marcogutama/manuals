# Comandos mas comunes linux

## Convertir archivo con formato DOS a Unix
- Opcion 1: dos2unix script.sh
- Opcion 2: sed -i 's/\r$//' script.sh
- Opcion 3 (vim): :set ff=unix
- Validar con: file script.sh

## Revision logs
### Less
```
sudo less /var/log/syslog
sudo grep "axentria" /var/log/syslog | less
```
Usa las teclas:
- Espacio: Para avanzar una página.
- B: Para retroceder una página.
- /texto: Buscar "texto" dentro del archivo (por ejemplo, /axentria).
- N: Ir a la siguiente coincidencia de búsqueda.
- Q: Salir del visor.

### Tail
Ver ultimas 10 lineas
```
sudo tail /var/log/syslog
```
Ver ultimas 50 lineas
```
sudo tail -n 50 /var/log/syslog
```
Monitoreo en tiempo real
```
sudo tail -f /var/log/syslog
```
Filtrar líneas con un patrón mientras monitoreas
```
sudo tail -f /var/log/syslog | grep "axentria"
```

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
:q: Salir (solo si no se han hecho cambios)
:q!: Salir sin guardar cambios (¡usa con cuidado!)
:set number: Mostrar números de línea
:set nonumber: Ocultar números de línea
/patron: Buscar un patrón
n: Buscar la siguiente coincidencia
N: Buscar la coincidencia anterior

### Consejos:

Escapar: Presiona la tecla Esc para salir del modo inserción y volver al modo normal.
Ayuda: :help o :help comando para obtener ayuda sobre un comando específico.