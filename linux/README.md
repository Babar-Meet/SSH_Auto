# Linux SSH Setup

This script installs and configures SSH server in one run.

## Open Terminal and run

1. Open your Terminal app.
2. Go to the script folder.
3. Make the script executable.
4. Run it.

cd path/to/ssh-setup/linux
chmod +x setup-ssh.sh
./setup-ssh.sh

## About sudo password prompt

- The script uses sudo for system setup (install service, enable boot start, update sshd config).
- Your terminal may ask for your sudo password.
- This is normal and required for admin-level changes.

## What the script does

- Detects package manager: apt, dnf, or pacman.
- Installs OpenSSH server package.
- Starts SSH service.
- Enables SSH service on boot.
- Handles service names ssh or sshd automatically.
- Creates ~/.ssh if needed.
- Generates an ed25519 key pair automatically.
- Adds your public key to ~/.ssh/authorized_keys.
- Sets permissions:
  - chmod 700 ~/.ssh
  - chmod 600 ~/.ssh/authorized_keys
- Keeps both password login and key login enabled.
- Restarts SSH service.

## Find your IP address

Use either command:

ip a

or

hostname -I

## Connect from another machine

ssh username@ip-address

- Default SSH port is 22.
- Password login works.
- Key login also works (usually no password prompt when key auth is used).
