# Generar certificado digital para firmar documentos en Linux 

**1. Instalar OpenSSL (si no está instalado)**

En la mayoría de las distribuciones Linux, OpenSSL ya viene preinstalado. Si no lo tienes:
```
# Debian/Ubuntu
sudo apt install openssl
```
```
# Fedora/RHEL
sudo dnf install openssl
```

**2. Generar un certificado autofirmado**

Un certificado autofirmado (self-signed) es válido para uso personal o entornos internos, pero no está reconocido por autoridades externas (como los de empresas). Para crearlo:

**a. Generar clave privada (.key) y certificado (.crt)**

Ejecuta en la terminal:
```
openssl req -x509 -newkey rsa:4096 -keyout mi_clave_privada.key -out mi_certificado.crt -days 365
```
* Explicación del comando:
    * -x509: Indica que es un certificado autofirmado.
    * -newkey rsa:4096: Genera una clave RSA de 4096 bits (recomendado para seguridad).
    * -keyout: Ruta donde se guardará tu clave privada.
    * -out: Ruta donde se guardará el certificado público.
    * -days 365: Validez del certificado (1 año).

**c. Eliminar la contraseña de la clave (opcional)**

Si no quieres ingresar contraseña cada vez que uses el certificado:
```
openssl rsa -in mi_clave_privada.key -out mi_clave_sin_pass.key
```
**3. Convertir a formato PKCS#12 (.p12 o .pfx)**

Muchas aplicaciones requieren este formato (como Adobe Reader o Okular). Para crearlo:
```
openssl pkcs12 -export -inkey mi_clave_privada.key -in mi_certificado.crt -out certificado.p12
```

**4. Verificar el certificado (opcional)**

Para confirmar que todo se generó correctamente:
```
openssl pkcs12 -info -in certificado.p12
```
**5. Usar el certificado en Linux**

**En Okular (u otros visores de PDF):**

1. Importa el archivo certificado.p12 en el gestor de claves de tu sistema (p. ej., seahorse en GNOME).
2. Al firmar un PDF, selecciona el certificado desde Okular.

**JSignPdf:**
1. Ingresar
    * Keystore type: PKCS12
    * Keystore file: tu archivo .p12 
    * Keystore password: contraseña del certificado
2. Seleccionar archivo pdf y area donde firmar

**Notas importantes:**
* **Almacenamiento seguro:**
    * El archivo .key es tu clave **privada**. ¡No lo compartas!
    * El archivo .p12 contiene clave + certificado. Protégelo con contraseña.
* **Validez del certificado:**
    * Si usas -days 365, caducará en 1 año. Modifica el valor si necesitas más tiempo (ej: -days 3650 para 10 años).
* **Limitaciones de certificados autofirmados:**
    * No serán reconocidos como "confiables" por terceros (solo sirven para uso personal).
