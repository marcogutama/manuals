---
name: commit-generator
description: Analiza los cambios de git (staged o todos) y genera un mensaje de commit siguiendo el estándar Conventional Commits, con selección atómica de archivos, detección automática de número de issue desde el nombre de la rama, y soporte multi-idioma. Úsalo cuando el usuario pida generar, sugerir o revisar un mensaje de commit para sus cambios actuales, o pida hacer un "commit atómico".
---

# Conventional Commit Generator

Skill inspirada en el flujo de [geminicommit](https://github.com/marcogutama/geminicommit) para generar mensajes de commit en formato Conventional Commits, sin depender de ninguna API externa: el propio agente de IA actúa como el modelo generador.

Esta skill SOLO genera el mensaje (y, si aplica, la lista de archivos sugerida). No ejecuta `git add` ni `git commit` automáticamente; el usuario decide si aplicar los cambios.

## Flujo de trabajo

1. **Recolectar contexto del repositorio**
   - Ejecuta `git status --porcelain=v1 --untracked-files=all` para ver qué hay modificado, nuevo o eliminado.
   - Si hay cambios en el índice (staged), usa `git diff --cached --diff-algorithm=minimal` como fuente principal del diff.
   - Si NO hay nada en staged pero sí hay cambios en el working directory, informa al usuario y ofrece dos caminos: (a) generar el mensaje igualmente analizando todos los cambios (modo "auto"), o (b) esperar a que el usuario haga `git add`.
   - Detecta la rama actual con `git branch --show-current`.

2. **Detectar número de issue desde el nombre de la rama** (si el usuario no lo da explícitamente)
   Aplica estos patrones en orden y usa el primer match:
   - `([A-Z]+-\d+)` (case-insensitive, normalizar a mayúsculas) → ej. `GEN-123`, `feature/ELI-1220` → `ELI-1220`
   - `#(\d+)` → ej. `feature-#123` → `123`
   - `(\d+)-` → ej. `123-add-login` → `123`
   - `-(\d+)-` → ej. `feature-123-login` → `123`
   - `issue-(\d+)`, `fix-(\d+)`, `feat-(\d+)`, `bug-(\d+)` → extraer el número
   Si no hay match, no se incluye número de issue (a menos que el usuario lo pase explícitamente).

3. **Selección atómica de archivos** (si hay más de un archivo modificado)
   Si el diff mezcla cambios de propósitos distintos (features/fixes/refactors no relacionados), NO los mezcles en un solo commit. En su lugar:
   - Agrupa los archivos por relación lógica: imports/dependencias compartidas, cambios de firma de función y sus llamadores, archivos de implementación junto a sus tests, configuración relacionada con el código que la usa.
   - Selecciona SOLO el grupo de archivos que forma un cambio completo, cohesivo y funcional (compila, no deja nada roto a medias).
   - Si detectas múltiples grupos independientes, dilo explícitamente al usuario y sugiere generar varios commits atómicos en lugar de uno solo. Genera el mensaje para el primer grupo y lista los archivos restantes como pendientes.
   - Si todos los archivos staged/modificados ya forman un único cambio coherente, úsalos todos.

4. **Generar el mensaje de commit**

   Formato de salida:
   ```
   <type>[scope][!]: [ft(<issue>) - ]<description>

   [body]

   [footer(s)]
   ```

   Reglas:
   - **type** (obligatorio, siempre en inglés, minúsculas, literal de Conventional Commits):
     - `feat`: nueva funcionalidad
     - `fix`: corrección de bug
     - `docs`: solo documentación
     - `style`: cambios que no afectan la lógica (espacios, formato, punto y coma)
     - `refactor`: cambio de código que no es fix ni feat
     - `perf`: mejora de rendimiento
     - `test`: agregar o corregir tests
     - `chore`: cambios de build/herramientas auxiliares
     - `ci`: cambios en configuración/scripts de CI
     - `build`: cambios en el sistema de build o dependencias externas
     - `revert`: revierte un commit anterior
   - **scope** (opcional, siempre en inglés): módulo, componente o carpeta afectada. Omitir si el cambio es global o abarca muchas áreas.
   - **description** (obligatoria): imperativo, minúscula inicial, sin punto final, idealmente bajo 50 caracteres en el subject completo (`type(scope): description`).
   - **issue**: si hay un número de issue (detectado o dado por el usuario), insértalo inmediatamente después de los dos puntos como `ft(<issue>) - `. Ejemplo: `feat(auth): ft(123) - add login validation`. Nunca agregues un footer `Ref:` para esto.
   - **body** (opcional): explica el *por qué* y *cómo* cambia el comportamiento anterior, si el cambio lo justifica. Usa oraciones imperativas, párrafos separados por líneas en blanco.
   - **BREAKING CHANGE** (opcional): si el cambio rompe compatibilidad, agrega un footer `BREAKING CHANGE: <qué cambió y cómo migrar>`. También puedes marcarlo con `!` después del type/scope (ej. `feat(api)!:`), pero el footer detallado sigue siendo recomendable.
   - **maxLength**: por defecto 72 caracteres para el mensaje completo (subject + body + footers), salvo que el usuario indique otro valor. El límite de ~50 caracteres es solo para el subject.
   - **idioma**: si el usuario pide un idioma distinto al inglés (ej. español, francés), el `type` y el `scope` se mantienen SIEMPRE en inglés; solo la `description`, el `body` y el texto de `BREAKING CHANGE` se traducen. Por defecto, usa inglés si el usuario no especifica idioma.

5. **Salida esperada**

   Si hubo selección atómica de archivos, responde primero con la lista de archivos elegidos:
   ```
   FILES: file1, file2, ...
   ```
   y si quedaron archivos fuera de este commit, indícalos aparte como sugerencia para un commit siguiente.

   Luego el mensaje de commit final, listo para copiar (sin comillas ni backticks adicionales):
   ```
   <mensaje de commit>
   ```

6. **No ejecutar acciones destructivas ni de escritura**
   - No corras `git add`, `git commit`, `git push` ni `git reset` salvo que el usuario lo pida explícitamente en un turno posterior.
   - Si el usuario luego confirma que quiere aplicar el commit, puedes ofrecer ejecutar `git commit -m "<mensaje>"` (y `git push` si lo pide), pero siempre como paso separado y explícito.

## Ejemplo

Input (`git diff --cached`):
```diff
diff --git a/src/user.js b/src/user.js
@@ -10,7 +10,7 @@
 const getUser = (id) => {
-  return { id, name: 'Old Name' };
+  return { id, name: 'New User' };
 };
+
+const deleteUser = (id) => {
+  // Delete user from database
+};
```
Rama: `42-user-management`

Output:
```
FILES: src/user.js

feat(user): ft(42) - add delete user function

Adds a new function `deleteUser` to handle the removal of users
from the database. Also updates the export to include it.
```
