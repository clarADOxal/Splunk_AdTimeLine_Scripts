


$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    Exit
}

Write-Host "Le script est bien exécuté en tant qu'administrateur !" -ForegroundColor Green


$forbiddenChars = @('#', ';', '[', ']', '=', '\', '$', '`', '"', "'")
$isValid = $false

do {
    $securePassword = Read-Host "Entrez le mot de passe administrateur Splunk (use this special only--> !@%^&*-_+? <--" -AsSecureString
    
    # Conversion temporaire en texte clair pour vérification
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    # Vérification si le mot de passe est vide
    if ([string]::IsNullOrEmpty($PlainPassword)) {
        Write-Host "Erreur : Le mot de passe ne peut pas être vide." -ForegroundColor Red
        continue
    }

    # Recherche de caractères interdits
    $hasForbiddenChar = $false
    foreach ($char in $forbiddenChars) {
        if ($PlainPassword.Contains($char)) {
            $hasForbiddenChar = $true
            Write-Host "Caractère interdit détecté : '$char'" -ForegroundColor Yellow
            break
        }
    }

    if ($hasForbiddenChar) {
        Write-Host "Le mot de passe contient des caractères non autorisés. Veuillez réessayer." -ForegroundColor Red
    } else {
        $isValid = $true
        Write-Host "Mot de passe valide !" -ForegroundColor Green
    }
} while (-not $isValid)


$pathfind=(Get-CimInstance Win32_Service -Filter "Name='Splunkd'").PathName
$cleanPath = $pathfind -replace '^"([^"]+)".*$', '$1'
$SPLUNK_HOME = Split-Path -Parent(Split-Path -Parent $cleanPath)
write-host -fore cyan "INFO :$SPLUNK_HOME"


& "$SPLUNK_HOME\bin\splunk.exe" stop

$passwdPath = "$SPLUNK_HOME\etc\passwd"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if (Test-Path $passwdPath) {
    Rename-Item -Path $passwdPath -NewName "passwd_$timestamp"
    Write-Host "Ancien fichier passwd sauvegardé." -ForegroundColor Yellow
}

######################
# New




# 2. Convertir temporairement le SecureString en texte clair pour l'injecter dans le fichier de configuration
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# 3. Chemin vers le fichier user-seed.conf
$seedFile = "$SPLUNK_HOME\etc\system\local\user-seed.conf"

# 4. Création du contenu du fichier de configuration
$configContent = @"
[user_info]
USERNAME = admin
PASSWORD = $PlainPassword
"@

write-host -fore red $PlainPassword

# 5. Écriture dans le fichier (en s'assurant que le dossier local existe)
$dir = [System.IO.Path]::GetDirectoryName($seedFile)
if (-not (Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

Set-Content -Path $seedFile -Value $configContent -Encoding UTF8

Write-Host "Le fichier user-seed.conf a été généré avec succès." -ForegroundColor Green


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


