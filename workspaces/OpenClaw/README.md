---
display_name: OpenClaw
description: "Workspace OpenClaw con escritorio básico (KasmVNC), Chrome, code-server y Docker in Docker"
icon: icon.svg
maintainer_github: makespacemadrid
tags: [openclaw, agents, docker, dind, workspace, makespace]
---

# OpenClaw (Inicial)

Template inicial para ejecutar OpenClaw sobre la imagen `ghcr.io/makespacemadrid/coder-mks-developer:latest`, con escritorio básico XFCE en KasmVNC, Chrome, code-server y Docker in Docker.

## Cuándo usarlo
- Quieres un workspace orientado a agentes/OpenClaw con escritorio básico web.
- Necesitas ajustar comando/puerto/directorio de OpenClaw por proyecto.

## Qué incluye
- Imagen `ghcr.io/makespacemadrid/coder-mks-developer:latest` con escritorio y tooling dev.
- Escritorio XFCE con módulo `kasmvnc`.
- Navegador Chrome (con fallback a Chromium si no está disponible el paquete).
- code-server integrado.
- Docker instalado al iniciar y ejecutando DinD (dockerd dentro del contenedor).
- Node.js actualizado automáticamente a `>=22.12` cuando hace falta (requisito de OpenClaw).
- Parámetros de OpenClaw: autoarranque, puerto, directorio y comando.
- Instalación oficial de OpenClaw en primer arranque (`curl -fsSL https://openclaw.ai/install.sh | bash`) en modo no interactivo.
- Script `~/.local/bin/start-openclaw` y logs en `~/.local/state/openclaw/openclaw.log`.
- App dedicada `OpenClaw UI` en Coder (reverse proxy al puerto configurado).
- OpenCode/Claude opcionales para asistentes de IA (con autoprovision de key MakeSpace si se activa).
- Home persistente en `/home/coder` (volumen o bind mount según parámetros) y datos de Docker en `/var/lib/docker`.
- Labels `com.centurylinklabs.watchtower.*` para actualizaciones con Watchtower.

## Creación rápida en Coder
- Puedes entrar por KasmVNC (escritorio), code-server o terminal.
- `GPU`: activa `--gpus all` en el contenedor.
- `Persistir home en el host`: monta `/home/coder` en `TF_VAR_users_storage/<usuario>/<workspace>`.
- `Persistir solo ~/Projects`: monta `/home/coder/Projects` en `TF_VAR_users_storage/<usuario>/<workspace>/Projects`.
- `Montar ruta host en ~/host`: monta una ruta del host en `/home/coder/host`.
- `Especificar UID para montar la ruta host`: UID para ejecutar el contenedor cuando montas `/home/coder/host` (por defecto 1000).
- `Repositorio Git`: clona en `~/Projects` al primer arranque.
- `[OpenClaw] Auto-iniciar servicio`: arranca OpenClaw al iniciar.
- `[OpenClaw] Onboard --install-daemon`: intenta `openclaw onboard --install-daemon` en modo no interactivo (best-effort).
- `[OpenClaw] Puerto`: puerto de OpenClaw (por defecto `3333`).
- `[OpenClaw] Directorio de trabajo`: directorio desde el que se ejecuta OpenClaw.
- `[OpenClaw] Comando de arranque`: por defecto usa `openclaw gateway run --allow-unconfigured --port ... --auth token --token ...`. Si lo dejas vacío, OpenClaw queda deshabilitado (sin app UI ni autoarranque).
- `[OpenClaw] UI path`: ruta de la UI para el app de Coder (por defecto `/`).
- `[OpenClaw] Health path`: ruta de healthcheck para el app de Coder (por defecto `/`).
- `OpenCode Base URL` + `OpenCode API key`: configura proveedor OpenAI-compatible.
- `Provisionar API key MakeSpace automáticamente`: genera una key de 30 días si no aportas una.
- `Claude Token`: usa Claude y omite OpenCode (genera el token con `claude setup-token`).

## Notas
- El arranque de OpenClaw es no bloqueante: si falla, el workspace sigue iniciando y deja aviso en logs.
- Si `openclaw` no está instalado y el autoarranque está activo, el template intenta instalarlo automáticamente con el instalador oficial.
- Tras el autoarranque, el template prueba salud operativa con `openclaw health` (best-effort) para detectar fallos tempranos del gateway.
- La app `OpenClaw UI` apunta a `http://localhost:<puerto OpenClaw><UI path>` y su healthcheck usa `<Health path>`.
- Puedes relanzar manualmente con `~/.local/bin/start-openclaw`.
- Si `OPENCLAW_COMMAND` está vacío, `start-openclaw` te mostrará un mensaje de configuración en lugar de fallar silenciosamente.
- El contenedor se ejecuta en modo `privileged` para soportar Docker in Docker.
- Tras merge a `main`, ejecuta `coder templates push` para publicar el template en Coder.

### Limitaciones de DinD
- No hay Swarm ni orquestador: `docker compose` ignora la sección `deploy.*`, así que no funcionan `resources.reservations/limits`, `placement`, `replicas`, etc. Usa flags de `docker run`/`docker compose` (`--cpus`, `--memory`, `--gpus`) para limitar contenedores.
- Las reservas de CPU/RAM solo pueden consumir lo que tenga asignado el workspace; los contenedores hijos no pueden reservar más allá de ese presupuesto.
- El Docker interno no accede al Docker del host; si necesitas manejar contenedores del nodo host, usa otro template con acceso al socket.
