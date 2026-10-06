@echo off
setlocal EnableDelayedExpansion
title Setup Claude 3P & 9Router

:: Verifikasi Hak Akses Administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Jalankan script ini sebagai Administrator (Klik kanan -> Run as administrator).
    pause
    exit /b
)

:: ===================================================================
:: STEP 1: RUNTIME (NODEJS, PYTHON, CLAUDE DESKTOP) & HOSTS
:: ===================================================================
echo.
echo [1/4] Memasang Node.js, Python, dan Claude Desktop...

set "HOSTS_FILE=%WINDIR%\System32\drivers\etc\hosts"
findstr /C:"9router" "%HOSTS_FILE%" >nul 2>&1
if %errorlevel% neq 0 echo 127.0.0.1 9router >> "%HOSTS_FILE%"

echo -^> Memeriksa dan memasang Node.js LTS...
where node >nul 2>&1
if %errorlevel% neq 0 (
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
) else (
    echo    Node.js sudah terpasang.
)

echo -^> Memeriksa dan memasang Python 3.12...
where python >nul 2>&1
if %errorlevel% neq 0 (
    winget install Python.Python.3.12 --override "/quiet PrependPath=1" --accept-package-agreements --accept-source-agreements
) else (
    echo    Python sudah terpasang.
)

echo -^> Memeriksa Claude Desktop...
if not exist "%LOCALAPPDATA%\AnthropicClaude\Claude.exe" if not exist "%LOCALAPPDATA%\Programs\Claude\Claude.exe" (
    echo    Membuka link download resmi Claude Desktop di browser...
    start https://claude.ai/redirect/claudeai.v1.f1f00150-1fbd-467c-adfc-2cbccaa0f85f/api/desktop/win32/x64/setup/latest/redirect
) else (
    echo    Claude Desktop sudah terpasang.
)

:: Refresh & Daftarkan PATH secara permanen ke Windows Environment
powershell -NoProfile -Command ^
    "$npm = \"$env:APPDATA\npm\";" ^
    "$uPath = [Environment]::GetEnvironmentVariable('Path', 'User');" ^
    "if ($uPath -notlike \"*$npm*\") { [Environment]::SetEnvironmentVariable('Path', \"$npm;$uPath\", 'User') }" >nul 2>&1

for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
for /f "tokens=2*" %%a in ('reg query "HKCU\Environment" /v Path 2^>nul') do set "USR_PATH=%%b"
set "PATH=%APPDATA%\npm;%ProgramFiles%\nodejs;%SYS_PATH%;%USR_PATH%;%PATH%"

:: Pengecekan Ketat Step 1: Tunggu sampai Node.js benar-benar siap
:WAIT_NODE
where node >nul 2>&1
if %errorlevel% neq 0 (
    timeout /t 2 /nobreak >nul
    for /f "tokens=2*" %%a in ('reg query "HKLM\System\CurrentControlSet\Control\Session Manager\Environment" /v Path 2^>nul') do set "SYS_PATH=%%b"
    set "PATH=!SYS_PATH!;%PATH%"
    goto WAIT_NODE
)

:: ===================================================================
:: STEP 2: INSTALL 9ROUTER & VERIFIKASI SERVICE AKTIF
:: ===================================================================
echo.
echo [2/4] Menyiapkan layanan 9Router...
where 9router >nul 2>&1
if %errorlevel% neq 0 (
    echo -^> Memasang 9Router via npm...
    call npm install -g 9router
) else (
    echo    9Router sudah terpasang via npm (dilewati).
)

:: Daftarkan ke Startup Windows tanpa file .vbs (Anti-Block Smart App Control)
powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\9Router.lnk');$s.TargetPath='powershell.exe';$s.Arguments='-WindowStyle Hidden -Command \"9router --no-browser\"';$s.WindowStyle=7;$s.Save()" >nul 2>&1

powershell -Command "$s=(New-Object -COM WScript.Shell).CreateShortcut('%USERPROFILE%\Desktop\9Router Dashboard.url');$s.TargetPath='http://9router:20128/dashboard';$s.Save()" >nul 2>&1

:: Cek apakah service 9Router sudah aktif di port 20128
powershell -Command "try { $tcp = New-Object Net.Sockets.TcpClient('127.0.0.1', 20128); $tcp.Close(); exit 0 } catch { exit 1 }"
if %errorlevel% equ 0 (
    echo    Service 9Router sudah aktif di port 20128 (dilewati).
) else (
    echo -^> Menjalankan background service 9Router...
    powershell -WindowStyle Hidden -Command "Start-Process cmd -ArgumentList '/c 9router --no-browser' -WindowStyle Hidden"
    powershell -Command "while ($true) { try { $tcp = New-Object Net.Sockets.TcpClient('127.0.0.1', 20128); $tcp.Close(); break } catch { Start-Sleep -Seconds 1 } }"
)

:: Bypass form login dashboard (default password 123456)
powershell -NoProfile -Command ^
    "$ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession;" ^
    "try { Invoke-RestMethod -Uri 'http://localhost:20128/api/auth/login' -Method POST -Body '{\"password\":\"123456\"}' -ContentType 'application/json' -WebSession $ws | Out-Null } catch {};" ^
    "try { Invoke-RestMethod -Uri 'http://localhost:20128/api/settings' -Method PATCH -Body '{\"requireLogin\":false}' -ContentType 'application/json' -WebSession $ws | Out-Null } catch {}" >nul 2>&1

:: ===================================================================
:: STEP 3: LOGIN ANTIGRAVITY & VERIFIKASI KONEKSI AKTIF
:: ===================================================================
echo.
echo [3/4] Memeriksa akun Google Antigravity...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession;" ^
    "try { Invoke-RestMethod -Uri 'http://localhost:20128/api/auth/login' -Method POST -Body '{\"password\":\"123456\"}' -ContentType 'application/json' -WebSession $ws | Out-Null } catch {};" ^
    "try { $conns = (Invoke-RestMethod -Uri 'http://localhost:20128/api/providers' -WebSession $ws).connections; if ($conns | Where-Object { $_.provider -eq 'antigravity' }) { exit 0 } } catch {};" ^
    "try { $conns = (Invoke-RestMethod -Uri 'http://localhost:20128/api/providers').connections; if ($conns | Where-Object { $_.provider -eq 'antigravity' }) { exit 0 } } catch {};" ^
    "$dbs = @(\"$env:APPDATA\9router\db\data.sqlite\", \"$env:USERPROFILE\.9router\db\data.sqlite\");" ^
    "foreach ($db in $dbs) { if (Test-Path $db) { if (Select-String -Path $db -Pattern 'antigravity' -SimpleMatch -Quiet -ErrorAction SilentlyContinue) { exit 0 } } }; exit 1"
if %errorlevel% equ 0 (
    echo    Akun Google Antigravity sudah terhubung (dilewati).
    goto STEP_4
)

echo    Silakan klik '+ Add' di browser untuk login Google...
start http://9router:20128/dashboard/providers/antigravity

:: Pengecekan Ketat Step 3: Validasi akun Google ke API & DB 9Router sebelum lanjut
:CHECK_LOGIN
set /p DUMMY="Tekan ENTER setelah selesai login di browser..."
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ws = New-Object Microsoft.PowerShell.Commands.WebRequestSession;" ^
    "try { Invoke-RestMethod -Uri 'http://localhost:20128/api/auth/login' -Method POST -Body '{\"password\":\"123456\"}' -ContentType 'application/json' -WebSession $ws | Out-Null } catch {};" ^
    "try { $conns = (Invoke-RestMethod -Uri 'http://localhost:20128/api/providers' -WebSession $ws).connections; if ($conns | Where-Object { $_.provider -eq 'antigravity' }) { exit 0 } } catch {};" ^
    "try { $conns = (Invoke-RestMethod -Uri 'http://localhost:20128/api/providers').connections; if ($conns | Where-Object { $_.provider -eq 'antigravity' }) { exit 0 } } catch {};" ^
    "$dbs = @(\"$env:APPDATA\9router\db\data.sqlite\", \"$env:USERPROFILE\.9router\db\data.sqlite\");" ^
    "foreach ($db in $dbs) { if (Test-Path $db) { if (Select-String -Path $db -Pattern 'antigravity' -SimpleMatch -Quiet -ErrorAction SilentlyContinue) { exit 0 } } }; exit 1"
if %errorlevel% neq 0 (
    echo [PERINGATAN] Akun Google belum terhubung. Silakan login terlebih dahulu di browser.
    goto CHECK_LOGIN
)

:STEP_4
:: ===================================================================
:: STEP 4: CONFIG CLAUDE 3P & COMBO ROUND ROBIN
:: ===================================================================
echo.
echo [4/4] Menerapkan konfigurasi ke Claude Desktop...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$baseUrl = 'http://localhost:20128';" ^
    "$comboBody = @{ name = 'claude-default'; models = @('antigravity/gemini-3.8-flash-medium', 'antigravity/claude-opus-4-6-thinking') } | ConvertTo-Json;" ^
    "try { Invoke-RestMethod -Uri \"$baseUrl/api/combos\" -Method POST -Body $comboBody -ContentType 'application/json' | Out-Null } catch {};" ^
    "$settingsPatch = @{ comboStrategies = @{ 'claude-default' = @{ fallbackStrategy = 'round-robin' } } } | ConvertTo-Json -Depth 5;" ^
    "try { Invoke-RestMethod -Uri \"$baseUrl/api/settings\" -Method PATCH -Body $settingsPatch -ContentType 'application/json' | Out-Null } catch {};" ^
    "$coworkBody = @{ baseUrl = 'http://127.0.0.1:20128/v1'; apiKey = 'sk-7bfd85abf3d91a68-tgclfw-ca844f90'; models = @('claude-default') } | ConvertTo-Json;" ^
    "try {" ^
    "  Invoke-RestMethod -Uri \"$baseUrl/api/cli-tools/cowork-settings\" -Method POST -Body $coworkBody -ContentType 'application/json' | Out-Null;" ^
    "} catch {" ^
    "  $uuid = [guid]::NewGuid().ToString();" ^
    "  $metaDir = \"$env:LOCALAPPDATA\Claude-3p\configLibrary\";" ^
    "  New-Item -ItemType Directory -Force -Path $metaDir | Out-Null;" ^
    "  Set-Content -Path \"$metaDir\_meta.json\" -Value (@{ appliedId = $uuid; entries = @(@{ id = $uuid; name = 'Default' }) } | ConvertTo-Json);" ^
    "  $cfg = @{ inferenceProvider = 'gateway'; inferenceGatewayBaseUrl = 'http://127.0.0.1:20128/v1'; inferenceGatewayApiKey = 'sk-7bfd85abf3d91a68-tgclfw-ca844f90'; inferenceModels = @(@{ name = 'claude-default' }) };" ^
    "  Set-Content -Path \"$metaDir\$uuid.json\" -Value ($cfg | ConvertTo-Json -Depth 5);" ^
    "  $roamingDir = \"$env:APPDATA\Claude\";" ^
    "  New-Item -ItemType Directory -Force -Path $roamingDir | Out-Null;" ^
    "  Set-Content -Path \"$roamingDir\claude_desktop_config.json\" -Value '{\"deploymentMode\": \"3p\"}';" ^
    "}"

tasklist /fi "imagename eq Claude.exe" 2>nul | findstr /i "Claude.exe" >nul 2>&1
if %errorlevel% equ 0 (
    echo -^> Claude Desktop sudah berjalan (dilewati).
) else (
    echo -^> Meluncurkan Claude Desktop...
    if exist "%LOCALAPPDATA%\AnthropicClaude\Claude.exe" (
        start "" "%LOCALAPPDATA%\AnthropicClaude\Claude.exe"
    ) else if exist "%LOCALAPPDATA%\Programs\Claude\Claude.exe" (
        start "" "%LOCALAPPDATA%\Programs\Claude\Claude.exe"
    ) else (
        start claude: >nul 2>&1
    )
)

echo SELESAI !
pause
