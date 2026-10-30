# -------------------------------------------------------------
#  Installe le raccourci "SSH Hub" (terminal Matrix) sur un PC
#  Windows 10/11. A lancer dans PowerShell :
#    irm https://raw.githubusercontent.com/Sebastien-Gardes/Endenoma-Portfolio/claude/zen-curie-gtdpcm/deploy/ssh-hub-windows.ps1 | iex
#
#  Cree une cle SSH propre a ce PC, l'entree "hub" dans
#  ~/.ssh/config, et un raccourci sur le Bureau avec l'icone et la
#  musique. La cle publique est copiee dans le presse-papiers : il
#  reste a l'ajouter au VPS depuis une machine deja autorisee.
#  Texte sans accents : "irm | iex" sous PowerShell 5.1 les abime.
# -------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/Sebastien-Gardes/Endenoma-Portfolio/claude/zen-curie-gtdpcm/deploy'
$dir  = "$env:LOCALAPPDATA\EndenomaHub"
$ssh  = "$env:USERPROFILE\.ssh"
$key  = "$ssh\id_ed25519"

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  Write-Host 'Client OpenSSH absent : Parametres > Applications > Fonctionnalites facultatives > Client OpenSSH, puis relance.' -ForegroundColor Red
  return
}
New-Item -ItemType Directory -Force $dir, $ssh | Out-Null

# Cle sans phrase de passe, comme sur le Mac. Start-Process garde le
# -N "" intact, quelle que soit la version de PowerShell.
if (-not (Test-Path $key)) {
  Start-Process ssh-keygen -ArgumentList "-q -t ed25519 -f `"$key`" -N `"`" -C $env:USERNAME@$env:COMPUTERNAME" -NoNewWindow -Wait
}

$cfg = "$ssh\config"
if (-not ((Test-Path $cfg) -and (Select-String -Path $cfg -Pattern '^Host hub\s*$' -Quiet))) {
  Add-Content -Path $cfg -Encoding ascii -Value "`r`nHost hub`r`n  HostName 13.140.182.127`r`n  User root`r`n  IdentityFile ~/.ssh/id_ed25519`r`n  ServerAliveInterval 30"
}

Invoke-WebRequest -UseBasicParsing "$base/ssh-hub-icone.ico" -OutFile "$dir\hub.ico"
Invoke-WebRequest -UseBasicParsing "$base/ssh-hub-son.mp3"   -OutFile "$dir\matrix.mp3"

Set-Content -Path "$dir\hub.ps1" -Encoding ascii -Value @'
# Lanceur SSH Hub : ecran noir, musique, points de chargement, puis
# pluie Matrix et session tmux sur le VPS.
$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ui = $Host.UI.RawUI
$ui.BackgroundColor = 'Black'; $ui.ForegroundColor = 'Green'; $ui.WindowTitle = 'ENDENOMA HUB'
Clear-Host
[Console]::CursorVisible = $false

$son = $null
try {
  Add-Type -AssemblyName PresentationCore
  $son = New-Object System.Windows.Media.MediaPlayer
  $son.Open([uri]"$PSScriptRoot\matrix.mp3"); $son.Volume = 0.6; $son.Play()
} catch {}

$x = [Math]::Max(0, [int]($ui.WindowSize.Width / 2) - 14)
$y = [int]($ui.WindowSize.Height / 2)
for ($i = 0; $i -lt 12; $i++) {
  [Console]::SetCursorPosition($x + 12, $y); Write-Host -NoNewline ('.' * ($i % 4)).PadRight(3)
  Start-Sleep -Milliseconds 250
}
[Console]::SetCursorPosition($x, $y); Write-Host -NoNewline (' ' * 30)
[Console]::SetCursorPosition($x, $y)
foreach ($c in 'CONNEXION AU HUB ENDENOMA_'.ToCharArray()) { Write-Host -NoNewline $c; Start-Sleep -Milliseconds 45 }
Start-Sleep -Milliseconds 500
Clear-Host
[Console]::CursorVisible = $true

ssh -q hub -t "clear; timeout --foreground 4 cmatrix -b -u 4; tmux new -A -s main 'bash; tmux kill-session -t main' 2>/dev/null || bash"

if ($son) { $son.Stop() }
'@

$bureau = [Environment]::GetFolderPath('Desktop')
$lien = (New-Object -ComObject WScript.Shell).CreateShortcut("$bureau\SSH Hub.lnk")
$lien.TargetPath   = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$lien.Arguments    = "-NoProfile -ExecutionPolicy Bypass -File `"$dir\hub.ps1`""
$lien.IconLocation = "$dir\hub.ico"
$lien.Save()

$pub = (Get-Content "$key.pub" -Raw).Trim()
Set-Clipboard $pub
Write-Host ''
Write-Host 'Raccourci "SSH Hub" cree sur le Bureau.' -ForegroundColor Green
ssh -o BatchMode=yes -o ConnectTimeout=8 hub true 2>$null
if ($LASTEXITCODE -eq 0) {
  Write-Host 'Connexion au VPS : OK. Double-clique sur le raccourci.' -ForegroundColor Green
} else {
  Write-Host 'Il reste a autoriser ce PC sur le VPS. Dans le SSH Hub du Mac, colle cette ligne :' -ForegroundColor Yellow
  Write-Host ''
  Write-Host "echo '$pub' >> ~/.ssh/authorized_keys"
  Write-Host ''
  Write-Host '(La cle seule est deja dans le presse-papiers.)'
}
