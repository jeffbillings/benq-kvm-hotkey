# install.ps1 - install the Ctrl+Alt+K "switch both monitors to the Mac" listener on this PC.
# Run:  powershell -ExecutionPolicy Bypass -File install.ps1  [-Code 19]
#
# The listener runs as a Task Scheduler task at logon, restarting if it ever exits.
# (A Startup-folder shortcut, or launching it from another program, let it get killed
#  when the program that started it went away.)
param([int]$Code = 19)

$dir  = "$env:LOCALAPPDATA\kvm-switch"
$ps   = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$user = "$env:USERDOMAIN\$env:USERNAME"

# stop any running listener so the hotkey can be re-registered
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*kvm-hotkey.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item "$PSScriptRoot\kvm-hotkey.ps1", "$PSScriptRoot\kvm-switch.ps1" $dir -Force

# older installs used a Startup-folder shortcut
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\KVM hotkey.lnk" -ErrorAction SilentlyContinue

$action    = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dir\kvm-hotkey.ps1`" -Code $Code"
$trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 `
                -RestartInterval (New-TimeSpan -Minutes 1) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'KVM hotkey' -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Force | Out-Null

Start-ScheduledTask -TaskName 'KVM hotkey'
Start-Sleep 4
Get-Content "$dir\kvm-hotkey.log" -Tail 1
