# Comandos mas comunes linux

## Convertir archivo con formato DOS a Unix
Opcion 1: dos2unix script.sh
Opcion 2: sed -i 's/\r$//' script.sh
Opcion 3 (vim): :set ff=unix
Validar con: file script.sh

# Comandos mas comunes vim

## Para cortar varias lineas
v modo visual linea
Usa las teclas de movimiento (j para bajar o k para subir) para seleccionar las líneas deseadas.
d
p

## Deshacer cambios
esc
u: Deshacer el último cambio.
Ctrl+r: Rehacer un cambio deshecho.