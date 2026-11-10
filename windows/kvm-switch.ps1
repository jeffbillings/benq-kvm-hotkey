# kvm-switch.ps1 - switch monitor inputs over DDC/CI (VCP 0x60 = Input Source)
# Usage:
#   kvm-switch.ps1 -List                 # show each monitor's current input code
#   kvm-switch.ps1 -Inputs 15,15         # set monitor 0 -> 15, monitor 1 -> 15
param(
    [switch]$List,
    [string]$Inputs
)
$log = Join-Path $PSScriptRoot 'kvm-switch.log'
Start-Transcript -Path $log -Append | Out-Null
"Args: Inputs='$Inputs' List=$List"
# -File passes "19,19" as one string, so split it ourselves
$codes = @($Inputs -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ })

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class Ddc {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct PHYSICAL_MONITOR {
        public IntPtr hPhysicalMonitor;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szPhysicalMonitorDescription;
    }
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int left, top, right, bottom; }

    delegate bool MonitorEnumProc(IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr data);

    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);
    [DllImport("dxva2.dll")] static extern bool GetNumberOfPhysicalMonitorsFromHMONITOR(IntPtr hMon, out uint count);
    [DllImport("dxva2.dll")] static extern bool GetPhysicalMonitorsFromHMONITOR(IntPtr hMon, uint count, [Out] PHYSICAL_MONITOR[] mons);
    [DllImport("dxva2.dll")] public static extern bool GetVCPFeatureAndVCPFeatureReply(IntPtr h, byte code, IntPtr type, out uint cur, out uint max);
    [DllImport("dxva2.dll")] public static extern bool SetVCPFeature(IntPtr h, byte code, uint value);

    public static List<PHYSICAL_MONITOR> GetAll() {
        var list = new List<PHYSICAL_MONITOR>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (IntPtr hMon, IntPtr hdc, ref RECT r, IntPtr d) => {
            uint n;
            if (GetNumberOfPhysicalMonitorsFromHMONITOR(hMon, out n) && n > 0) {
                var arr = new PHYSICAL_MONITOR[n];
                if (GetPhysicalMonitorsFromHMONITOR(hMon, n, arr)) list.AddRange(arr);
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@

$mons = [Ddc]::GetAll()

if ($List -or -not $codes) {
    for ($i = 0; $i -lt $mons.Count; $i++) {
        $cur = 0; $max = 0
        $ok = [Ddc]::GetVCPFeatureAndVCPFeatureReply($mons[$i].hPhysicalMonitor, 0x60, [IntPtr]::Zero, [ref]$cur, [ref]$max)
        $val = if ($ok) { "$cur (0x{0:X2})" -f $cur } else { "DDC read failed" }
        "Monitor ${i}: $($mons[$i].szPhysicalMonitorDescription)  input = $val"
    }
    return
}

for ($i = 0; $i -lt [Math]::Min($codes.Count, $mons.Count); $i++) {
    $ok = [Ddc]::SetVCPFeature($mons[$i].hPhysicalMonitor, 0x60, [uint32]$codes[$i])
    "Monitor ${i} -> $($codes[$i]): ok=$ok"
}
Stop-Transcript | Out-Null

