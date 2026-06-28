# Stops and removes the TikZoom services. Leaves files in place.
param([string]$InstallDir = "C:\TikZoom")
$ErrorActionPreference = "Continue"
$nssm = (Get-Command nssm -ErrorAction SilentlyContinue).Source
if ($nssm) {
    & $nssm stop TikZoomApp 2>$null | Out-Null
    & $nssm stop TikZoomCaddy 2>$null | Out-Null
    & $nssm remove TikZoomApp confirm 2>$null | Out-Null
    & $nssm remove TikZoomCaddy confirm 2>$null | Out-Null
}
Get-NetFirewallRule -DisplayName "TikZoom HTTPS"   -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Get-NetFirewallRule -DisplayName "TikZoom HTTP App" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
Write-Host "Removed TikZoom services and firewall rules. Files kept at $InstallDir."
