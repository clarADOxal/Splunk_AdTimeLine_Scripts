$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Le script est bien exécuté en tant qu'administrateur !" -ForegroundColor Green



# 1. Localiser SPLUNK_HOME
$pathfind = (Get-CimInstance Win32_Service -Filter "Name='Splunkd'").PathName
$cleanPath = $pathfind -replace '^"([^"]+)".*$', '$1'
$SPLUNK_HOME = Split-Path -Parent (Split-Path -Parent $cleanPath)

# 2. Arrêter Splunk (obligatoire avant le nettoyage des index)
& "$SPLUNK_HOME\bin\splunk.exe" stop

# 3. Vider les données de l'index main
& "$SPLUNK_HOME\bin\splunk.exe" clean eventdata -index main -f

# 4. Réinitialiser le suivi des fichiers ingérés (fishbucket)
# Permet à Splunk de relire des fichiers identiques lors d'une prochaine analyse
& "$SPLUNK_HOME\bin\splunk.exe" clean eventdata -index _thefishbucket -f

# 5. Supprimer tous les fichiers dans C:\in (en conservant le dossier)
$inFolder = "C:\in"
if (Test-Path $inFolder) {
    Remove-Item "$inFolder\*" -Recurse -Force
    Write-Host -ForegroundColor Green "Dossier $inFolder vidé."
}

# 6. Redémarrer Splunk
& "$SPLUNK_HOME\bin\splunk.exe" start
Start-Process "http://localhost:8000/"

