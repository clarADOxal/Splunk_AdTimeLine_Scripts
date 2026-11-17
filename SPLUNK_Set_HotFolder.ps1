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

# In FOLDER
# =========
$in = "./in"
if (!(Test-Path $in)) {
    Write-Host "$in doesn't exist, creation in progress..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $in | Out-Null
}

# Find Splunk Port
# ================
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
$url = "http://localhost:$port"
write-host -fore red $url


# AutoSearch ingestion files3
# ==========================
$absolutePath = (Resolve-Path $in).Path -replace '\\', '/'
$appLocalDir = "$SPLUNK_HOME\etc\apps\SA-ADTimeline\local"
if (!(Test-Path $appLocalDir)) {
    New-Item -ItemType Directory -Path $appLocalDir | Out-Null
}

$inputsContent = @"
[monitor://$absolutePath]
disabled = false
index = main
sourcetype = adtimeline
whitelist = \.csv$

[monitor://$absolutePath]
disabled = false
index = main
sourcetype = adobjects
whitelist = \.xml$
"@
[System.IO.File]::WriteAllText("$appLocalDir\inputs.conf", $inputsContent, $utf8NoBom)


# 6. Redémarrer Splunk
& "$SPLUNK_HOME\bin\splunk.exe" start

Start-Process $url
sleep 10
Start-Process "http://localhost:8000/fr-FR/app/SA-ADTimeline/ad_infra?form.ad_index=main"
Start-Process "http://localhost:8000/fr-FR/app/SA-ADTimeline/sensitive_accounts?form.ad_index=main"
Start-Process "http://localhost:8000/fr-FR/app/SA-ADTimeline/investigate_timeframe?form.time_token.earliest=-7d%2540h&form.time_token.latest=now&form.ad_index=main"
Start-Process "http://localhost:8000/fr-FR/app/SA-ADTimeline/suspicious_activity?form.ad_index=main"
Start-Process "http://localhost:8000/fr-FR/app/SA-ADTimeline/suspicious_exchange_activity?form.ad_index=main"

