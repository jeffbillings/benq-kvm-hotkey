# BenQ KVM hotkey

One key combo on each computer switches both BenQ PD2506Q monitors to the *other* computer.
The monitors' built-in KVM moves the keyboard and mouse along with the picture, so the
next press happens on the other machine, which switches everything back.

Switching is done over DDC/CI (VCP code `0x60`, Input Source). Display Pilot 2 is not needed.

## Input codes (as reported by these monitors)

| Computer | Port        | Code      |
|----------|-------------|-----------|
| Windows  | DisplayPort | 15 (0x0F) |
| Mac      | USB-C       | 19 (0x13) |

## Windows: Ctrl+Alt+K → Mac

```
powershell -ExecutionPolicy Bypass -File windows\install.ps1
```

- `windows/kvm-hotkey.ps1`: background listener that registers Ctrl+Alt+K and sets every
  monitor to input 19. It's installed to `%LOCALAPPDATA%\kvm-switch` and run by a Task
  Scheduler task ("KVM hotkey") at logon, which restarts it if it exits. It logs to
  `kvm-hotkey.log` in that folder.
- `windows/kvm-switch.ps1`: one-off tool. `-List` shows each monitor's current input code;
  `-Inputs 19,19` sets them.
- `windows/uninstall.ps1`: removes the listener and its scheduled task.

Lessons learned:
- Hotkeys on Start Menu shortcuts never fired here. The listener uses `RegisterHotKey`
  instead, which is reliable and switches faster.
- `powershell -File script.ps1 -Inputs 19,19` passes `"19,19"` as one string. An `[int[]]`
  parameter turns that into `1919`, so the script splits the string itself.
- A listener started by another program can die when that program exits. Task Scheduler
  runs it on its own and restarts it.

## Mac: hotkey → PC

1. `brew install m1ddc` (Apple Silicon).
2. In the Shortcuts app, add a **Run Shell Script** action with the contents of
   `mac/switch-to-pc.sh`, then give the shortcut a keyboard shortcut.
3. Saved export of the shortcut: `mac/KVM.zip` (unzip on the Mac).

Check the Mac's input code with `m1ddc display 1 get input`.
