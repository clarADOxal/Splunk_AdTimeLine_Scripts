$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Le script est bien exécuté en tant qu'administrateur !" -ForegroundColor Green

$pathfind=(Get-CimInstance Win32_Service -Filter "Name='Splunkd'").PathName
$cleanPath = $pathfind -replace '^"([^"]+)".*$', '$1'
$SPLUNK_HOME = Split-Path -Parent(Split-Path -Parent $cleanPath)
write-host -fore cyan "INFO :$SPLUNK_HOME"


& "$SPLUNK_HOME\bin\splunk.exe" stop

ren "$SPLUNK_HOME\etc\passwd" "$SPLUNK_HOME\etc\passwd_$timestamp"

echo "[user_info]">>$SPLUNK_HOME\etc\system\local\user-seed.conf
echo "USERNAME = admin">>$SPLUNK_HOME\etc\system\local\user-seed.conf
echo "PASSWORD = password">>$SPLUNK_HOME\etc\system\local\user-seed.conf

#Search PORT into Conf file
#==========================
$webConfPath = "$SPLUNK_HOME\etc\system\local\web.conf"
if (!(Test-Path $webConfPath)) {
    $webConfPath = "$SPLUNK_HOME\etc\system\default\web.conf"
}

$port = 8000 # Port par défaut de secours
if (Test-Path $webConfPath) {
    # Recherche de la ligne "mgmtPort" ou "httpport" dans le fichier de config
    $content = Get-Content $webConfPath -Raw
    if ($content -match "httpport\s*=\s*(\d+)") {
        $port = $matches[1]
    }
}


& "$SPLUNK_HOME\bin\splunk.exe" start

$url = "http://localhost:$port"
Start-Process $url