# Comandos mas comunes linux

## Convertir archivo con formato DOS a Unix
- Opcion 1: dos2unix script.sh
- Opcion 2: sed -i 's/\r$//' script.sh
- Opcion 3 (vim): :set ff=unix
- Validar con: file script.sh

## Comandos mas comunes vim

### Para cortar varias lineas
- v modo visual linea
- Usa las teclas de movimiento (j para bajar o k para subir) para seleccionar las líneas deseadas.
- y copiar
- p pegar

### Deshacer cambios
- esc
- u: Deshacer el último cambio.
- Ctrl+r: Rehacer un cambio deshecho.

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