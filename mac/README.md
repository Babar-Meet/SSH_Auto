# macOS SSH Setup

This script enables and configures SSH in one run.

## Open Terminal and run

1. Open **Terminal**.
2. Go to the script folder.
3. Make the script executable.
4. Run it.

   cd path/to/ssh-setup/mac
   chmod +x setup-ssh.sh
   ./setup-ssh.sh

## About admin password prompt

- The script uses sudo to enable Remote Login and update system SSH settings.
- macOS may ask for your admin password.
- This is expected for system-level changes.

## What the script does

- Enables Remote Login (systemsetup -setremotelogin on).
- Creates ~/.ssh if needed.
- Generates an ed25519 key pair automatically.
- Adds your public key to ~/.ssh/authorized_keys.
- Applies secure key permissions.
- Keeps both password login and key login enabled.
- Restarts SSH service.

## Find your IP address

Use Terminal command:

    ifconfig

Or open **System Settings** and check your active network connection details.

## Connect from another machine

    ssh username@ip-address

- Default SSH port is 22.
- Password login works.
- Key login also works (faster and often no password prompt).
