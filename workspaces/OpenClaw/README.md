---
display_name: OpenClaw
description: "Workspace OpenClaw con escritorio básico (KasmVNC), Chrome y Docker in Docker"
icon: icon.svg
maintainer_github: makespacemadrid
tags: [openclaw, agents, docker, dind, workspace, makespace]
---

# OpenClaw (Inicial)

Template inicial para ejecutar OpenClaw sobre la imagen `ghcr.io/makespacemadrid/coder-mks-developer:latest`, con escritorio básico XFCE en KasmVNC, Chrome y Docker in Docker.

## Cuándo usarlo
- Quieres un workspace orientado a agentes/OpenClaw con escritorio básico web.
- Necesitas ajustar puerto/directorio de OpenClaw por proyecto.

## Qué incluye
- Imagen `ghcr.io/makespacemadrid/coder-mks-developer:latest` con escritorio y tooling dev.
- Escritorio XFCE con módulo `kasmvnc`.
- Navegador Chrome (con fallback a Chromium si no está disponible el paquete).
- Docker instalado al iniciar y ejecutando DinD (dockerd dentro del contenedor).
- Node.js actualizado automáticamente a `>=22.12` cuando hace falta (requisito de OpenClaw).
- Parámetros de OpenClaw: autoarranque, puerto y directorio.
- Instalación oficial de OpenClaw en primer arranque (`curl -fsSL https://openclaw.ai/install.sh | bash`) en modo no interactivo.
- Script `~/.local/bin/start-openclaw` y logs en `~/.local/state/openclaw/openclaw.log`.
- App dedicada `OpenClaw UI` en Coder (reverse proxy al puerto configurado).
- Home persistente en `/home/coder` (volumen o bind mount según parámetros) y datos de Docker en `/var/lib/docker`.
- Labels `com.centurylinklabs.watchtower.*` para actualizaciones con Watchtower.

## Creación rápida en Coder
- Puedes entrar por KasmVNC (escritorio) o terminal.
- `GPU`: activa `--gpus all` en el contenedor.
- `Persistir home en el host`: monta `/home/coder` en `TF_VAR_users_storage/<usuario>/<workspace>`.
- `Persistir solo ~/Projects`: monta `/home/coder/Projects` en `TF_VAR_users_storage/<usuario>/<workspace>/Projects`.
- `Montar ruta host en ~/host`: monta una ruta del host en `/home/coder/host`.
- `Especificar UID para montar la ruta host`: UID para ejecutar el contenedor cuando montas `/home/coder/host` (por defecto 1000).
- `Repositorio Git`: clona en `~/Projects` al primer arranque.
- `[OpenClaw] Auto-iniciar servicio`: arranca OpenClaw al iniciar.
- `[OpenClaw] Puerto`: puerto de OpenClaw (por defecto `3333`).
- `[OpenClaw] Directorio de trabajo`: directorio desde el que se ejecuta OpenClaw.
- `OpenCode Base URL` + `OpenCode API key`: variables de entorno OpenAI-compatible para uso manual.
- `Provisionar API key MakeSpace automáticamente`: genera una key de 30 días si no aportas una.

## Notas
- El arranque de OpenClaw es síncrono en startup: intenta dejar el gateway arriba antes de finalizar el arranque del workspace.
- Si `openclaw` no está instalado y el autoarranque está activo, el template intenta instalarlo automáticamente con el instalador oficial.
- Tras el autoarranque, el template prueba salud operativa con `openclaw health` (best-effort) para detectar fallos tempranos del gateway.
- La app `OpenClaw UI` apunta a `http://localhost:<puerto OpenClaw>/?token=<gateway token>` para inyectar credenciales en cada apertura y su healthcheck usa `/`.
- La app `OpenClaw UI` se publica por subdominio (`subdomain=true`) y abre en pestaña normal (`open_in="tab"`).
- El token del gateway se genera automáticamente (aleatorio) por workspace.
- El template sincroniza ese token en `gateway.auth.token`, de modo que `openclaw dashboard --no-open` y la app `OpenClaw UI` usan el mismo valor.
- El template no parchea los assets de `control-ui`; usa el flujo nativo de OpenClaw para tomar `?token` y guardarlo en `localStorage`.
- Puedes relanzar manualmente con `~/.local/bin/start-openclaw`.
- Si ejecutas `openclaw dashboard` en una terminal sin GUI, es normal ver "No GUI detected"; en Coder abre directamente el app `OpenClaw UI`.
- El contenedor se ejecuta en modo `privileged` para soportar Docker in Docker.
- Tras merge a `main`, ejecuta `coder templates push` para publicar el template en Coder.

### Limitaciones de DinD
- No hay Swarm ni orquestador: `docker compose` ignora la sección `deploy.*`, así que no funcionan `resources.reservations/limits`, `placement`, `replicas`, etc. Usa flags de `docker run`/`docker compose` (`--cpus`, `--memory`, `--gpus`) para limitar contenedores.
- Las reservas de CPU/RAM solo pueden consumir lo que tenga asignado el workspace; los contenedores hijos no pueden reservar más allá de ese presupuesto.
- El Docker interno no accede al Docker del host; si necesitas manejar contenedores del nodo host, usa otro template con acceso al socket.
