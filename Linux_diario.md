# Comandos mas comunes linux

## Convertir archivo con formato DOS a Unix
Opcion 1: dos2unix script.sh
Opcion 2: sed -i 's/\r$//' script.sh
Opcion 3 (vim): :set ff=unix
Validar con: file script.sh