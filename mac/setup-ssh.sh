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

TARGET_USER="${SUDO_USER:-$(whoami)}"
SSH_DIR="${HOME}/.ssh"
PRIVATE_KEY="${SSH_DIR}/id_ed25519"
PUBLIC_KEY="${PRIVATE_KEY}.pub"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"
SSHD_CONFIG="/etc/ssh/sshd_config"

set_sshd_option() {
  local key="$1"
  local value="$2"

  if ${SUDO} grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "${SSHD_CONFIG}"; then
    ${SUDO} sed -i '' -E "s|^[#[:space:]]*${key}[[:space:]]+.*|${key} ${value}|g" "${SSHD_CONFIG}"
  else
    echo "${key} ${value}" | ${SUDO} tee -a "${SSHD_CONFIG}" >/dev/null
  fi
}

log "Enabling Remote Login (SSH)..."
${SUDO} systemsetup -setremotelogin on >/dev/null

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

log "Restarting SSH service..."
if ${SUDO} launchctl print system/com.openssh.sshd >/dev/null 2>&1; then
  ${SUDO} launchctl kickstart -k system/com.openssh.sshd >/dev/null 2>&1 || true
else
  ${SUDO} launchctl stop com.openssh.sshd >/dev/null 2>&1 || true
  ${SUDO} launchctl start com.openssh.sshd >/dev/null 2>&1 || true
fi

log "SSH setup complete."
log "Connect with: ssh ${TARGET_USER}@ip-address"
log "Port: 22"
log "Password and key login are both enabled."
