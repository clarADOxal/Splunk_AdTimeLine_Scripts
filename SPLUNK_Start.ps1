write-host -fore yellow "Paste Data (xml+csv files) into 'IN' folder (c:\in) "
write-host -fore yellow "Then Press Enter..."
sleep


# In FOLDER
# =========
$in = "./in"
if (!(Test-Path $in)) {
    Write-Host "$in doesn't exist, creation in progress..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $in | Out-Null
}



$pathfind=(Get-CimInstance Win32_Service -Filter "Name='Splunkd'").PathName
$cleanPath = $pathfind -replace '^"([^"]+)".*$', '$1'
$SPLUNK_HOME = Split-Path -Parent(Split-Path -Parent $cleanPath)
write-host -fore cyan "INFO :$SPLUNK_HOME"


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


Start-Process "$url/fr-FR/app/SA-ADTimeline/ad_infra?form.ad_index=main"
Start-Process "$url/fr-FR/app/SA-ADTimeline/sensitive_accounts?form.ad_index=main"
Start-Process "$url/fr-FR/app/SA-ADTimeline/investigate_timeframe?form.time_token.earliest=-7d%2540h&form.time_token.latest=now&form.ad_index=main"
Start-Process "$url/fr-FR/app/SA-ADTimeline/suspicious_activity?form.ad_index=main"
Start-Process "$url/fr-FR/app/SA-ADTimeline/suspicious_exchange_activity?form.ad_index=main"
