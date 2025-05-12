## Resumen comandos docker

### **Configuración y uso de Docker**
**`sudo dnf install docker -y`**: Instala Docker utilizando el gestor de paquetes `dnf`.
**`sudo systemctl start docker`**: Inicia el servicio de Docker.
**`sudo systemctl enable docker`**: Configura Docker para que se inicie automáticamente al arrancar el sistema.
**`sudo usermod -aG docker $USER`**: Agrega al usuario al grupo Docker para ejecutar comandos sin sudo.
**`newgrp docker`**: Actualiza la sesión para aplicar los cambios del grupo.

### **Gestión de contenedores**
**`docker pull nginx`**: Descarga la imagen oficial de Nginx desde Docker Hub.
**`docker run -dp 80:80 nginx`**: Crea y ejecuta un contenedor basado en la imagen Nginx, mapeando el puerto 80 del host al puerto 80 del contenedor.
**`docker ps`**: Muestra los contenedores en ejecución.
**`docker ps -a`**: Lista todos los contenedores, incluidos los detenidos.
**`docker rm fe 1d`**: Elimina un contenedor específico con los IDs `fe` y `1d`.
**`docker images`**: Muestra las imágenes disponibles localmente.

### **Construcción de imágenes personalizadas**
**`docker build -t 2048 .`**: Crea una imagen llamada `2048` basada en el contexto del directorio actual.
**`docker run -dp 80:80 2048`**: Ejecuta un contenedor basado en la imagen `2048` y mapea el puerto 80 del host al contenedor.

### **Carga y gestión de imágenes**
**`docker tag 2048:latest mgutama/2048`**: Etiqueta la imagen `2048` para prepararla para su subida a Docker Hub.
**`docker push mgutama/2048`**: Sube la imagen etiquetada `mgutama/2048` a Docker Hub.

### **Eliminación de imágenes y contenedores**
**`docker rmi mgutama/2048`**: Elimina la imagen `mgutama/2048` localmente.
**`docker rmi 2048`**: Elimina la imagen `2048` localmente.
**docker rmi $(docker images -q) --force**: elimina todas las imagenes

### **Docker Compose**
**docker-compose build client**
**`docker-compose up -d`**: Levanta los servicios definidos en el archivo docker-compose.yml en modo detached (en segundo plano).
**`docker-compose down`**: Detiene y elimina todos los contenedores, redes y volúmenes creados por `docker-compose up`.