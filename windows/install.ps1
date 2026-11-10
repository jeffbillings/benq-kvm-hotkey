# install.ps1 - install the Ctrl+Alt+K "switch both monitors to the Mac" listener on this PC.
# Run:  powershell -ExecutionPolicy Bypass -File install.ps1  [-Code 19]
param([int]$Code = 19)

$dir = "$env:LOCALAPPDATA\kvm-switch"
$ps  = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\KVM hotkey.lnk"

# stop any running listener so the hotkey can be re-registered
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*kvm-hotkey.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

New-Item -ItemType Directory -Force $dir | Out-Null
Copy-Item "$PSScriptRoot\kvm-hotkey.ps1", "$PSScriptRoot\kvm-switch.ps1" $dir -Force

$args_ = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dir\kvm-hotkey.ps1`" -Code $Code"
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
$s.TargetPath = $ps; $s.Arguments = $args_; $s.WindowStyle = 7; $s.Save()

Start-Process $ps -ArgumentList $args_ -WindowStyle Hidden
Start-Sleep 3
Get-Content "$dir\kvm-hotkey.log" -Tail 1
