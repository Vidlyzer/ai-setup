# Setup Otomatis Claude 3P & 9Router
# Requires Run as Administrator

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Jalankan PowerShell sebagai Administrator (Klik kanan -> Run as administrator)." -ForegroundColor Yellow
    pause
    exit
}

# ===================================================================
# STEP 1: RUNTIME (NODEJS, PYTHON, CLAUDE DESKTOP) & HOSTS
# ===================================================================
Write-Host "`n[1/4] Memasang Node.js, Python, dan Claude Desktop..." -ForegroundColor Cyan

# 1.1 Daftarkan domain 9router ke hosts
$hostsPath = "$env:WINDIR\System32\drivers\etc\hosts"
if (Test-Path $hostsPath) {
    $hostsContent = Get-Content -Path $hostsPath -Raw -ErrorAction SilentlyContinue
    if ($hostsContent -notmatch "9router") {
        Write-Host "-> Mendaftarkan domain 9router ke file hosts..." -ForegroundColor Gray
        Add-Content -Path $hostsPath -Value "`n127.0.0.1 9router" -Force
    }
}

# 1.2 Pasang Node.js LTS jika belum ada
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "-> Memasang Node.js LTS via winget..." -ForegroundColor Yellow
    winget install OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "-> Node.js sudah terpasang (dilewati)." -ForegroundColor Green
}

# 1.3 Pasang Python 3.12 dengan PrependPath aktif jika belum ada
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "-> Memasang Python 3.12 via winget..." -ForegroundColor Yellow
    winget install Python.Python.3.12 --override "/quiet PrependPath=1" --accept-package-agreements --accept-source-agreements
} else {
    Write-Host "-> Python sudah terpasang (dilewati)." -ForegroundColor Green
}

# 1.4 Pasang Claude Desktop resmi Anthropic jika belum ada
$claudeExePath = "$env:LOCALAPPDATA\AnthropicClaude\Claude.exe"
$claudeAltPath = "$env:LOCALAPPDATA\Programs\Claude\Claude.exe"
$isClaudeInstalled = (Test-Path $claudeExePath) -or (Test-Path $claudeAltPath) -or (Get-Process Claude -ErrorAction SilentlyContinue) -or (Get-Command claude -ErrorAction SilentlyContinue)

if (-not $isClaudeInstalled) {
    Write-Host "-> Membuka link download resmi Claude Desktop di browser..." -ForegroundColor Yellow
    $downloadUrl = "https://claude.ai/redirect/claudeai.v1.f1f00150-1fbd-467c-adfc-2cbccaa0f85f/api/desktop/win32/x64/setup/latest/redirect"
    Start-Process $downloadUrl

    Write-Host "-> Menunggu file installer selesai terunduh di folder Downloads..." -ForegroundColor Yellow
    $downloadsFolder = "$env:USERPROFILE\Downloads"
    $maxWait = 120
    $waited = 0
    while (-not (Test-Path $claudeExePath) -and -not (Test-Path $claudeAltPath) -and -not (Get-Process Claude -ErrorAction SilentlyContinue) -and ($waited -lt $maxWait)) {
        $installer = Get-ChildItem -Path $downloadsFolder -Filter "*Claude*Setup*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($installer -and (Test-Path $installer.FullName)) {
            try {
                $testStream = [System.IO.File]::Open($installer.FullName, 'Open', 'Read', 'None')
                $testStream.Close()
                Write-Host "-> Memasang $($installer.Name)..." -ForegroundColor Yellow
                Start-Process $installer.FullName -ArgumentList "--silent" -Wait
                Write-Host "-> Claude Desktop berhasil dipasang!" -ForegroundColor Green
                break
            } catch {
                # File masih sedang diunduh oleh browser
            }
        }
        Start-Sleep -Seconds 2
        $waited += 2
    }
} else {
    Write-Host "-> Claude Desktop sudah terpasang (dilewati)." -ForegroundColor Green
}

# 1.5 Daftarkan PATH permanen ke Windows Environment & sesi aktif
$npmDir = "$env:APPDATA\npm"
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$npmDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$npmDir;$userPath", "User")
}

$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$env:Path = "$npmDir;$env:ProgramFiles\nodejs;$machinePath;$userPath;$env:Path"

# Verifikasi Node.js siap
while (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 1
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$npmDir;$env:ProgramFiles\nodejs;$machinePath;$userPath;$env:Path"
}

# ===================================================================
# STEP 2: INSTALL 9ROUTER & JALANKAN SERVICE
# ===================================================================
Write-Host "`n[2/4] Menyiapkan layanan 9Router..." -ForegroundColor Cyan

# 2.1 Pasang 9router jika belum terpasang
if (-not (Get-Command 9router -ErrorAction SilentlyContinue)) {
    Write-Host "-> Memasang 9Router via npm..." -ForegroundColor Yellow
    cmd.exe /c npm install -g 9router
} else {
    Write-Host "-> 9Router sudah terpasang via npm (dilewati)." -ForegroundColor Green
}

# Daftarkan ke Startup folder via shortcut .lnk
$startupFolder = [Environment]::GetFolderPath("Startup")
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut("$startupFolder\9Router.lnk")
$shortcut.TargetPath = "powershell.exe"
$shortcut.Arguments = "-WindowStyle Hidden -Command `"9router --no-browser`""
$shortcut.WindowStyle = 7
$shortcut.Save()

# Shortcut Dashboard di Desktop
$desktopFolder = [Environment]::GetFolderPath("Desktop")
$dashShortcut = $wsh.CreateShortcut("$desktopFolder\9Router Dashboard.url")
$dashShortcut.TargetPath = "http://9router:20128/dashboard"
$dashShortcut.Save()

# 2.2 Periksa apakah 9Router sudah berjalan di port 20128
$isPortOpen = $false
try {
    $tcpCheck = New-Object Net.Sockets.TcpClient("127.0.0.1", 20128)
    $tcpCheck.Close()
    $isPortOpen = $true
} catch {}

if ($isPortOpen) {
    Write-Host "-> Service 9Router sudah aktif di port 20128 (dilewati)." -ForegroundColor Green
} else {
    Write-Host "-> Menjalankan background service 9Router..." -ForegroundColor Gray
    Start-Process powershell -ArgumentList "-WindowStyle Hidden -Command `"9router --no-browser`"" -WindowStyle Hidden
    while ($true) {
        try {
            $tcp = New-Object Net.Sockets.TcpClient("127.0.0.1", 20128)
            $tcp.Close()
            break
        } catch {
            Start-Sleep -Seconds 1
        }
    }
}

# 2.3 Bypass form login dashboard (default password 123456)
$webSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
try {
    Invoke-RestMethod -Uri "http://localhost:20128/api/auth/login" -Method POST -Body '{"password":"123456"}' -ContentType "application/json" -WebSession $webSession -ErrorAction SilentlyContinue | Out-Null
    Invoke-RestMethod -Uri "http://localhost:20128/api/settings" -Method PATCH -Body '{"requireLogin":false}' -ContentType "application/json" -WebSession $webSession -ErrorAction SilentlyContinue | Out-Null
} catch {}

# Fungsi pengecekan status Antigravity (API + Session + Database)
function Test-AntigravityConnected {
    try {
        $conns = (Invoke-RestMethod -Uri "http://localhost:20128/api/providers" -WebSession $webSession -ErrorAction Stop).connections
        if ($conns | Where-Object { $_.provider -eq "antigravity" }) { return $true }
    } catch {}

    try {
        $conns = (Invoke-RestMethod -Uri "http://localhost:20128/api/providers" -ErrorAction Stop).connections
        if ($conns | Where-Object { $_.provider -eq "antigravity" }) { return $true }
    } catch {}

    $dbCandidates = @(
        "$env:APPDATA\9router\db\data.sqlite",
        "$env:USERPROFILE\.9router\db\data.sqlite"
    )
    foreach ($db in $dbCandidates) {
        if (Test-Path $db) {
            $hasAg = Select-String -Path $db -Pattern "antigravity" -SimpleMatch -Quiet -ErrorAction SilentlyContinue
            if ($hasAg) { return $true }
        }
    }

    return $false
}

# ===================================================================
# STEP 3: LOGIN ANTIGRAVITY & VERIFIKASI KONEKSI
# ===================================================================
Write-Host "`n[3/4] Memeriksa akun Google Antigravity..." -ForegroundColor Cyan

if (Test-AntigravityConnected) {
    Write-Host "-> Akun Google Antigravity sudah terhubung (dilewati)." -ForegroundColor Green
} else {
    Write-Host "-> Silakan klik '+ Add' di browser untuk login Google..." -ForegroundColor Yellow
    Start-Process "http://9router:20128/dashboard/providers/antigravity"
    while ($true) {
        Read-Host "Tekan ENTER setelah selesai login di browser"
        if (Test-AntigravityConnected) { break }
        Write-Host "[PERINGATAN] Akun Google belum terhubung. Silakan login terlebih dahulu di browser." -ForegroundColor Yellow
    }
}

# ===================================================================
# STEP 4: CONFIG CLAUDE 3P & COMBO ROUND ROBIN
# ===================================================================
Write-Host "[4/4] Menerapkan konfigurasi ke Claude Desktop..."

$baseUrl = "http://localhost:20128"

# 4.1 Buat Combo claude-default
$comboBody = @{
    name   = "claude-default"
    models = @("antigravity/gemini-3.8-flash-medium", "antigravity/claude-opus-4-6-thinking")
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$baseUrl/api/combos" -Method POST -Body $comboBody -ContentType "application/json" -WebSession $webSession -ErrorAction Stop | Out-Null
} catch {}

# 4.2 Set strategi Round Robin
$settingsPatch = @{
    comboStrategies = @{
        "claude-default" = @{ fallbackStrategy = "round-robin" }
    }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "$baseUrl/api/settings" -Method PATCH -Body $settingsPatch -ContentType "application/json" -WebSession $webSession -ErrorAction Stop | Out-Null
} catch {}

# 4.3 Terapkan ke Claude Desktop 3P
$coworkBody = @{
    baseUrl = "http://127.0.0.1:20128/v1"
    apiKey  = "sk-7bfd85abf3d91a68-tgclfw-ca844f90"
    models  = @("claude-default")
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$baseUrl/api/cli-tools/cowork-settings" -Method POST -Body $coworkBody -ContentType "application/json" -WebSession $webSession -ErrorAction Stop | Out-Null
} catch {
    # Fallback jika API gagal: tulis file config secara manual
    $uuid = [guid]::NewGuid().ToString()
    $metaDir = "$env:LOCALAPPDATA\Claude-3p\configLibrary"
    New-Item -ItemType Directory -Force -Path $metaDir | Out-Null
    Set-Content -Path "$metaDir\_meta.json" -Value (@{ appliedId = $uuid; entries = @(@{ id = $uuid; name = "Default" }) } | ConvertTo-Json)
    $cfg = @{
        inferenceProvider       = "gateway"
        inferenceGatewayBaseUrl = "http://127.0.0.1:20128/v1"
        inferenceGatewayApiKey  = "sk-7bfd85abf3d91a68-tgclfw-ca844f90"
        inferenceModels         = @(@{ name = "claude-default" })
    }
    Set-Content -Path "$metaDir\$uuid.json" -Value ($cfg | ConvertTo-Json -Depth 5)
    $roamingDir = "$env:APPDATA\Claude"
    New-Item -ItemType Directory -Force -Path $roamingDir | Out-Null
    Set-Content -Path "$roamingDir\claude_desktop_config.json" -Value '{"deploymentMode": "3p"}'
}

# 4.4 Luncurkan Claude Desktop jika belum berjalan
if (Get-Process Claude -ErrorAction SilentlyContinue) {
    Write-Host "-> Claude Desktop sudah berjalan (dilewati)." -ForegroundColor Green
} else {
    Write-Host "-> Meluncurkan Claude Desktop..." -ForegroundColor Cyan
    if (Test-Path $claudeExePath) {
        Start-Process $claudeExePath
    } elseif (Test-Path $claudeAltPath) {
        Start-Process $claudeAltPath
    } else {
        try { Start-Process "claude:" } catch {}
    }
}

Write-Host "SELESAI !" -ForegroundColor Green
pause
