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
----
## tar files

### Descomprimir

```bash
tar -xzf geminicommit-v0.2.6-linux-amd64.tar.gz
```

Donde:
- `-x`: indica extraer
- `-z`: indica descomprimir con gzip
- `-f`: indica que se especificará un archivo

Si deseas extraer en una carpeta específica, puedes añadir la opción `-C` seguida de la ruta:

```bash
tar -xzf geminicommit-v0.2.6-linux-amd64.tar.gz -C /ruta/destino
```
