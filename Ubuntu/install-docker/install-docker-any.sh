#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# Helpers
# ----------------------------

log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "This script must be run as root. Try: sudo $0"
    exit 1
  fi
}

detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID=${ID:-unknown}
    OS_LIKE=${ID_LIKE:-}
    OS_VERSION=${VERSION_ID:-}
  else
    err "/etc/os-release not found, cannot detect OS."
    exit 1
  fi

  log "Detected OS: id=$OS_ID, like=$OS_LIKE, version=$OS_VERSION"
}

# ----------------------------
# Install for Debian/Ubuntu
# ----------------------------
install_docker_debian() {
  log "Using Debian/Ubuntu install path"

  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release

  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    # Pick correct Docker OS for repo
    local DOCKER_OS="ubuntu"
    if [ "$OS_ID" = "debian" ]; then
      DOCKER_OS="debian"
    fi

    curl -fsSL https://download.docker.com/linux/${DOCKER_OS}/gpg | \
      gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  fi
  chmod a+r /etc/apt/keyrings/docker.gpg

  local CODENAME
  CODENAME=$(lsb_release -cs)

  cat > /etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${OS_ID} ${CODENAME} stable
EOF

  apt-get update -y
  apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
}

# ----------------------------
# Install for RHEL / CentOS / Rocky / Alma
# ----------------------------
install_docker_rhel() {
  log "Using RHEL/CentOS/Rocky/Alma install path"

  if command -v dnf >/dev/null 2>&1; then
    dnf -y install dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf -y install \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-compose-plugin || true
  else
    yum -y install yum-utils
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum -y install \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-compose-plugin || true
  fi
}

# ----------------------------
# Install for Fedora
# ----------------------------
install_docker_fedora() {
  log "Using Fedora install path"

  dnf -y install dnf-plugins-core
  dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
  dnf -y install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin || true
}

# ----------------------------
# Fallback: standalone docker-compose binary
# ----------------------------
install_standalone_compose() {
  if command -v docker-compose >/dev/null 2>&1; then
    log "docker-compose already installed (standalone). Skipping."
    return
  fi

  warn "docker compose plugin not available. Installing standalone docker-compose binary."

  local DEST="/usr/local/bin/docker-compose"
  local URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"

  curl -L "$URL" -o "$DEST"
  chmod +x "$DEST"

  log "Standalone docker-compose installed: $(docker-compose --version || echo 'unknown version')"
}

# ----------------------------
# Configure Docker daemon
# ----------------------------
configure_daemon() {
  log "Configuring /etc/docker/daemon.json"

  mkdir -p /etc/docker

  cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "live-restore": true
}
EOF
}

# ----------------------------
# Enable service & add user
# ----------------------------
enable_docker_service() {
  systemctl enable docker
  systemctl restart docker
}

add_user_to_docker_group() {
  local target_user="$SUDO_USER"
  if [ -z "$target_user" ]; then
    target_user=$(logname 2>/dev/null || echo "")
  fi

  if [ -z "$target_user" ]; then
    warn "Could not determine non-root user to add to docker group. Skipping."
    return
  fi

  log "Adding user '$target_user' to docker group"
  usermod -aG docker "$target_user" || warn "Failed to add user $target_user to docker group"
}

# ----------------------------
# Main
# ----------------------------
main() {
  require_root
  detect_os

  case "$OS_ID" in
    ubuntu|debian)
      install_docker_debian
      ;;
    rhel|centos|rocky|almalinux)
      install_docker_rhel
      ;;
    fedora)
      install_docker_fedora
      ;;
    *)
      # Try OS_LIKE if ID is unknown
      if echo "$OS_LIKE" | grep -qi "debian"; then
        install_docker_debian
      elif echo "$OS_LIKE" | grep -Eqi "rhel|fedora|centos"; then
        install_docker_rhel
      else
        err "Unsupported or untested OS: $OS_ID (like: $OS_LIKE). Exiting."
        exit 1
      fi
      ;;
  esac

  configure_daemon
  enable_docker_service

  # Check compose plugin
  if ! docker compose version >/dev/null 2>&1; then
    install_standalone_compose
  else
    log "docker compose plugin is installed: $(docker compose version)"
  fi

  add_user_to_docker_group

  log "Docker installation complete."
  echo
  echo "Docker version: $(docker --version || echo 'not found')"
  echo "Compose plugin: $(docker compose version 2>/dev/null || echo 'not available')"
  echo
  echo ">>> Log out and log back in so your user is in the 'docker' group."
}

main "$@"
