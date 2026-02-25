terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
    null = {
      source = "hashicorp/null"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

variable "docker_socket" {
  default     = "unix:///var/run/docker.sock"
  description = "(Opcional) Docker socket URI (usa unix:// prefix)"
  type        = string
}

variable "users_storage" {
  default     = ""
  description = "Ruta base para storage de usuarios (ej. $TF_VAR_users_storage)."
  type        = string
}

variable "opencode_default_base_url" {
  default     = ""
  description = "Base URL OpenAI-compatible por defecto (ej. $TF_VAR_opencode_default_base_url)."
  type        = string
}

variable "mks_key_endpoint" {
  default     = ""
  description = "Endpoint para solicitar keys MakeSpace (autoprovision)."
  type        = string
}

variable "default_repo_url" {
  default     = ""
  description = "Repositorio Git por defecto (ej. $TF_VAR_default_repo_url)."
  type        = string
}
data "coder_parameter" "enable_gpu" {
  name         = "01_enable_gpu"
  display_name = "[Compute] GPU"
  description  = "Activa --gpus all en el contenedor."
  type         = "bool"
  default      = false
  mutable      = true
}

data "coder_parameter" "enable_dri" {
  name         = "01_enable_dri"
  display_name = "[Compute] DRI (/dev/dri)"
  description  = "Mapea /dev/dri para aceleracion grafica (Intel/AMD o NVIDIA via EGL/GL)."
  type         = "bool"
  default      = false
  mutable      = true
}

data "coder_parameter" "git_repo_url" {
  name         = "03_git_repo_url"
  display_name = "[Code] Repositorio Git (opcional)"
  description  = "URL de Git para clonar en ~/Projects/<repo> en el primer arranque"
  type         = "string"
  default      = var.default_repo_url
  mutable      = true
}

data "coder_parameter" "persist_home_storage" {
  name         = "02_01_persist_home_storage"
  display_name = "[Storage] Persistir home en el host"
  description  = "Monta /home/coder en TF_VAR_users_storage/<usuario>/<workspace>. Si no lo activas, /home/coder se guarda en un volumen Docker; si el workspace esta apagado y se limpia Docker en el host, ese volumen puede desaparecer."
  type         = "bool"
  default      = false
  mutable      = true
}

data "coder_parameter" "persist_projects_storage" {
  name         = "02_02_persist_projects_storage"
  display_name = "[Storage] Persistir solo ~/Projects"
  description  = "Monta /home/coder/Projects en TF_VAR_users_storage/<usuario>/<workspace>/Projects."
  type         = "bool"
  default      = false
  mutable      = true
}

data "coder_parameter" "host_mount_path" {
  name         = "02_03_host_mount_path"
  display_name = "[Storage] Montar ruta host en ~/host"
  description  = "Ruta del host que se monta en /home/coder/host dentro del workspace."
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "host_mount_uid" {
  name         = "02_04_host_mount_uid"
  display_name = "[Storage] Especificar UID para montar la ruta host"
  description  = "UID para ejecutar el contenedor cuando montas ~/host. Por defecto 1000."
  type         = "string"
  default      = "1000"
  mutable      = true
}

data "coder_parameter" "opencode_provider_url" {
  name         = "04_opencode_provider_url"
  display_name = "[AI/OpenAI] Base URL (opcional)"
  description  = "Base URL compatible con OpenAI (ej. https://api.tu-proveedor.com/v1)."
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "opencode_api_key" {
  name         = "04_opencode_api_key"
  display_name = "[AI/OpenAI] API key (opcional)"
  description  = "API key para el proveedor OpenAI compatible."
  type         = "string"
  default      = ""
  mutable      = true
}

data "coder_parameter" "autoprovision_mks_key" {
  name         = "04_autoprovision_mks_key"
  display_name = "[AI/OpenCode] Provisionar API key MakeSpace automáticamente"
  description  = "Genera y precarga una API key MakeSpace (30 días)."
  type         = "bool"
  default      = true
  mutable      = true
}

data "coder_parameter" "openclaw_autostart" {
  name         = "05_openclaw_autostart"
  display_name = "[OpenClaw] Auto-iniciar servicio"
  description  = "Intenta arrancar OpenClaw al iniciar el workspace (sin fallar si no esta instalado)."
  type         = "bool"
  default      = true
  mutable      = true
}

data "coder_parameter" "openclaw_port" {
  name         = "05_openclaw_port"
  display_name = "[OpenClaw] Puerto"
  description  = "Puerto TCP para la UI/API de OpenClaw."
  type         = "number"
  default      = 3333
  mutable      = true
}

data "coder_parameter" "openclaw_workdir" {
  name         = "05_openclaw_workdir"
  display_name = "[OpenClaw] Directorio de trabajo"
  description  = "Directorio desde el que se ejecuta OpenClaw."
  type         = "string"
  default      = "/home/coder/Projects"
  mutable      = true
}

locals {
  username                   = data.coder_workspace_owner.me.name
  workspace_image            = "ghcr.io/makespacemadrid/coder-mks-developer:latest"
  enable_gpu                 = data.coder_parameter.enable_gpu.value
  enable_dri                 = data.coder_parameter.enable_dri.value
  persist_home_storage       = data.coder_parameter.persist_home_storage.value
  persist_projects_storage   = data.coder_parameter.persist_projects_storage.value
  host_mount_path            = trimspace(data.coder_parameter.host_mount_path.value)
  host_mount_uid             = trimspace(data.coder_parameter.host_mount_uid.value)
  workspace_storage_root     = trimspace(var.users_storage)
  workspace_storage_home     = local.workspace_storage_root != "" ? "${local.workspace_storage_root}/${local.username}/${lower(data.coder_workspace.me.name)}" : ""
  workspace_storage_projects = local.workspace_storage_root != "" ? "${local.workspace_storage_root}/${local.username}/${lower(data.coder_workspace.me.name)}/Projects" : ""
  home_mount_host_path       = local.persist_home_storage && local.workspace_storage_root != "" ? local.workspace_storage_home : ""
  projects_mount_host_path   = local.persist_projects_storage && local.workspace_storage_root != "" ? local.workspace_storage_projects : ""
  opencode_default_base_url  = trimspace(var.opencode_default_base_url)
  mks_key_endpoint           = trimspace(var.mks_key_endpoint)
  openai_base_url            = trimspace(data.coder_parameter.opencode_provider_url.value)
  openai_api_key             = trimspace(data.coder_parameter.opencode_api_key.value)
  auto_provision_mks_key     = data.coder_parameter.autoprovision_mks_key.value
  openclaw_autostart         = data.coder_parameter.openclaw_autostart.value
  openclaw_port              = data.coder_parameter.openclaw_port.value
  openclaw_gateway_token     = random_password.openclaw_gateway_token.result
  openclaw_workdir           = trimspace(data.coder_parameter.openclaw_workdir.value)
  openclaw_workdir_resolved  = local.openclaw_workdir != "" ? local.openclaw_workdir : "/home/coder/Projects"
}

resource "random_password" "openclaw_gateway_token" {
  length  = 48
  special = false
}

provider "docker" {
  host = var.docker_socket != "" ? var.docker_socket : null
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  startup_script = <<-EOT
    set -e

    # Levantar dbus (necesario para apps Electron/navegadores en entorno grafico)
    if ! pgrep -x dbus-daemon >/dev/null 2>&1; then
      sudo mkdir -p /run/dbus
      sudo dbus-daemon --system --fork || true
    fi

    # Audio basico para sesiones KasmVNC
    sudo usermod -aG audio "$USER" || true
    mkdir -p ~/.config/pulse
    if [ ! -f ~/.config/pulse/client.conf ]; then
      cat > ~/.config/pulse/client.conf <<'PULSECFG'
autospawn = yes
daemon-binary = /usr/bin/pulseaudio
enable-shm = false
PULSECFG
    fi
    if ! pgrep -u "$USER" pulseaudio >/dev/null 2>&1; then
      pulseaudio --start --exit-idle-time=-1 || true
    fi

    # Asegurar /home/coder como HOME efectivo incluso si se ejecuta como root
    sudo mkdir -p /home/coder
    sudo chown "$USER:$USER" /home/coder || true

    if [ "${tostring(local.enable_dri)}" = "true" ]; then
      # Alinear grupos para /dev/dri (rendering GPU) sin tocar permisos del host
      for dev in /dev/dri/renderD128 /dev/dri/card0; do
        if [ -e "$dev" ]; then
          dev_gid=$(stat -c '%g' "$dev" 2>/dev/null || echo "")
          if [ -n "$dev_gid" ]; then
            dev_group=$(getent group "$dev_gid" | cut -d: -f1)
            if [ -z "$dev_group" ]; then
              dev_group="hostgpu_$dev_gid"
              if ! getent group "$dev_group" >/dev/null; then
                sudo groupadd -g "$dev_gid" "$dev_group" || true
              fi
            fi
            sudo usermod -aG "$dev_group" "$USER" || true
          fi
          if command -v setfacl >/dev/null 2>&1; then
            sudo setfacl -m "u:$USER:rw" "$dev" 2>/dev/null || true
          fi
        fi
      done
    fi

    # Configurar PATH para .local/bin (siempre útil)
    mkdir -p /home/coder/.local/bin
    if [ ! -f /home/coder/.profile ]; then
      echo '# ~/.profile: executed by the command interpreter for login shells.' > /home/coder/.profile
      echo 'if [ -n "$BASH_VERSION" ]; then' >> /home/coder/.profile
      echo '    if [ -f "$HOME/.bashrc" ]; then' >> /home/coder/.profile
      echo '        . "$HOME/.bashrc"' >> /home/coder/.profile
      echo '    fi' >> /home/coder/.profile
      echo 'fi' >> /home/coder/.profile
    fi

    if ! grep -q "/.local/bin" /home/coder/.profile 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/coder/.profile
    fi

    mkdir -p ~/Projects
    python3 - <<'PY'
import json
import os

paths = [
    os.path.expanduser("~/Projects/.vscode/settings.json"),
    os.path.expanduser("~/.vscode-server/data/Machine/settings.json"),
]
for path in paths:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = {}
    if os.path.exists(path):
        try:
            with open(path) as f:
                data = json.load(f)
        except Exception:
            data = {}
    data["terminal.integrated.cwd"] = "/home/coder/Projects"
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
PY
    mkdir -p ~/.opencode ~/.config/opencode
    if [ ! -f ~/.opencode/opencode.json ]; then
      cat > ~/.opencode/opencode.json <<'JSONCFG'
{}
JSONCFG
    fi
    ln -sf ~/.opencode/opencode.json ~/.opencode/config.json || true
    ln -sf ~/.opencode/opencode.json ~/.config/opencode/opencode.json || true

    # Asegurar permisos de pipx para el usuario actual
    sudo mkdir -p /opt/pipx /opt/pipx/bin
    sudo chown -R "$USER:$USER" /opt/pipx || true

    # Inicializar /etc/skel la primera vez
    if [ ! -f ~/.init_done ]; then
      cp -rT /etc/skel ~ || true
      touch ~/.init_done
    fi

    # Autoprovisionar clave OpenCode MakeSpace si está habilitado
    auto_flag="$${AUTO_PROVISION_MKS_API_KEY:-true}"
    if [ -z "$${OPENCODE_PROVIDER_URL:-}" ] && [ -n "$${OPENCODE_DEFAULT_BASE_URL:-}" ]; then
      OPENCODE_PROVIDER_URL="$${OPENCODE_DEFAULT_BASE_URL}"
      export OPENCODE_PROVIDER_URL
    fi
    if printf '%s' "$auto_flag" | grep -Eq '^(1|true|TRUE|yes|on)$'; then
      MKS_BASE_URL="$${MKS_BASE_URL:-$OPENCODE_PROVIDER_URL}"
      export MKS_BASE_URL
      payload=""
      if [ -z "$${OPENCODE_API_KEY:-}" ]; then
        KEY_ENDPOINT="$${MKS_KEY_ENDPOINT:-}"
        if [ -z "$KEY_ENDPOINT" ]; then
          echo "MKS_KEY_ENDPOINT no configurado; omitiendo autoprovision de key" >&2
        else
          alias="coder-$(tr -dc 0-9 </dev/urandom 2>/dev/null | head -c 8 | sed 's/^$/00000000/')"
          payload=$(printf '{"email":"%s","alias":"%s"}' "$${CODER_USER_EMAIL:-}" "$alias")
          resp=$(curl -fsSL -X POST "$KEY_ENDPOINT" -H "Content-Type: application/json" -d "$payload" 2>/dev/null || true)
          key=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("key",""))' 2>/dev/null || true)
          if [ -n "$key" ]; then
            OPENCODE_API_KEY="$key"
            export OPENCODE_API_KEY
            MKS_API_KEY="$key"
            export MKS_API_KEY
            mkdir -p /home/coder/.opencode
            printf "%s" "$key" > /home/coder/.opencode/.latest_mks_key || true
            printf "%s" "$payload" > /home/coder/.opencode/.latest_mks_request || true
          fi
        fi
      fi
      if [ -n "$${OPENCODE_API_KEY:-}" ]; then
        export OPENCODE_API_KEY
        MKS_API_KEY="$${MKS_API_KEY:-$OPENCODE_API_KEY}"
        export MKS_API_KEY
        mkdir -p /home/coder/.opencode
        if [ -n "$payload" ] && [ -n "$${OPENCODE_API_KEY:-}" ]; then
          printf "%s" "$${OPENCODE_API_KEY:-}" > /home/coder/.opencode/.latest_mks_key || true
          printf "%s" "$payload" > /home/coder/.opencode/.latest_mks_request || true
        fi
      fi
    fi

    # Propagar variables a nuevas shells interactivas
    if [ -n "$${OPENCODE_PROVIDER_URL:-}" ]; then
      MKS_BASE_URL="$${MKS_BASE_URL:-$OPENCODE_PROVIDER_URL}"
      export MKS_BASE_URL
      if ! grep -q "MKS_BASE_URL=" ~/.bashrc 2>/dev/null; then
        echo "export MKS_BASE_URL=\"$MKS_BASE_URL\"" >> ~/.bashrc
      fi
      if ! grep -q "OPENCODE_PROVIDER_URL=" ~/.bashrc 2>/dev/null; then
        echo "export OPENCODE_PROVIDER_URL=\"$OPENCODE_PROVIDER_URL\"" >> ~/.bashrc
      fi
    fi
    if [ -n "$${OPENCODE_API_KEY:-}" ]; then
      MKS_API_KEY="$${MKS_API_KEY:-$OPENCODE_API_KEY}"
      export MKS_API_KEY
      if ! grep -q "MKS_API_KEY=" ~/.bashrc 2>/dev/null; then
        echo "export MKS_API_KEY=\"$MKS_API_KEY\"" >> ~/.bashrc
      fi
      if ! grep -q "OPENCODE_API_KEY=" ~/.bashrc 2>/dev/null; then
        echo "export OPENCODE_API_KEY=\"$OPENCODE_API_KEY\"" >> ~/.bashrc
      fi
    fi

    # GitHub CLI (instalar si falta)
    if ! command -v gh >/dev/null 2>&1; then
      echo ">> Installing GitHub CLI (gh)..."
      sudo install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh
    fi

    # Docker Engine: instalar si falta y arrancar dockerd (DinD)
    if ! command -v dockerd >/dev/null 2>&1; then
      echo ">> Installing Docker (docker.io)..."
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
    fi

    # Cgroup v2: delegar controladores para Docker in Docker (evita modo threaded)
    if [ -f /sys/fs/cgroup/cgroup.controllers ]; then
      echo ">> Enabling cgroup v2 delegation for DinD..."
      sudo mkdir -p /sys/fs/cgroup/init
      if [ ! -w /sys/fs/cgroup/init/cgroup.procs ] || [ ! -w /sys/fs/cgroup/cgroup.subtree_control ]; then
        echo ">> cgroup v2 not writable; skipping delegation (likely already handled by host)"
      else
        for _ in $(seq 1 20); do
          sudo xargs -rn1 < /sys/fs/cgroup/cgroup.procs > /sys/fs/cgroup/init/cgroup.procs 2>/dev/null || true
          if sudo sh -c 'sed -e "s/ / +/g" -e "s/^/+/" < /sys/fs/cgroup/cgroup.controllers > /sys/fs/cgroup/cgroup.subtree_control'; then
            break
          fi
          sleep 0.1
        done
      fi
    fi

    if ! pgrep dockerd >/dev/null 2>&1; then
      echo ">> Starting dockerd (DinD)..."
      sudo dockerd --host=unix:///var/run/docker.sock --storage-driver=overlay2 >/tmp/dockerd.log 2>&1 &
      for i in $(seq 1 30); do
        if sudo docker info >/dev/null 2>&1; then
          echo ">> dockerd ready"
          break
        fi
        sleep 1
      done
    fi

    # Navegador para escritorio basico (preferencia: Google Chrome)
    if ! command -v google-chrome >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1 && ! command -v chromium-browser >/dev/null 2>&1; then
      echo ">> Installing browser for desktop session..."
      sudo apt-get update -y || true
      sudo apt-get install -y ca-certificates curl gnupg || true
      if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
        sudo install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg || true
        sudo chmod a+r /etc/apt/keyrings/google-chrome.gpg || true
      fi
      if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
          | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null || true
      fi
      sudo apt-get update -y || true
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y google-chrome-stable || \
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser || \
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y chromium || true
    fi

    # OpenClaw requiere Node >= 22.12.0
    ensure_node22=false
    if ! command -v node >/dev/null 2>&1; then
      ensure_node22=true
    else
      node_ver=$(node -p 'process.versions.node' 2>/dev/null || echo "0.0.0")
      min_node_ver="22.12.0"
      if [ "$(printf '%s\n%s\n' "$min_node_ver" "$node_ver" | sort -V | head -n1)" != "$min_node_ver" ]; then
        ensure_node22=true
      fi
    fi
    if [ "$ensure_node22" = "true" ]; then
      echo ">> Installing/upgrading Node.js 22.x (required by OpenClaw)..."
      sudo apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
      hash -r || true
      node -v || true
    fi

    # OpenClaw: instalación oficial no interactiva (si hace falta)
    export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
    if ! grep -q "/.npm-global/bin" /home/coder/.profile 2>/dev/null; then
      echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> /home/coder/.profile
    fi
    if ! grep -q "/.npm-global/bin" /home/coder/.bashrc 2>/dev/null; then
      echo 'export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"' >> /home/coder/.bashrc
    fi
    if [ "$${OPENCLAW_AUTOSTART:-false}" = "true" ] && ! command -v openclaw >/dev/null 2>&1; then
      echo ">> Installing OpenClaw (official installer)..."
      if ! OPENCLAW_NO_PROMPT=1 OPENCLAW_NO_ONBOARD=1 OPENCLAW_USE_GUM=0 curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-prompt --no-onboard --no-gum; then
        echo "WARN: instalación de OpenClaw falló. Revisa red/permisos y relanza el workspace." >&2
      fi
      export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
    fi
    # No actualizar OpenClaw automáticamente en startup:
    # puede tardar mucho y bloquear el arranque del gateway/app.
    # Si necesitas actualizar, hazlo manualmente con:
    #   openclaw update --yes --no-restart

    if command -v openclaw >/dev/null 2>&1; then
      openclaw config set gateway.auth.mode token >/dev/null 2>&1 || true
      openclaw config set gateway.auth.token "$${OPENCLAW_GATEWAY_TOKEN:-}" >/dev/null 2>&1 || true
    fi

    # Persistir configuración de OpenClaw para invocaciones manuales posteriores
    mkdir -p "$HOME/.local/state/openclaw"
    cat > "$HOME/.local/state/openclaw/runtime.env" <<EOF
OPENCLAW_PORT="$${OPENCLAW_PORT:-3333}"
OPENCLAW_GATEWAY_TOKEN="$${OPENCLAW_GATEWAY_TOKEN:-}"
OPENCLAW_WORKDIR="$${OPENCLAW_WORKDIR:-$HOME/Projects}"
EOF
    chmod 600 "$HOME/.local/state/openclaw/runtime.env"

    # Script de OpenClaw (siempre disponible)
    mkdir -p "$HOME/.local/state/openclaw"
    touch "$HOME/.local/state/openclaw/openclaw.log"
    cat > "$HOME/.local/bin/start-openclaw" <<'OPENCLAWSTART'
#!/usr/bin/env bash
set -euo pipefail
STATE_DIR="$HOME/.local/state/openclaw"
ENV_FILE="$STATE_DIR/runtime.env"
LOG_FILE="$STATE_DIR/openclaw.log"
PID_FILE="$STATE_DIR/openclaw.pid"
mkdir -p "$STATE_DIR"

if [ -f "$ENV_FILE" ]; then
  # Cargar token/puerto/workdir persistidos por el startup script del agente.
  set -a
  . "$ENV_FILE"
  set +a
fi

OPENCLAW_PORT="$${OPENCLAW_PORT:-3333}"
OPENCLAW_WORKDIR="$${OPENCLAW_WORKDIR:-$HOME/Projects}"

if [ -z "$${OPENCLAW_GATEWAY_TOKEN:-}" ]; then
  echo "OPENCLAW_GATEWAY_TOKEN no definido. Rebuild/start del workspace para regenerar la configuración." >&2
  exit 1
fi

if curl -fsS --max-time 1 "http://127.0.0.1:$OPENCLAW_PORT/" >/dev/null 2>&1; then
  echo "OpenClaw ya está escuchando en :$OPENCLAW_PORT"
  exit 0
fi

cd "$OPENCLAW_WORKDIR" 2>/dev/null || cd "$HOME/Projects"
ulimit -n 65536 >/dev/null 2>&1 || true
nohup openclaw gateway run --allow-unconfigured --port "$OPENCLAW_PORT" --auth token --token "$OPENCLAW_GATEWAY_TOKEN" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

for _ in $(seq 1 90); do
  if curl -fsS --max-time 1 "http://127.0.0.1:$OPENCLAW_PORT/" >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done

echo "OpenClaw no respondió en :$OPENCLAW_PORT tras 90s. Revisa $LOG_FILE" >&2
exit 1
OPENCLAWSTART
    chmod +x "$HOME/.local/bin/start-openclaw"

    # OpenClaw opcional: arranque determinista antes de finalizar startup.
    if [ "$${OPENCLAW_AUTOSTART:-false}" = "true" ]; then
      if ! "$HOME/.local/bin/start-openclaw"; then
        echo "WARN: no se pudo arrancar OpenClaw automáticamente. Revisa ~/.local/state/openclaw/openclaw.log" >&2
      fi
      if command -v openclaw >/dev/null 2>&1; then
        if openclaw health --timeout 3000 >/dev/null 2>&1; then
          echo ">> OpenClaw health OK"
        else
          echo "WARN: openclaw health no respondió tras arranque." >&2
        fi
      fi
    else
      echo "INFO: OpenClaw autostart deshabilitado (OPENCLAW_AUTOSTART=false)." >&2
    fi

  EOT

  env = {
    GIT_AUTHOR_NAME                 = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL                = data.coder_workspace_owner.me.email
    GIT_COMMITTER_NAME              = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL             = data.coder_workspace_owner.me.email
    HOME                            = "/home/coder"
    OPENCODE_PROVIDER_URL           = local.openai_base_url
    OPENCODE_API_KEY                = local.openai_api_key
    OPENCODE_DEFAULT_BASE_URL       = local.opencode_default_base_url
    MKS_KEY_ENDPOINT                = local.mks_key_endpoint
    MKS_BASE_URL                    = local.openai_base_url
    MKS_API_KEY                     = local.openai_api_key
    AUTO_PROVISION_MKS_API_KEY      = tostring(local.auto_provision_mks_key)
    CODER_USER_EMAIL                = data.coder_workspace_owner.me.email
    OPENCLAW_AUTOSTART              = tostring(local.openclaw_autostart)
    OPENCLAW_PORT                   = tostring(local.openclaw_port)
    OPENCLAW_GATEWAY_TOKEN          = local.openclaw_gateway_token
    OPENCLAW_WORKDIR                = local.openclaw_workdir_resolved
  }
}

module "kasmvnc" {
  count               = data.coder_workspace.me.start_count
  source              = "registry.coder.com/coder/kasmvnc/coder"
  version             = "~> 1.2"
  agent_id            = coder_agent.main.id
  desktop_environment = "xfce"
  subdomain           = true
}

module "git-config" {
  count    = data.coder_workspace.me.start_count
  source   = "registry.coder.com/coder/git-config/coder"
  version  = "~> 1.0"
  agent_id = coder_agent.main.id
}

module "git-clone" {
  count    = data.coder_parameter.git_repo_url.value != "" ? data.coder_workspace.me.start_count : 0
  source   = "registry.coder.com/coder/git-clone/coder"
  version  = "~> 1.2"
  agent_id = coder_agent.main.id
  url      = data.coder_parameter.git_repo_url.value
  base_dir = "~/Projects"
}

resource "coder_app" "openclaw_ui" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main.id
  slug         = "openclaw-ui"
  display_name = "OpenClaw UI"
  icon         = "/icon/folder.svg"
  url          = "http://localhost:${local.openclaw_port}/?token=${urlencode(local.openclaw_gateway_token)}"
  subdomain    = true
  order        = 1
  open_in      = "tab"

  healthcheck {
    url       = "http://localhost:${local.openclaw_port}/"
    interval  = 5
    threshold = 6
  }
}

resource "docker_volume" "home_volume" {
  count = local.home_mount_host_path == "" ? 1 : 0
  name  = "coder-${data.coder_workspace.me.id}-home"

  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "docker_volume" "docker_data" {
  name = "coder-${data.coder_workspace.me.id}-docker-data"

  lifecycle {
    ignore_changes = all
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "null_resource" "ensure_host_paths" {
  count = (local.home_mount_host_path != "" || local.projects_mount_host_path != "" || local.host_mount_path != "") ? 1 : 0
  triggers = {
    home     = local.home_mount_host_path
    projects = local.projects_mount_host_path
    host     = local.host_mount_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      if [ -n "${self.triggers.home}" ]; then mkdir -p "${self.triggers.home}"; fi
      if [ -n "${self.triggers.projects}" ]; then mkdir -p "${self.triggers.projects}"; fi
      if [ -n "${self.triggers.host}" ]; then mkdir -p "${self.triggers.host}"; fi
    EOT
  }
}

resource "docker_container" "workspace" {
  depends_on = [null_resource.ensure_host_paths]
  image      = local.workspace_image

  name     = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  hostname = data.coder_workspace.me.name

  user = local.host_mount_path != "" ? local.host_mount_uid : "coder"

  privileged = true

  entrypoint = [
    "sh",
    "-c",
    <<-EOT
      set -e
      mkdir -p /home/coder/.opencode /home/coder/.config/opencode
      if [ ! -f /home/coder/.opencode/opencode.json ]; then
        printf '{}' > /home/coder/.opencode/opencode.json
      fi
      ln -sf /home/coder/.opencode/opencode.json /home/coder/.opencode/config.json || true
      ln -sf /home/coder/.opencode/opencode.json /home/coder/.config/opencode/opencode.json || true
      ${replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")}
    EOT
  ]

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "TZ=Europe/Madrid",
    "NVIDIA_VISIBLE_DEVICES=${local.enable_gpu ? "all" : ""}",
    "NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics,video"
  ]
  gpus = local.enable_gpu ? "all" : null
  dynamic "devices" {
    for_each = local.enable_dri ? ["/dev/dri"] : []
    content {
      host_path      = devices.value
      container_path = devices.value
      permissions    = "rwm"
    }
  }

  shm_size = 2 * 1024 * 1024 * 1024

  dynamic "mounts" {
    for_each = local.home_mount_host_path != "" ? [local.home_mount_host_path] : []
    content {
      target = "/home/coder"
      type   = "bind"
      source = mounts.value
    }
  }

  dynamic "volumes" {
    for_each = local.home_mount_host_path == "" ? [docker_volume.home_volume[0].name] : []
    content {
      container_path = "/home/coder"
      volume_name    = volumes.value
    }
  }

  dynamic "mounts" {
    for_each = local.projects_mount_host_path != "" ? [local.projects_mount_host_path] : []
    content {
      target = "/home/coder/Projects"
      type   = "bind"
      source = mounts.value
    }
  }

  dynamic "mounts" {
    for_each = local.host_mount_path != "" ? [local.host_mount_path] : []
    content {
      target = "/home/coder/host"
      type   = "bind"
      source = mounts.value
    }
  }

  volumes {
    container_path = "/var/lib/docker"
    volume_name    = docker_volume.docker_data.name
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
  labels {
    label = "com.centurylinklabs.watchtower.enable"
    value = "true"
  }
  labels {
    label = "com.centurylinklabs.watchtower.scope"
    value = "coder-workspaces"
  }
}
