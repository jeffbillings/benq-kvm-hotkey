# uninstall.ps1 - stop the listener and remove its scheduled task and files.
Unregister-ScheduledTask -TaskName 'KVM hotkey' -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*kvm-hotkey.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\KVM hotkey.lnk" -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\kvm-switch" -Recurse -Force -ErrorAction SilentlyContinue
"Uninstalled."
