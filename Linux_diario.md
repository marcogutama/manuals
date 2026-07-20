# Comandos mas comunes linux

## Buscar un archivo en linux
find . -name "FFCAddTurnCondition.java"
find . -type f -name "*.properties"  ->-type f: Indica que solo quieres buscar archivos (no directorios u otros tipos de archivos).
find . -type f -name "*test*"

## Convertir archivo con formato DOS a Unix
- Opcion 1: dos2unix script.sh
- Opcion 2: sed -i 's/\r$//' script.sh
- Opcion 3 (vim): :set ff=unix
- Validar con: file script.sh

## Renombrar carpeta
mv "manuals baustro" manuals_baustro
mv manuals\ baustro manuals_baustro

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

## Validar conectividad a una IP y puerto específico 
```
telnet <ip_address> <port>
nc -zv <ip_address> <port>
curl -v telnet://<ip_address>:<port>
```

## Obtener ip publica 
curl ifconfig.me

## Curl
### Get Request simple
curl https://jsonplaceholder.typicode.com/posts/1

### Get Request con cabeceras (headers)
curl -H "Accept: application/json" https://jsonplaceholder.typicode.com/posts/1

### Post Request con datos en x-www-form-urlencoded
curl -X POST -d "username=juan&password=1234" https://httpbin.org/post

### Post Request con JSON
curl -X POST -H "Content-Type: application/json" \
    -d '{"nombre":"Juan", "edad":30}' \
    https://httpbin.org/post

## Descargar archivos
wget https://ejemplo.com/archivo.zip
wget -c https://ejemplo.com/archivo.zip  # c: soporta reanudación
wget -O mi_archivo.zip https://ejemplo.com/archivo.zip # Si quieres cambiar el nombre del archivo descargado

curl -O https://ejemplo.com/archivo.zip # Guarda el archivo con el nombre original del servidor
curl -o mi_archivo.zip https://ejemplo.com/archivo.zip # Para guardarlo con un nombre personalizado
Sin las opciones -O o -o, curl imprimirá el contenido del archivo directamente en la terminal (stdout)

## Identificar qué proceso está usando un puerto (ej. 8585)
sudo lsof -i :8585

## Ejecutar telnet en un contenedor si herramientas (sin instalar nada)

En Linux puro, puedes usar **`/dev/tcp`** que es una funcionalidad nativa del shell (bash):

### ✅ Opción 1 — `/dev/tcp` (la más simple)
```bash
bash -c "echo > /dev/tcp/10.16.191.33/8444" && echo "ABIERTO" || echo "CERRADO/FILTRADO"
```
### Opcion para mapear todos los puertos accesibles a un servidor
seq 1 65535 | xargs -P 50 -I{} bash -c \
  'timeout 1 bash -c "echo > /dev/tcp/10.1.99.43/{}" 2>/dev/null && echo "Puerto {}: ABIERTO"'

O con timeout para no quedarte esperando:
```bash
timeout 3 bash -c "echo > /dev/tcp/10.16.191.33/8444" && echo "Puerto ABIERTO" || echo "Puerto CERRADO o TIMEOUT"
```

### ✅ Opción 2 — Con más detalle usando `/dev/tcp`
```bash
(echo >/dev/tcp/10.16.191.33/8444) 2>/dev/null \
  && echo "CONECTADO: puerto 8444 accesible" \
  || echo "FALLO: puerto 8444 no accesible"
```

### ✅ Opción 3 — Si el contenedor tiene `curl`
```bash
curl -v telnet://10.16.191.33:8444 --connect-timeout 5
```

### ✅ Opción 4 — Si el contenedor tiene `wget`
```bash
wget -q --spider --timeout=5 http://10.16.191.33:8444 2>&1 | head -5
```

---

## Recomendación

La **Opción 1 con `/dev/tcp`** es la más directa porque solo depende de `bash`, que siempre está presente. Si el contenedor usa `sh` (dash/ash en vez de bash), puede que no funcione — en ese caso prueba llamando `bash` explícitamente como se muestra arriba.

---

## Generar uuid
| Método / Comando                   | Bytes | Bits | Formato                | Ejemplo de salida                                                  | Uso típico                                                |
| ---------------------------------- | ----- | ---- | ---------------------- | ------------------------------------------------------------------ | --------------------------------------------------------- |
| `uuidgen`                          | 16    | 128  | UUID (hex con guiones) | `550e8400-e29b-41d4-a716-446655440000`                             | Identificadores únicos, correlación                       |
| `cat /proc/sys/kernel/random/uuid` | 16    | 128  | UUID (hex con guiones) | `123e4567-e89b-12d3-a456-426614174000`                             | Alternativa a `uuidgen`                                   |
| `openssl rand -hex 16`             | 16    | 128  | Hexadecimal            | `9f1c2e7a4b8d6c3e5f9a1b2c3d4e5f6a`                                 | API keys simples                                          |
| `openssl rand -hex 32`             | 32    | 256  | Hexadecimal            | `a3f9c2e7b4d8c6e1f0a9b2c3d4e5f6a7c8d9e0f1a2b3c4d5e6f7a8b9c0d1e2f3` | API keys seguras                                          |
| `openssl rand -base64 32`          | 32    | 256  | Base64                 | `q83Jk2l9ZkP1v8sL0xYwTQeR7uH3aB6c9dEfGhIjKlM=`                     | Tokens seguros (requiere manejo de caracteres especiales) |


## Usar otra version de java
```bash
export JAVA_HOME=/path/to/java-17
export PATH=$JAVA_HOME/bin:$PATH
mvn clean install
```
---

## Codificación (encriptado) en base64:

Para codificar texto en base64:

```bash
echo "texto a codificar" | base64
```

Para codificar el contenido de un archivo:

```bash
base64 archivo.txt > archivo_codificado.txt
```

## Decodificación (desencriptado) de base64:

Para decodificar texto en base64:

```bash
echo "dGV4dG8gYSBjb2RpZmljYXI=" | base64 -d
```

Para decodificar un archivo:

```bash
base64 -d archivo_codificado.txt > archivo_decodificado.txt
```

## Encriptación con OpenSSL y base64:

Si quieres una verdadera encriptación (ya que base64 es solo codificación, no encriptación), puedes combinar OpenSSL con base64:

Para encriptar y codificar:

```bash
echo "texto secreto" | openssl enc -aes-256-cbc -a -salt -pass pass:tucontraseña
```

Para desencriptar:

```bash
echo "U2FsdGVkX1+AbCdEfG..." | openssl enc -aes-256-cbc -d -a -salt -pass pass:tucontraseña
```

Recuerda que base64 por sí mismo no es una forma de encriptación segura, sino solo una codificación que puede ser fácilmente revertida. Para una verdadera seguridad, debes usar algoritmos de encriptación como los que proporciona OpenSSL.


---
## Copiar archivos entre servidores

### Método 1: Usando `scp` (El método clásico)

La sintaxis básica de `scp` funciona igual que el comando `cp` tradicional, pero añadiendo los datos de conexión SSH (`usuario@servidor:`).

#### Caso A: Estás en el Servidor A y quieres enviar un archivo al Servidor B

```bash
scp /ruta/archivo.txt usuario_B@ip_servidor_B:/ruta/destino/
```

#### Caso B: Estás en el Servidor B y quieres traer un archivo desde el Servidor A

```bash
scp usuario_A@ip_servidor_A:/ruta/archivo.txt /ruta/destino/local/
```

#### ¿Y si es una carpeta completa?

Solo debes agregar la opción **`-r`** (recursivo):

```bash
scp -r /ruta/carpeta/ usuario_B@ip_servidor_B:/ruta/destino/
```
