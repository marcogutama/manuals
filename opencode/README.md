# Configuración de OpenCode

Copia versionada de las skills y subagentes de [OpenCode](https://opencode.ai/docs). Es un **espejo exacto** de
`~/.config/opencode/`, con la misma estructura interna, para que sincronizar sea una copia directa.

```
opencode/
├── skills/
│   ├── commit-generator/SKILL.md              # mensajes de commit (Conventional Commits)
│   ├── quarkus-microservice-scaffold/SKILL.md  # crear microservicio nuevo
│   ├── quarkus-logging-audit/SKILL.md          # logs, MDC, auditoría, datos sensibles
│   ├── quarkus-rest-contract/SKILL.md          # endpoints, DTOs, OpenAPI, codRespuesta
│   ├── quarkus-resilience/SKILL.md             # clientes externos, fault tolerance, colas
│   └── quarkus-testing/SKILL.md                # tests, cobertura, JaCoCo
└── agents/
    └── quarkus-reviewer.md                     # revisión pre-PR contra el estándar
```

Las skills `quarkus-*` derivan de [`../microservicios/`](../microservicios/) y contienen las reglas accionables
de cada dominio, para no cargar las ~3200 líneas de la norma en cada sesión.

## Instalar

```bash
cp -r ~/Documents/manuals/opencode/skills/* ~/.config/opencode/skills/
cp -r ~/Documents/manuals/opencode/agents/* ~/.config/opencode/agents/
```

Quedan disponibles en cualquier directorio (skills globales). La alternativa es `.opencode/skills/` dentro de
un repositorio, que las versiona con el equipo pero las limita a ese proyecto.

## Sincronizar

Los archivos de aquí y los de `~/.config/opencode/` son **independientes**: al editar uno hay que copiar al
otro.

```bash
# manuals → config (después de un git pull)
cp -r ~/Documents/manuals/opencode/skills/* ~/.config/opencode/skills/
cp -r ~/Documents/manuals/opencode/agents/* ~/.config/opencode/agents/

# config → manuals (después de editar en caliente)
cp -r ~/.config/opencode/skills/quarkus-* ~/Documents/manuals/opencode/skills/
cp ~/.config/opencode/agents/quarkus-reviewer.md ~/Documents/manuals/opencode/agents/
```

Verificar que están sincronizados:

```bash
diff -r ~/.config/opencode/skills ~/Documents/manuals/opencode/skills
diff -r ~/.config/opencode/agents ~/Documents/manuals/opencode/agents
```

Alternativa: reemplazar las copias de `~/.config/opencode/` por symlinks a este directorio. Elimina la
sincronización manual, a cambio de que la configuración dependa de que exista.

## Convenciones

- **Skills**: directorio `skills/<nombre>/SKILL.md`, con `<nombre>` idéntico al campo `name` del frontmatter.
  Solo minúsculas, dígitos y guiones simples: `^[a-z0-9]+(-[a-z0-9]+)*$`.
- **Frontmatter**: `name` y `description` obligatorios. La `description` decide si la skill se activa, así que
  debe enumerar los temas y las palabras que usarías al pedir ese trabajo.
- **Subagentes**: `agents/<nombre>.md`; el nombre del archivo es el nombre del agente. Los de revisión llevan
  `permission.edit: deny`.
- **Contenido accionable**, no explicativo. Si una skill pasa de ~300 líneas, probablemente son dos.

Detalle del flujo completo en
[../microservicios/flujo-trabajo-ia.md](../microservicios/flujo-trabajo-ia.md).
