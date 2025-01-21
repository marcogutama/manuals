# Comandos mas comunes git

## git status -s

## buscar un archivo en linux
find . -name "FFCAddTurnCondition.java"
find . -type f -name "*.properties"  ->-type f: Indica que solo quieres buscar archivos (no directorios u otros tipos de archivos).
find . -type f -name "*test*"

## Buscar archivos en git
git ls-files "*.properties"
git ls-files "*test*"

## Ver historial de un objecto
git log --follow /path/test.txt -> follow: obtiene historial de un archivo incluso si se ha renombrado o movido en algún momento del tiempo
git log --oneline --graph

## Ver diferencias con gui
git difftool HEAD -- /path/test.txt
git difftool commit1 commit2 -- /path/test.txt

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

## Buscar una rama
git branch -a|grep 276809

## Hacer merge desde la rama 3-az-246233 a dev
git checkout dev
git pull origin dev
git checkout 3-az-246233
git merge dev
git push origin dev

## Revertir un archivo a un commit anterior
git checkout <commit-hash> -- <archivo>

## COnfiguracion herramienta gui para comparacion
git config --global diff.tool meld
git config --global difftool.prompt false