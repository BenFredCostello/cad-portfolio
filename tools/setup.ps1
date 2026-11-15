# One-time setup. Run in PowerShell:
#   irm https://raw.githubusercontent.com/BenFredCostello/cad-portfolio/main/tools/setup.ps1 | iex
$dest = "$env:USERPROFILE\Documents\cad-portfolio"
if (-not (Test-Path $dest)) { git clone https://github.com/BenFredCostello/cad-portfolio.git $dest }
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest\tools\sync.ps1`""
$trigger = New-ScheduledTaskTrigger -Daily -At 7:13pm
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
Register-ScheduledTask -TaskName 'CAD portfolio sync' -Action $action -Trigger $trigger -Settings $settings -Force | Out-Null
Write-Host "Done. The portfolio is in $dest and syncs daily at 7:13pm (or next time the PC is on)."
Write-Host "Running the first sync now (this exports STLs from Inventor and may take a few minutes)..."
& "$dest\tools\sync.ps1"
