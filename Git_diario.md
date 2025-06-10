# Comandos mas comunes git

## git setup
git config --global user.name "Tu Nombre"
git config --global user.email "tu.email@ejemplo.com"
git config --global core.editor "nano"  # o vim, emacs, etc.
git config --global color.ui auto

## Verificar configuracion
git config --list
git config --list --global

## Configurar alias
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status

## Crear repositorio
mkdir mi-proyecto
cd mi-proyecto
git init

## git status -s

## Buscar archivos en git
git ls-files "*.properties"
git ls-files "*test*"

## Ver historial de un objecto
git log --follow /path/test.txt -> follow: obtiene historial de un archivo incluso si se ha renombrado o movido en algún momento del tiempo
git log --oneline --graph
git log --author="parte_del_nombre"
git log --author="nombre_del_autor" --pretty=format:"%h - %s"
git log --author="nombre_del_autor" --since="2024-01-01" --until="2024-12-31"
git log <nombre-de-la-rama> # Lista todos los commits de la rama en especificada
git log <nombre-de-la-rama> --grep="filter" # Filtrar con grep


## Para actualizar (hacer pull) de la rama qa sin moverte de dev
git fetch origin qa:qa

## Ver diferencias con gui (difftool), sin gui (diff)
git difftool HEAD -- /path/test.txt
git difftool commit1 commit2 -- /path/test.txt
git diff dev..qa -- path/to/your/file
git diff dev:/path/test.txt qa:/path/test.txt

## Ver archivos modificados en un commit específico
git show --name-only <commit-hash>
git show <commit-hash>

## Descartar todos los cambios 
git reset --hard HEAD

## Reversar commit cuando aun no se hace push:
git reset --soft HEAD~1

## Deshacer cambios no confirmados (no stage)
git restore src/main/java/ec/fin/baustro/service/ProducerProcessor.java

## Quitar del stage (pero mantiene los cambios)
git reset <file>
git reset .

## Quitar del stage y resetea los cambios (stage)
git reset HEAD src/main/java/ec/fin/baustro/service/ProducerProcessor.java

## Editar mensaje commit
git commit --amend

## Eliminar archivos nuevos (??):
git clean -fd

## Crear una nueva rama
git branch nombre_de_la_rama
git checkout -b nombre_de_la_rama	->crear y se cambia a la nueva rama en un solo paso

## Eliminar una rama local
git branch -d nombre-de-la-rama

## Listar ramas
git branch		# solo muestra las ramas locales
git branch -a	# ramas locales y remotas
git branch -r	# solo ramas remotas

## Hacer merge desde la rama 3-az-246233 a dev
git checkout dev
git pull origin dev
git checkout 3-az-246233
git merge dev
git push origin dev

## Revertir un archivo a un commit anterior
git checkout <commit-hash> -- <archivo>

## Configuracion herramienta gui para comparacion
git config --global diff.tool meld
git config --global difftool.prompt false

## Guardar cambios temporalmente
git stash

## Comprueba que los cambios están guardados
git stash list

## Restaura cambios desde el stash
git stash pop

## Helper contraseñas (Git las guardará en ~/.git-credentials, y no te las volverá a pedir)
git config --global credential.helper store
