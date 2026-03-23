# Comandos Git - Guía de Referencia

## 🔧 Configuración inicial

### Setup básico
```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu.email@ejemplo.com"
git config --global core.editor "nano"  # o vim, emacs, etc.
git config --global color.ui auto
```

### Configurar herramientas
```bash
# Herramienta de comparación visual
git config --global diff.tool meld
git config --global difftool.prompt false

# Helper para contraseñas (guarda en ~/.git-credentials)
git config --global credential.helper store
git config --global --unset credential.helper	# Limpiar las credenciales
```

### Alias útiles
```bash
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
```

### Verificar configuración
```bash
git config --list
git config --list --global
```

## 🚀 Inicialización y estado

### Crear repositorio
```bash
mkdir mi-proyecto
cd mi-proyecto
git init
```

### Estado del repositorio
```bash
git status          # Estado completo
git status -s        # Estado resumido
```

## 📁 Manejo de archivos

### Buscar archivos
```bash
git ls-files "*.properties"
git ls-files "*test*"
```

### Preparar cambios (Stage)
```bash
git add <archivo>          # Preparar un archivo específico
git add .                  # Preparar cambios del directorio actual hacia abajo
git add -A                 # Preparar TODO el repositorio (independiente de la carpeta actual)
git add :/                 # Preparar TODO desde la raíz del proyecto
git add -u                 # Preparar solo archivos ya rastreados (ignora archivos nuevos ??)
```
### Quitar del stage (Unstage)
# Quitar del stage (mantiene los cambios en el archivo)
```bash
git reset <archivo>        # Quitar un archivo específico
git reset .                # Quitar todo lo del directorio actual
git reset :/               # Quitar todo lo del repositorio (Global)
```

### Descartar cambios
```bash
# Descartar cambios no confirmados
git restore <archivo>

# Descartar TODOS los cambios
git reset --hard HEAD

# Eliminar archivos nuevos (??)
git clean -fd
```

## 📜 Historial y logs

### Ver historial
```bash
git log --oneline --graph
git log --follow <archivo>           # Sigue renombres/movimientos
git log --author="nombre_autor"
git log --author="nombre" --pretty=format:"%h - %s"
git log --since="2024-01-01" --until="2024-12-31"
git log <rama>                       # Commits de una rama específica
git log <rama> --grep="filtro"       # Filtrar con grep
git log -- path/al/archivo           # Historial de commits de un archivo
git log -p -- path/al/archivo        # Incluir diffs (los cambios realizados en cada commit)
git log --all                        # Log de todas las ramas
```

### Ver cambios específicos
```bash
git show <commit-hash>               # Ver commit completo
git show --name-only <commit-hash>   # Solo archivos modificados
```

## 🔍 Comparar diferencias

### Con herramienta visual (difftool)
```bash
git difftool HEAD -- <archivo>
git difftool <commit1> <commit2> -- <archivo>
```

### Con línea de comandos (diff)
```bash
git diff dev..qa -- <archivo>
git diff dev:<archivo> qa:<archivo>
git diff <archivo>                  # Ver cambios NO staged
git diff --staged <archivo>         # Ver cambios STAGED
git diff HEAD                       # Ver TODOS los cambios (working + staged vs último commit)
```

## 🌿 Manejo de ramas

### Crear y cambiar ramas
```bash
git branch <nombre_rama>             # Crear rama
git checkout -b <nombre_rama>        # Crear y cambiar en un paso
```

### Listar ramas
```bash
git branch          # Solo locales
git branch -a       # Locales y remotas
git branch -r       # Solo remotas
```

### Eliminar ramas
```bash
git branch -d <nombre_rama>          # Eliminar rama local
```

### Actualizar rama sin moverse
```bash
git fetch origin qa:qa               # Actualizar rama qa desde remoto
```

## 🔄 Merge y integración

### Proceso de merge típico
```bash
git checkout dev
git pull origin dev
git checkout <rama_feature>
git merge dev
git push origin dev
```

### Cancelar merge
```bash
git merge --abort                    # Cancelar merge en proceso
```

## ⏪ Deshacer cambios

### Revertir commits
```bash
git revert <id-del-commit>                  # Revertir un commit
git reset --soft HEAD~1              		# Deshacer último commit (mantiene cambios)
git checkout <commit-hash> -- <archivo>  	# Revertir archivo específico
git reset --hard origin/main				# Descartar commits locales
```

### Editar commits
```bash
git commit --amend                      # Editar mensaje del último commit
git commit --amend -m "First commit"
git commit --amend --no-edit            # Fusiona los cambios con el commit anterior
```

## 🍒 Cherry-pick

### Traer commits específicos
```bash
git cherry-pick <hash-commit>
git cherry-pick <commit1> <commit2> <commit3>    # Múltiples commits
git cherry-pick <inicio>^..<fin>                 # Rango de commits
git cherry-pick --no-commit <hash>               # Sin commit automático
```

### Resolver conflictos en cherry-pick
```bash
# Después de resolver conflictos manualmente:
git add .
git cherry-pick --continue
```

## 💾 Stash (cambios temporales)

### Operaciones básicas
```bash
git stash                    # Guardar cambios temporalmente
git stash pop               # Restaurar y eliminar del stash
git stash apply             # Aplicar sin eliminar del stash
```

### Gestión avanzada
```bash
git stash list                      # Listar todos los stashes
git stash show <stash_name>         # Ver contenido de un stash
git stash drop <stash_name>         # Eliminar stash específico
git stash clear                     # Eliminar TODOS los stashes
git stash show -p stash@{0}         # Ver los cambios del stash más reciente (stash@{0})
git stash show stash@{0}            # Resumen de archivos del stash más reciente
```

---

*💡 Tip: Usa `git help <comando>` para obtener ayuda detallada de cualquier comando*