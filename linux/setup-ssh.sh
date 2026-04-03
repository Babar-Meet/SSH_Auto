#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[SSH-SETUP] $1"
}

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

TARGET_USER="${SUDO_USER:-$USER}"
if command -v getent >/dev/null 2>&1; then
  TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
else
  TARGET_HOME="$(eval echo "~${TARGET_USER}")"
fi

if [[ -z "${TARGET_HOME}" || ! -d "${TARGET_HOME}" ]]; then
  TARGET_HOME="$HOME"
fi

SSH_DIR="${TARGET_HOME}/.ssh"
PRIVATE_KEY="${SSH_DIR}/id_ed25519"
PUBLIC_KEY="${PRIVATE_KEY}.pub"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"

install_ssh_package() {
  if command -v apt-get >/dev/null 2>&1; then
    log "Detected apt package manager."
    ${SUDO} apt-get update
    ${SUDO} apt-get install -y openssh-server
  elif command -v dnf >/dev/null 2>&1; then
    log "Detected dnf package manager."
    ${SUDO} dnf install -y openssh-server
  elif command -v pacman >/dev/null 2>&1; then
    log "Detected pacman package manager."
    ${SUDO} pacman -Sy --noconfirm openssh
  else
    echo "[ERROR] Unsupported package manager. Supported: apt, dnf, pacman."
    exit 1
  fi
}

detect_service_name() {
  if ${SUDO} systemctl list-unit-files | grep -q '^ssh\.service'; then
    echo "ssh"
  elif ${SUDO} systemctl list-unit-files | grep -q '^sshd\.service'; then
    echo "sshd"
  elif ${SUDO} systemctl status ssh >/dev/null 2>&1; then
    echo "ssh"
  else
    echo "sshd"
  fi
}

set_sshd_option() {
  local key="$1"
  local value="$2"

  if ${SUDO} grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "${SSHD_CONFIG}"; then
    ${SUDO} sed -i -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "${SSHD_CONFIG}"
  else
    echo "${key} ${value}" | ${SUDO} tee -a "${SSHD_CONFIG}" >/dev/null
  fi
}

log "Installing OpenSSH..."
install_ssh_package

SERVICE_NAME="$(detect_service_name)"

log "Starting SSH service (${SERVICE_NAME})..."
${SUDO} systemctl start "${SERVICE_NAME}"

log "Enabling SSH service on boot (${SERVICE_NAME})..."
${SUDO} systemctl enable "${SERVICE_NAME}"

log "Ensuring password and key login stay enabled..."
set_sshd_option "PasswordAuthentication" "yes"
set_sshd_option "PubkeyAuthentication" "yes"

log "Preparing ${SSH_DIR}..."
mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"

if [[ ! -f "${PRIVATE_KEY}" ]]; then
  log "Generating SSH key pair..."
  ssh-keygen -t ed25519 -N "" -f "${PRIVATE_KEY}"
else
  log "SSH key already exists. Keeping existing key."
fi

if [[ ! -f "${PUBLIC_KEY}" ]]; then
  log "Public key missing. Recreating from private key..."
  ssh-keygen -y -f "${PRIVATE_KEY}" > "${PUBLIC_KEY}"
fi

touch "${AUTHORIZED_KEYS}"
chmod 600 "${AUTHORIZED_KEYS}"
chmod 644 "${PUBLIC_KEY}"

PUB_KEY_CONTENT="$(cat "${PUBLIC_KEY}")"
if ! grep -qxF "${PUB_KEY_CONTENT}" "${AUTHORIZED_KEYS}"; then
  log "Adding public key to authorized_keys..."
  echo "${PUB_KEY_CONTENT}" >> "${AUTHORIZED_KEYS}"
else
  log "Public key already exists in authorized_keys."
fi

chmod 700 "${SSH_DIR}"
chmod 600 "${AUTHORIZED_KEYS}"

if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
  chown -R "${SUDO_USER}:${SUDO_USER}" "${SSH_DIR}"
fi

log "Restarting SSH service (${SERVICE_NAME})..."
${SUDO} systemctl restart "${SERVICE_NAME}"

log "SSH setup complete."
log "Connect with: ssh ${TARGET_USER}@ip-address"
log "Port: 22"
log "Password and key login are both enabled."
