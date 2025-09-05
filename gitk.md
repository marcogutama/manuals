# Guía rápida: gitk desde terminal

## Uso básico

```bash
# Ver historial completo del repositorio
gitk

# Ver historial de todas las ramas
gitk --all

# Ver historial de una rama específica
gitk nombre_rama
```

## Historial de archivos específicos

```bash
# Ver historial de un archivo específico
gitk -- archivo.txt

# Ver historial de un archivo con seguimiento de renombres
gitk --follow -- archivo.txt

# Ver historial de múltiples archivos
gitk -- archivo1.txt archivo2.txt

# Ver historial de una carpeta específica
gitk -- carpeta/
```

## Filtros por rango

```bash
# Ver commits entre dos puntos
gitk commit1..commit2

# Ver historial de un archivo entre commits
gitk commit1..commit2 -- archivo.txt

# Ver últimos N commits
gitk -n 20
```

## Filtros por fecha y autor

```bash
# Ver commits desde una fecha
gitk --since="2024-01-01"

# Ver commits hasta una fecha
gitk --until="2024-12-31"

# Ver commits de un autor específico
gitk --author="nombre_autor"
```

## Combinaciones útiles

```bash
# Archivo específico con todas las ramas
gitk --all -- archivo.txt

# Historial de archivo en rama específica
gitk rama_especifica -- archivo.txt

# Ver cambios recientes en un archivo
gitk -n 10 --follow -- archivo.txt
```

## Navegación en gitk

- **Doble clic en commit**: Ver detalles del commit
- **Clic en archivo**: Ver diferencias del archivo
- **Ctrl+F**: Buscar en el historial
- **F5**: Refrescar vista