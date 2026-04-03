# Windows SSH Setup

This script installs and configures SSH server on Windows in one run.

## Run as Administrator

1. Open Start Menu.
2. Search for Command Prompt.
3. Right-click Command Prompt and choose **Run as administrator**.
4. Go to the script folder.
5. Run the script.

## One-step execution

From an Administrator Command Prompt, run:

    cd path\to\ssh-setup\windows
    setup-ssh.bat

## What the script does

- Installs OpenSSH Server (and client tools if missing).
- Starts the sshd service.
- Sets sshd to automatic startup on boot.
- Opens Windows Firewall port 22.
- Creates %USERPROFILE%\.ssh if needed.
- Generates an ed25519 key pair automatically.
- Adds your public key to authorized_keys.
- Keeps both password login and key login enabled.
- Restarts the SSH service.

## Find your IP address

Run:

    ipconfig

Use your active adapter IPv4 address.

## Connect from another machine

    ssh username@ip-address

- Default SSH port is 22.
- Password login works.
- Key login also works (faster and usually no password prompt if your key is used).
