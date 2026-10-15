<#
  ReHide one-line installer.

  Usage (in PowerShell):
    irm https://raw.githubusercontent.com/t3sco/ReHide/main/install.ps1 | iex

  Downloads Fix-Taskbar.ps1 from this repo to a temp file, runs its -Install
  (which copies it to %LOCALAPPDATA%\ReHide), then deletes the temp file.
  This installer is the only part of ReHide that touches the internet.
#>
$ErrorActionPreference = 'Stop'

$url = 'https://raw.githubusercontent.com/t3sco/ReHide/main/Fix-Taskbar.ps1'
$tmp = Join-Path $env:TEMP 'ReHide-Fix-Taskbar.ps1'

Write-Host 'Downloading ReHide...'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing

try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp -Install
}
finally {
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
}
