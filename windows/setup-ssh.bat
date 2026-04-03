@echo off
setlocal

echo ==================================================
echo SSH Setup Toolkit for Windows
echo ==================================================
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run this script as Administrator.
    echo Right-click setup-ssh.bat and choose "Run as administrator".
    exit /b 1
)

echo [1/10] Installing OpenSSH Server and Client...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$capabilities = @('OpenSSH.Server~~~~0.0.1.0','OpenSSH.Client~~~~0.0.1.0'); foreach ($capName in $capabilities) { $cap = Get-WindowsCapability -Online -Name $capName; if ($cap.State -ne 'Installed') { Add-WindowsCapability -Online -Name $capName | Out-Null; Write-Host ($capName + ' installed.') } else { Write-Host ($capName + ' already installed.') } }"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install OpenSSH components.
    exit /b 1
)

echo [2/10] Setting sshd service to start automatically...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-Service -Name sshd -StartupType Automatic"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to set sshd startup type.
    exit /b 1
)

echo [3/10] Starting sshd service...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Service -Name sshd"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to start sshd service.
    exit /b 1
)

echo [4/10] Adding firewall rule for port 22...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "if (-not (Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null; Write-Host 'Firewall rule created.' } else { Write-Host 'Firewall rule already exists.' }"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to configure firewall rule.
    exit /b 1
)

echo [5/10] Ensuring password + key login and ListenAddress are enabled...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$config = Join-Path $env:ProgramData 'ssh\sshd_config'; if (-not (Test-Path $config)) { New-Item -Path $config -ItemType File -Force | Out-Null }; $content = Get-Content -Path $config -Raw -ErrorAction SilentlyContinue; if ($null -eq $content) { $content = '' }; if ($content -match '(?m)^\s*#?\s*PasswordAuthentication\s+\S+') { $content = [regex]::Replace($content, '(?m)^\s*#?\s*PasswordAuthentication\s+\S+', 'PasswordAuthentication yes') } else { $content = ($content.TrimEnd() + [Environment]::NewLine + 'PasswordAuthentication yes') }; if ($content -match '(?m)^\s*#?\s*PubkeyAuthentication\s+\S+') { $content = [regex]::Replace($content, '(?m)^\s*#?\s*PubkeyAuthentication\s+\S+', 'PubkeyAuthentication yes') } else { $content = ($content.TrimEnd() + [Environment]::NewLine + 'PubkeyAuthentication yes') }; if ($content -match '(?m)^\s*#?\s*ListenAddress\s+\S+') { $content = [regex]::Replace($content, '(?m)^\s*#?\s*ListenAddress\s+\S+', 'ListenAddress 0.0.0.0') } else { $content = ($content.TrimEnd() + [Environment]::NewLine + 'ListenAddress 0.0.0.0') }; Set-Content -Path $config -Value ($content.TrimEnd() + [Environment]::NewLine) -Encoding ascii"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to update sshd_config.
    exit /b 1
)

echo [6/10] Creating .ssh folder if needed...
if not exist "%USERPROFILE%\.ssh" (
    mkdir "%USERPROFILE%\.ssh"
)

echo [7/10] Generating SSH key (ed25519) if needed...
if not exist "%USERPROFILE%\.ssh\id_ed25519" (
    if exist "%WINDIR%\System32\OpenSSH\ssh-keygen.exe" (
        "%WINDIR%\System32\OpenSSH\ssh-keygen.exe" -t ed25519 -N "" -f "%USERPROFILE%\.ssh\id_ed25519"
    ) else (
        ssh-keygen -t ed25519 -N "" -f "%USERPROFILE%\.ssh\id_ed25519"
    )
) else (
    echo Existing key found. Skipping key generation.
)
if %errorlevel% neq 0 (
    echo [ERROR] Failed to generate SSH key.
    exit /b 1
)

echo [8/10] Adding public key to authorized_keys...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$sshDir = Join-Path $env:USERPROFILE '.ssh'; $pubPath = Join-Path $sshDir 'id_ed25519.pub'; $authPath = Join-Path $sshDir 'authorized_keys'; if (-not (Test-Path $authPath)) { New-Item -Path $authPath -ItemType File -Force | Out-Null }; $pub = (Get-Content -Path $pubPath -Raw).Trim(); $existing = @(); if (Test-Path $authPath) { $existing = Get-Content -Path $authPath }; if ($existing -notcontains $pub) { Add-Content -Path $authPath -Value $pub; Write-Host 'Public key added.' } else { Write-Host 'Public key already present.' }"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to update authorized_keys.
    exit /b 1
)

echo [9/10] Setting secure permissions on .ssh files...
icacls "%USERPROFILE%\.ssh" /inheritance:r /grant:r "%USERNAME%:(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" /T >nul
icacls "%USERPROFILE%\.ssh\authorized_keys" /inheritance:r /grant:r "%USERNAME%:F" "SYSTEM:F" "Administrators:F" >nul

echo [10/10] Restarting sshd service...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Restart-Service -Name sshd"
if %errorlevel% neq 0 (
    echo [ERROR] Failed to restart sshd service.
    exit /b 1
)

echo.
echo SSH setup is complete.
echo You can connect from another machine with:
echo   ssh %USERNAME%@ip-address
echo Port: 22
echo Both password and SSH key login are enabled.
