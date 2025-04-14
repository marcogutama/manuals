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