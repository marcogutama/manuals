# Comandos Git - Guía de Referencia

## 🔧 Configuración inicial

### Setup básico
```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu.email@ejemplo.com"
git config --global core.editor "nano"  # o vim, emacs, etc.
git config --global color.ui auto
```

### Herramienta de comparación visual
```bash
git config --global diff.tool meld
git config --global difftool.prompt false
```

### Credenciales
```bash
git config --global credential.helper store     # Guarda en ~/.git-credentials
git config --global --unset credential.helper   # Limpiar credenciales guardadas
```

### Alias útiles
```bash
git config --global alias.sw switch
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
```

### Verificar configuración
```bash
git config --list
git config --list --global
```

---

## 🚀 Estado del repositorio

```bash
git status          # Estado completo
git status -s       # Estado resumido
```

---

## 📁 Manejo de archivos

### Buscar archivos rastreados
```bash
git ls-files "*.properties"
git ls-files "*test*"
```

### Preparar cambios (Stage)
```bash
git add <archivo>   # Preparar un archivo específico
git add .           # Preparar cambios del directorio actual hacia abajo
git add -A          # Preparar TODO el repositorio (independiente de la carpeta actual)
git add :/          # Preparar TODO desde la raíz del proyecto
git add -u          # Preparar solo archivos ya rastreados (no incluye archivos nuevos sin rastrear)
```

### Quitar del stage (Unstage)
```bash
git restore --staged <archivo>  # Quitar un archivo específico del stage (Git >= 2.23, recomendado)
git restore --staged .          # Quitar todo el directorio actual del stage
git reset <archivo>             # Alternativa tradicional (Git < 2.23)
git reset :/                    # Alternativa tradicional: quitar todo el repositorio del stage
```

### Descartar cambios no confirmados
```bash
git restore <archivo>       # Descartar cambios de un archivo específico
git reset --hard HEAD       # Descartar TODOS los cambios (working tree + stage)
git clean -fd               # Eliminar archivos y carpetas nuevos sin rastrear
```

---

## 💾 Stash (cambios temporales)

### Operaciones básicas
```bash
git stash                   # Guardar cambios temporalmente
git stash pop               # Restaurar el último stash y eliminarlo
git stash apply             # Aplicar el último stash sin eliminarlo
```

### Gestión avanzada
```bash
git stash list                  # Listar todos los stashes guardados
git stash show stash@{0}        # Resumen de archivos del stash más reciente
git stash show -p stash@{0}     # Ver los cambios detallados del stash más reciente
git stash drop stash@{0}        # Eliminar un stash específico
git stash clear                 # Eliminar TODOS los stashes
```

---

## 📜 Historial y logs

### Ver historial
```bash
git log --oneline --graph
git log --oneline --name-only                   # Muestra el ID del commit, el título y justo debajo la lista de archivos
git log --oneline --name-status                 # Que archivo se tocó, y qué se le hizo (M = Modificado, A = Añadido, D = Eliminado)
git log --name-only                             # Si necesitas saber quién lo hizo y cuándo, pero manteniendo solo la lista de archivos
git log --follow <archivo>                      # Sigue renombres/movimientos del archivo
git log --author="nombre_autor"
git log --author="nombre" --pretty=format:"%h - %s"
git log --since="2024-01-01" --until="2024-12-31"
git log <rama>                                  # Commits de una rama específica
git log <rama> --grep="filtro"                  # Filtrar commits por texto
git log -- path/al/archivo                      # Historial de commits de un archivo
git log -p -- path/al/archivo                   # Historial + diffs de un archivo
git log --all                                   # Log de todas las ramas
```

### Ver cambios de un commit específico
```bash
git show <commit-hash>                          # Ver commit completo con diff
git show --name-only <commit-hash>              # Solo archivos modificados en ese commit
```

---

## 🔍 Comparar diferencias

### Con herramienta visual (meld u otro difftool)
```bash
git difftool HEAD -- <archivo>
git difftool <commit1> <commit2> -- <archivo>
```

### Con línea de comandos
```bash
git diff <archivo>                  # Cambios NO staged (working tree vs último commit)
git diff --staged <archivo>         # Cambios STAGED (listos para commit)
git diff HEAD                       # TODOS los cambios (working + staged vs último commit)
git diff dev..qa -- <archivo>       # Diferencias de un archivo entre dos ramas
git diff dev:<archivo> qa:<archivo> # Otra forma de comparar el mismo archivo entre ramas
```

---

## ⏪ Revertir archivos y commits

### Restaurar un archivo a un commit anterior
```bash
git restore --source <commit-hash> <archivo>    # Recomendado (Git >= 2.23)
git restore --source <commit-hash> .            # Restaurar todos los archivos del directorio
git checkout <commit-hash> -- <archivo>         # Alternativa tradicional (Git < 2.23)
```

### Revertir commits
```bash
git revert <commit-hash>            # Crea un nuevo commit que deshace los cambios (seguro para ramas compartidas)
git reset --soft HEAD~1             # Deshace el último commit pero mantiene los cambios en stage
git reset --hard origin/<rama>      # Descarta commits locales y sincroniza con el remoto
```

### Editar el último commit
```bash
git commit --amend                  # Editar mensaje del último commit
git commit --amend -m "Nuevo mensaje"
git commit --amend --no-edit        # Agregar cambios al último commit sin cambiar el mensaje
```

---

## 🌿 Manejo de ramas

### Crear y cambiar ramas
```bash
git switch <nombre_rama>                # Cambiar a una rama existente (Git >= 2.23, recomendado)
git switch -c <nombre_rama>             # Crear y cambiar en un paso
git switch -c <nombre_rama> <hash>      # Crear rama desde un commit específico
git checkout <nombre_rama>              # Alternativa tradicional (Git < 2.23)
git checkout -b <nombre_rama>           # Alternativa tradicional: crear y cambiar
```

### Listar ramas
```bash
git branch                          # Solo locales
git branch -a                       # Locales y remotas
git branch -r                       # Solo remotas
```

### Eliminar ramas
```bash
git branch -d <nombre_rama>         # Eliminar rama local (solo si ya fue mergeada)
git branch -D <nombre_rama>         # Forzar eliminación de rama local
```

### Renombrar rama
```bash
git branch -m <nombre_nuevo>                    # Renombrar la rama actual
git branch -m <nombre_viejo> <nombre_nuevo>     # Renombrar cualquier rama local
```

### Actualizar rama remota sin moverse
```bash
git fetch origin qa:qa              # Actualizar rama qa local desde el remoto
```

---

## 🔄 Merge e integración

### Proceso de merge típico
```bash
git switch dev
git pull origin dev
git switch <rama_feature>
git merge dev
git push origin <rama_feature>
```

### Cancelar merge en proceso
```bash
git merge --abort
```

---

## 🍒 Cherry-pick

### Traer commits específicos a la rama actual
```bash
git cherry-pick <hash-commit>
git cherry-pick <commit1> <commit2> <commit3>   # Múltiples commits
git cherry-pick <inicio>^..<fin>                # Rango de commits (inclusivo)
git cherry-pick --no-commit <hash>              # Aplica cambios sin hacer commit automático
```

### Resolver conflictos en cherry-pick
```bash
# Después de resolver conflictos manualmente:
git add .
git cherry-pick --continue
```

---

## 🌐 Remotos

### Consultar remotos
```bash
git remote -v                               # Ver remotos configurados
```

### Descargar cambios
```bash
git fetch origin                            # Descarga cambios sin aplicarlos
git pull origin <rama>                      # Descarga y aplica cambios
git pull --rebase origin <rama>             # Pull con rebase en lugar de merge
```

### Subir cambios
```bash
git push origin <rama>
git push -u origin <rama>                   # Sube y establece tracking con el remoto
git push --force-with-lease origin <rama>   # Push forzado seguro (falla si alguien más subió cambios)
```

---

## 🏷️ Tags

> 💡 Los tags marcan commits específicos como versiones de release (ej: `v1.0.0`). En muchos equipos esto lo gestiona automáticamente el pipeline de CI/CD o el tech lead, por lo que puede que nunca necesites usarlos manualmente.

### Crear y listar tags
```bash
git tag                             # Listar todos los tags
git tag <nombre>                    # Crear tag ligero en el commit actual
git tag -a <nombre> -m "mensaje"    # Crear tag anotado con mensaje
git tag -a <nombre> <commit-hash>   # Crear tag en un commit específico
```

### Publicar y eliminar tags
```bash
git push origin <nombre-tag>        # Publicar un tag específico al remoto
git push origin --tags              # Publicar todos los tags al remoto
git tag -d <nombre-tag>             # Eliminar tag local
git push origin --delete <nombre-tag> # Eliminar tag del remoto
```

---

*💡 Tip: Usa `git help <comando>` para obtener ayuda detallada de cualquier comando*