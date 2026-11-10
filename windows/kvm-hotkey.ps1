# kvm-hotkey.ps1 - background listener: Ctrl+Alt+K sets every monitor's input (VCP 0x60) to $Code
# Started at login from the Startup folder. Logs to kvm-hotkey.log next to this script.
param([int]$Code = 19)

$log = Join-Path $PSScriptRoot 'kvm-hotkey.log'
function Log($m) { "$(Get-Date -Format s)  $m" | Add-Content $log }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class KvmHotkey {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct PHYSICAL_MONITOR {
        public IntPtr h;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string desc;
    }
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int l, t, r, b; }
    [StructLayout(LayoutKind.Sequential)] struct MSG { public IntPtr hwnd; public uint message; public IntPtr wParam, lParam; public uint time; public int x, y; }
    delegate bool EnumProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d);

    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, EnumProc p, IntPtr d);
    [DllImport("dxva2.dll")] static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMon, out uint n);
    [DllImport("dxva2.dll")] static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMon, uint n, [Out] PHYSICAL_MONITOR[] a);
    [DllImport("dxva2.dll")] static extern bool DestroyPhysicalMonitors(uint n, PHYSICAL_MONITOR[] a);
    [DllImport("dxva2.dll")] static extern bool SetVCPFeature(IntPtr h, byte code, uint v);
    [DllImport("user32.dll", SetLastError = true)] static extern bool RegisterHotKey(IntPtr hwnd, int id, uint mods, uint vk);
    [DllImport("user32.dll")] static extern int GetMessage(out MSG m, IntPtr hwnd, uint min, uint max);

    public static string SetAll(uint code) {
        var results = new List<string>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d) => {
            uint n;
            if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMon, out n) && n > 0) {
                var a = new PHYSICAL_MONITOR[n];
                if (GetPhysicalMonitorsFromHMONITOR(hMon, n, a)) {
                    foreach (var m in a) results.Add(SetVCPFeature(m.h, 0x60, code).ToString());
                    DestroyPhysicalMonitors(n, a);
                }
            }
            return true;
        }, IntPtr.Zero);
        return string.Join(",", results);
    }

    // Ctrl+Alt+K. Returns error text if the hotkey can't be registered; otherwise loops forever.
    public static string Run(uint code, Action<string> log) {
        const uint MOD_ALT = 1, MOD_CONTROL = 2, MOD_NOREPEAT = 0x4000, VK_K = 0x4B;
        if (!RegisterHotKey(IntPtr.Zero, 1, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_K))
            return "RegisterHotKey failed, error " + Marshal.GetLastWin32Error() + " (combo probably taken by another app)";
        log("Listening for Ctrl+Alt+K -> input " + code);
        MSG msg;
        while (GetMessage(out msg, IntPtr.Zero, 0, 0) > 0) {
            if (msg.message == 0x0312) log("Hotkey pressed, set results: " + SetAll(code));
        }
        return "message loop ended";
    }
}
'@

$err = [KvmHotkey]::Run([uint32]$Code, [Action[string]]{ param($m) Log $m })
Log $err
