# Shared Windows UI Automation helpers (taken from
# tools/autotest/exe_uia_test.ps1) for the D-030 update-chain test.
# Dot-source it; it uses the caller's $script:hwnd / $script:view.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class NexaWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hgt, bool repaint);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr e);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);

    [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk, scan; public uint flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Explicit)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
    [DllImport("user32.dll", SetLastError = true)] public static extern uint SendInput(uint n, INPUT[] inputs, int size);

    // Types text as Unicode characters (any language, any keyboard layout).
    public static uint TypeText(string text) {
        var list = new System.Collections.Generic.List<INPUT>();
        foreach (char c in text) {
            foreach (uint up in new uint[] { 0, 2 }) {
                var i = new INPUT { type = 1 };
                i.u.ki = new KEYBDINPUT { vk = 0, scan = c, flags = 4 | up };
                list.Add(i);
            }
        }
        return SendInput((uint)list.Count, list.ToArray(), Marshal.SizeOf(typeof(INPUT)));
    }

    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint mapType);

    // Keys as a real keyboard sends them: left Ctrl and scan codes (Flutter
    // tells the keys apart by scan code; without one Ctrl is not seen).
    static void Down(byte vk, bool ext) { keybd_event(vk, (byte)MapVirtualKey(vk, 0), ext ? 1u : 0u, UIntPtr.Zero); }
    static void Up(byte vk, bool ext) { keybd_event(vk, (byte)MapVirtualKey(vk, 0), (ext ? 1u : 0u) | 2u, UIntPtr.Zero); }

    public static void Press(byte vk, bool ctrl) {
        if (ctrl) Down(0xA2, false);
        System.Threading.Thread.Sleep(30);
        Down(vk, false); Up(vk, false);
        System.Threading.Thread.Sleep(30);
        if (ctrl) Up(0xA2, false);
        System.Threading.Thread.Sleep(150);
    }

    // Ctrl + an extended key (arrows).
    public static void CtrlExtended(byte vk) {
        Down(0xA2, false);
        System.Threading.Thread.Sleep(30);
        Down(vk, true); Up(vk, true);
        System.Threading.Thread.Sleep(30);
        Up(0xA2, false);
    }
}
'@

# Flutter on Windows exposes its accessibility tree through MSAA
# (IAccessible); UI Automation sees it through the MSAA proxy. The first
# accessibility request only switches Flutter's semantics on, so the tree is
# woken up and, if UI Automation still sees nothing, read through MSAA.
Add-Type -AssemblyName Accessibility
$accessibilityDll = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Accessibility' } | Select-Object -First 1).Location
Add-Type -ReferencedAssemblies $accessibilityDll @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Accessibility;
public class NexaMsaaNode {
    public string Name; public string Description; public int X, Y, W, H; public int State;
    public IAccessible Acc;
    public string Label { get { return ((Name ?? "") + " " + (Description ?? "")).Trim(); } }
}
public static class NexaMsaa {
    [DllImport("oleacc.dll")] static extern int AccessibleObjectFromWindow(IntPtr hwnd, uint id, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object obj);
    [DllImport("oleacc.dll")] static extern int AccessibleChildren(IAccessible parent, int start, int count, [Out] object[] children, out int obtained);
    static Guid IID_IAccessible = new Guid("618736E0-3C3D-11CF-810C-00AA00389B71");
    public static List<NexaMsaaNode> All(IntPtr hwnd) {
        var list = new List<NexaMsaaNode>();
        object o;
        try {
            if (AccessibleObjectFromWindow(hwnd, 0xFFFFFFFC, ref IID_IAccessible, out o) != 0 || o == null) return list;
        } catch { return list; }
        Walk(o as IAccessible, list, 0);
        return list;
    }
    static void Walk(IAccessible acc, List<NexaMsaaNode> list, int depth) {
        if (acc == null || depth > 60 || list.Count > 4000) return;
        int count = 0;
        try { count = acc.accChildCount; } catch { return; }
        if (count <= 0) return;
        var children = new object[count];
        int got = 0;
        try { if (AccessibleChildren(acc, 0, count, children, out got) != 0) return; } catch { return; }
        for (int i = 0; i < got; i++) {
            var child = children[i] as IAccessible;
            if (child == null) continue;
            var n = new NexaMsaaNode { Acc = child };
            try { n.Name = child.get_accName(0); } catch { }
            try { n.Description = child.get_accDescription(0); } catch { }
            try { object st = child.get_accState(0); n.State = st is int ? (int)st : 0; } catch { }
            try { int x, y, w, h; child.accLocation(out x, out y, out w, out h, 0); n.X = x; n.Y = y; n.W = w; n.H = h; } catch { }
            list.Add(n);
            Walk(child, list, depth + 1);
        }
    }
    public static bool Invoke(NexaMsaaNode n) {
        try { n.Acc.accDoDefaultAction(0); return true; } catch { return false; }
    }
}
'@

# ---------------------------------------------------------------- helpers
$script:proc = $null
$script:hwnd = [IntPtr]::Zero
$script:root = $null
$script:view = [IntPtr]::Zero
$script:diag = @()
$script:usedMsaa = $false

function Alive { return ($script:proc -and -not $script:proc.HasExited) }

function Focus-Nexa {
    if ([NexaWin]::IsIconic($script:hwnd)) { [void][NexaWin]::ShowWindow($script:hwnd, 9) }
    # The Alt key press lets this script move the window to the foreground.
    [NexaWin]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
    [void][NexaWin]::SetForegroundWindow($script:hwnd)
    [NexaWin]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 400
}

function All-Uia {
    try {
        $r = [Windows.Automation.AutomationElement]::FromHandle($script:hwnd)
        return @($r.FindAll([Windows.Automation.TreeScope]::Descendants,
                [Windows.Automation.Condition]::TrueCondition))
    } catch { return @() }
}

# Every visible accessible element as @{ kind; label; name; x; y; w; h; el }:
# UI Automation first, MSAA when UI Automation does not see Flutter's tree.
function All-Elements {
    $out = New-Object System.Collections.ArrayList
    foreach ($e in All-Uia) {
        try {
            if ($e.Current.IsOffscreen) { continue }
            $r = $e.Current.BoundingRectangle
            [void]$out.Add(@{ kind = 'uia'; el = $e; name = $e.Current.Name;
                    label = ($e.Current.Name + ' ' + $e.Current.HelpText).Trim();
                    x = $r.X; y = $r.Y; w = $r.Width; h = $r.Height })
        } catch { }
    }
    $named = @($out | Where-Object { $_.label }).Count
    if ($named -lt 5 -and $script:view -ne [IntPtr]::Zero) {
        $script:usedMsaa = $true
        foreach ($n in [NexaMsaa]::All($script:view)) {
            if (($n.State -band 0x18000) -ne 0) { continue }   # invisible / offscreen
            [void]$out.Add(@{ kind = 'msaa'; el = $n; name = $n.Name; label = $n.Label;
                    x = $n.X; y = $n.Y; w = $n.W; h = $n.H })
        }
    }
    return $out
}

function Label($e) { if ($e) { return $e.label } else { return '' } }

# Visible element whose name / description equals (or contains) $text.
# Flutter merges a widget's texts into one name with line breaks ("Wave\nWave"),
# so "equals" means one of its lines; the smallest matching element wins
# (containers repeat the texts of their children).
function Find-El([string]$text, [switch]$Contains, [int]$TimeoutSec = 8) {
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        $best = $null
        foreach ($e in All-Elements) {
            if ($e.w -le 0 -or $e.h -le 0) { continue }
            $l = "$($e.label)"
            $lines = @($l -split "`r?`n" | ForEach-Object { $_.Trim() })
            $hit = if ($Contains) { $l -like "*$text*" } else { ($e.name -eq $text) -or ($lines -contains $text) }
            if ($hit -and (-not $best -or ($e.w * $e.h) -lt ($best.w * $best.h))) { $best = $e }
        }
        if ($best) { return $best }
        Start-Sleep -Milliseconds 400
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Click-El($e) {
    if (-not $e) { return $false }
    if ($e.kind -eq 'uia') {
        try {
            $p = $e.el.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
            if ($p) { $p.Invoke(); Start-Sleep -Milliseconds 700; return $true }
        } catch { }
    } elseif ($e.kind -eq 'msaa') {
        if ([NexaMsaa]::Invoke($e.el)) { Start-Sleep -Milliseconds 700; return $true }
    }
    try {
        if ($e.w -le 0) { return $false }
        Focus-Nexa
        [void][NexaWin]::SetCursorPos([int]($e.x + $e.w / 2), [int]($e.y + $e.h / 2))
        Start-Sleep -Milliseconds 150
        [NexaWin]::mouse_event(0x2, 0, 0, 0, [UIntPtr]::Zero)
        [NexaWin]::mouse_event(0x4, 0, 0, 0, [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 700
        return $true
    } catch { return $false }
}

# Like Find-El, but scrolls the page down with the mouse wheel until the
# element appears (Flutter only exposes what is on or near the screen).
function Find-Scroll([string]$text, [switch]$Contains, [int]$MaxSteps = 15) {
    $e = Find-El $text -Contains:$Contains -TimeoutSec 2
    $r = New-Object NexaWin+RECT
    [void][NexaWin]::GetWindowRect($script:hwnd, [ref]$r)
    for ($i = 0; -not $e -and $i -lt $MaxSteps; $i++) {
        Focus-Nexa
        [void][NexaWin]::SetCursorPos([int]($r.Left + ($r.Right - $r.Left) * 0.5), [int]($r.Top + ($r.Bottom - $r.Top) * 0.45))
        [NexaWin]::mouse_event(0x0800, 0, 0, [uint32](4294967296 - 360), [UIntPtr]::Zero)
        Start-Sleep -Milliseconds 500
        $e = Find-El $text -Contains:$Contains -TimeoutSec 1
    }
    return $e
}

function Click-Text([string]$text, [switch]$Contains) {
    return (Click-El (Find-El $text -Contains:$Contains))
}

function Hover-El($e) {
    if (-not $e) { return }
    Focus-Nexa
    [void][NexaWin]::SetCursorPos([int]($e.x + $e.w / 2), [int]($e.y + $e.h / 2))
    Start-Sleep -Milliseconds 1200
}

function Key([byte]$vk) {
    [NexaWin]::keybd_event($vk, 0, 0, [UIntPtr]::Zero)
    [NexaWin]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 900
}

