# NEXA AutoTest - stage "Windows Release exe".
#
# Starts the Portable build (nexa_music.exe) with an isolated test profile
# (NEXA_DATA_DIR) and drives it like a person would, through Windows UI
# Automation, the keyboard, media keys and the Windows media controls
# (GlobalSystemMediaTransportControls). Never touches the owner's profile.
#
# Writes <RunDir>\exe.json (checks), <RunDir>\exe_app.log (app output),
# <RunDir>\screenshots\*.png.
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][string]$RunDir,
    [string]$ProfileDb = ''
)

$ErrorActionPreference = 'Continue'
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

$results = New-Object System.Collections.ArrayList
function Add-Result([string]$id, [string]$ft, [string]$title, [string]$status, [string]$detail) {
    [void]$results.Add([ordered]@{ id = $id; ft = $ft; title = $title; status = $status; detail = $detail;
        level = 'Windows Release exe (Portable build, UI Automation)' })
    Write-Host "AUTOTEST $status $id ($ft) $title - $detail"
}
function Check([string]$id, [string]$ft, [string]$title, [bool]$ok, [string]$detail) {
    Add-Result $id $ft $title $(if ($ok) { 'PASS' } else { 'FAIL' }) $detail
}

# ---------------------------------------------------------------- helpers
$script:proc = $null
$script:hwnd = [IntPtr]::Zero
$script:root = $null
$script:view = [IntPtr]::Zero
$script:diag = @()
$script:usedMsaa = $false
$shotDir = Join-Path $RunDir 'screenshots'
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null

function Start-Nexa([string]$logName) {
    $log = Join-Path $RunDir $logName
    $env:NEXA_DATA_DIR = (Join-Path $RunDir 'exe_profile')
    # Through cmd so the app's console output lands in the log file.
    $cmd = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d', '/c', "`"`"$Exe`" > `"$log`" 2>&1`"" `
        -WorkingDirectory (Split-Path $Exe) -WindowStyle Hidden -PassThru
    Remove-Item Env:NEXA_DATA_DIR
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process -Name 'nexa_music' -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -eq $Exe -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
        if ($p) {
            $script:proc = $p
            $script:hwnd = $p.MainWindowHandle
            Start-Sleep -Seconds 2
            $script:view = [NexaWin]::FindWindowEx($script:hwnd, [IntPtr]::Zero, 'FLUTTERVIEW', $null)
            if ($script:view -eq [IntPtr]::Zero) { $script:view = $script:hwnd }
            # The first request switches Flutter's semantics on; wait until
            # the accessibility tree has content.
            $wake = (Get-Date).AddSeconds(20)
            do {
                $n = [NexaMsaa]::All($script:view).Count
                if ($n -gt 10) { break }
                Start-Sleep -Milliseconds 500
            } while ((Get-Date) -lt $wake)
            $script:root = [Windows.Automation.AutomationElement]::FromHandle($script:hwnd)
            $uia = (All-Uia).Count
            $script:diag += "$logName start: MSAA nodes $n, UI Automation elements $uia"
            return $true
        }
        Start-Sleep -Milliseconds 300
    }
    return $false
}

function Stop-Nexa {
    if ($script:proc -and -not $script:proc.HasExited) {
        $null = $script:proc.CloseMainWindow()
        if (-not $script:proc.WaitForExit(8000)) { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue }
    }
    Get-Process -Name 'nexa_music' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $Exe } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

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

function Shot([string]$name) {
    try {
        Focus-Nexa
        $r = New-Object NexaWin+RECT
        [void][NexaWin]::GetWindowRect($script:hwnd, [ref]$r)
        $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
        if ($w -le 0 -or $h -le 0) { return }
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r.Left, $r.Top, 0, 0, $bmp.Size)
        $bmp.Save((Join-Path $shotDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
    } catch { Write-Host "screenshot $name failed: $($_.Exception.Message)" }
}

function Window-Logical {
    $r = New-Object NexaWin+RECT
    [void][NexaWin]::GetWindowRect($script:hwnd, [ref]$r)
    $dpi = [NexaWin]::GetDpiForWindow($script:hwnd); if ($dpi -eq 0) { $dpi = 96 }
    return @{ w = [int](($r.Right - $r.Left) * 96 / $dpi); h = [int](($r.Bottom - $r.Top) * 96 / $dpi); dpi = $dpi }
}

# Windows media controls (what the media overlay shows).
$script:asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$type) {
    $t = $script:asTask.MakeGenericMethod($type).Invoke($null, @($op))
    $null = $t.Wait(8000)
    return $t.Result
}
function Media-State {
    try {
        [void][Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
        $mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
        $current = $mgr.GetCurrentSession()
        foreach ($s in $mgr.GetSessions()) {
            if ($s.SourceAppUserModelId -match 'nexa') {
                $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
                return @{ found = $true; title = $props.Title; artist = $props.Artist;
                    status = "$($s.GetPlaybackInfo().PlaybackStatus)"; app = $s.SourceAppUserModelId;
                    current = ($current -and $current.SourceAppUserModelId -eq $s.SourceAppUserModelId) }
            }
        }
        return @{ found = $false; sessions = (@($mgr.GetSessions()) | ForEach-Object { $_.SourceAppUserModelId }) -join ', ' }
    } catch {
        return @{ found = $false; error = $_.Exception.Message }
    }
}
function Media-Text($m) {
    if (-not $m.found) { return "no NEXA media session ($($m.sessions)$($m.error))" }
    return "'$($m.title)' / '$($m.artist)' $($m.status)$(if ($m.current) { ' (current session)' } else { ' (not the current session)' })"
}
function Wait-Media([scriptblock]$cond, [int]$sec = 6) {
    $deadline = (Get-Date).AddSeconds($sec)
    do { $m = Media-State; if (& $cond $m) { return $m }; Start-Sleep -Milliseconds 400 } while ((Get-Date) -lt $deadline)
    return $m
}

# --------------------------------------------------------------- profile
$profileDir = Join-Path $RunDir 'exe_profile'
New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
if ($ProfileDb -and (Test-Path $ProfileDb)) {
    Copy-Item -Path $ProfileDb -Destination (Join-Path $profileDir 'nexa_library.sqlite') -Force
}
$startTime = Get-Date

# ------------------------------------------------------------ 1. start
$started = Start-Nexa 'exe_app.log'
if (-not $started) {
    Add-Result 'EX-01-start' 'FT-01' 'Portable exe starts with an isolated profile' 'FAIL' 'no window within 30 s'
} else {
    $title = $script:proc.MainWindowTitle
    $all = @(All-Elements | Where-Object { $_.label })
    Check 'EX-01-start' 'FT-01' 'Portable exe starts with an isolated test profile; its accessibility tree is visible' `
        ($title -eq 'NEXA Music' -and $all.Count -gt 10) "window '$title', $($all.Count) named elements via $(if ($script:usedMsaa) { 'MSAA' } else { 'UI Automation' }); $($script:diag -join '; ')"
    Shot '01_home'
    # What the accessibility tree contains (for diagnosing failed look-ups).
    $treeLines = @($script:diag) + @(All-Elements | ForEach-Object { "$($_.kind) [$([int]$_.x),$([int]$_.y) $([int]$_.w)x$([int]$_.h)] $($_.label)" })
    [System.IO.File]::WriteAllLines((Join-Path $RunDir 'exe_tree.txt'), [string[]]$treeLines, (New-Object System.Text.UTF8Encoding $false))

    # Settings: version.
    $null = Click-Text 'Settings'
    $ver = Find-Scroll 'Version 0.9.0' -Contains
    Check 'EX-01-version' 'FT-01' 'Settings - About shows version 0.9.0' ($null -ne $ver) $(if ($ver) { Label $ver } else { 'not found' })
    Shot '02_settings'

    # Library from the real database (filled by the integration stage).
    $null = Click-Text 'Library'
    $null = Click-Text 'Songs'
    $seq = Find-El 'Seq 01' -Contains -TimeoutSec 8
    Shot '03_library'
    Check 'EX-02-library' 'FT-02' 'Release exe shows the imported test library from its database' `
        ($null -ne $seq) $(if ($seq) { "'Seq 01' visible in Library - Songs" } else { 'Seq 01 NOT visible' })
    $null = Click-Text 'Library'
    $null = Click-Text 'Songs'

    # ------------------------------------------- 2. playback + media keys
    $seq = Find-El 'Seq 01' -Contains -TimeoutSec 6
    $null = Click-El $seq
    $m = Wait-Media { param($x) $x.found -and $x.status -eq 'Playing' } 8
    Check 'EX-16-session' 'FT-16' 'Windows media overlay shows NEXA with song, artist and Playing' `
        ($m.found -and $m.status -eq 'Playing' -and $m.title) (Media-Text $m)
    Shot '04_playing'
    if ($m.found -and $m.status -eq 'Playing') {
        if (-not $m.current) {
            Add-Result 'EX-16-keys' 'FT-16' 'Media keys control NEXA in the background' 'BLOCKED' `
                'another app is the current Windows media session; close other players and run again'
        } else {
            [void][NexaWin]::ShowWindow($script:hwnd, 6)   # minimise: background
            Start-Sleep -Milliseconds 800
            $t0 = $m.title
            Key 0xB3; $pausedM = Wait-Media { param($x) $x.status -eq 'Paused' }
            Key 0xB3; $playM = Wait-Media { param($x) $x.status -eq 'Playing' }
            Key 0xB0; $nextM = Wait-Media { param($x) $x.title -and $x.title -ne $t0 }
            Key 0xB1; $prevM = Wait-Media { param($x) $x.title -eq $t0 }
            Key 0xB2; $stopM = Wait-Media { param($x) $x.status -ne 'Playing' }
            Check 'EX-16-keys' 'FT-16' 'Media keys with NEXA minimised: Play/Pause, Next, Previous, Stop' `
                ($pausedM.status -eq 'Paused' -and $playM.status -eq 'Playing' -and $nextM.title -ne $t0 -and $prevM.title -eq $t0 -and $stopM.status -ne 'Playing') `
                ("play/pause -> $($pausedM.status) -> $($playM.status); next -> '$($nextM.title)'; previous -> '$($prevM.title)'; stop -> $($stopM.status)")
        }
    } else {
        Add-Result 'EX-16-keys' 'FT-16' 'Media keys control NEXA in the background' 'BLOCKED' 'playback did not start'
    }

    # ------------------------------------------------------ 3. keyboard
    Focus-Nexa
    $before = Media-State
    if (-not ($before.found -and $before.status -eq 'Playing')) {
        # Stop (media key) ended playback: start the library again.
        $null = Click-Text 'Library'
        $null = Click-Text 'Songs'
        $null = Click-Text 'Play'
        $before = Wait-Media { param($x) $x.found -and $x.status -eq 'Playing' } 6
        Focus-Nexa
    }
    if (-not $before.found) {
        Add-Result 'EX-18-keyboard' 'FT-18' 'Keyboard shortcuts in the exe' 'BLOCKED' 'no NEXA media session to observe'
    } else {
        $s0 = $before.status
        [System.Windows.Forms.SendKeys]::SendWait(' '); $afterSpace = Wait-Media { param($x) $x.status -ne $s0 } 4
        [System.Windows.Forms.SendKeys]::SendWait(' '); $afterSpace2 = Wait-Media { param($x) $x.status -eq $s0 } 4
        $t1 = $afterSpace2.title
        [NexaWin]::CtrlExtended(0x27); $afterNext = Wait-Media { param($x) $x.title -ne $t1 } 4
        Check 'EX-18-keyboard' 'FT-18' 'Space toggles playback, Ctrl+Right plays the next song (Release exe)' `
            ($afterSpace.status -ne $s0 -and $afterSpace2.status -eq $s0 -and $afterNext.title -ne $t1) `
            ("space: $s0 -> $($afterSpace.status) -> $($afterSpace2.status); ctrl+right: '$t1' -> '$($afterNext.title)'")
    }

    # ---------------------------------- 4. accessibility client + pages
    $pages = @(
        @{ nav = 'Home'; expect = 'Your sound, in motion'; shot = '05_home' },
        @{ nav = 'Wave'; expect = 'Your Wave'; shot = '06_wave' },
        @{ nav = 'Discover'; expect = 'Free music from open catalogs'; shot = '07_discover' },
        @{ nav = 'Library'; expect = 'Add folder'; shot = '08_library' },
        @{ nav = 'Settings'; expect = 'Privacy and learning'; shot = '09_settings' }
    )
    $seen = @()
    foreach ($pg in $pages) {
        $null = Click-Text $pg.nav
        $ok = $null -ne (Find-Scroll $pg.expect -Contains -MaxSteps 6)
        $seen += "$($pg.nav):$(if ($ok) { 'ok' } else { 'MISSING' })"
        Shot $pg.shot
    }
    $null = Click-Text 'Open Now Playing' -Contains
    $np = $null -ne (Find-El 'NOW PLAYING' -Contains -TimeoutSec 5)
    Shot '10_now_playing'
    $ring = Find-El 'Play / Pause' -Contains -TimeoutSec 4
    Hover-El $ring
    $tooltip = $null -ne (Find-El 'Play / Pause' -Contains -TimeoutSec 2)
    $queueBtn = Find-El 'Show or hide Up Next' -TimeoutSec 4
    $q1 = Click-El $queueBtn; $q2 = Click-El (Find-El 'Show or hide Up Next' -TimeoutSec 4)
    $null = Click-Text 'Settings'
    $audioTest = Click-El (Find-Scroll 'Open audio engine test')
    Start-Sleep -Seconds 2
    $back = Click-Text 'Back'
    $returned = $null -ne (Find-Scroll 'Open audio engine test')
    Check 'EX-28-a11y' 'FT-28' 'With a UI Automation client attached: all pages, Now Playing, Play/Pause hover, queue button, audio test and back - no crash' `
        ((Alive) -and -not ($seen -match 'MISSING') -and $np -and $q1 -and $q2 -and $audioTest -and $back -and $returned) `
        ("pages $($seen -join ', '); now playing $np; hover tooltip $tooltip; queue $q1/$q2; audio test $audioTest, back $back, returned $returned; alive $(Alive)")

    # ------------------------------------------- 5. resize and maximise
    $sizes = @()
    [void][NexaWin]::ShowWindow($script:hwnd, 9)
    [void][NexaWin]::MoveWindow($script:hwnd, 40, 40, 700, 450, $true); Start-Sleep -Seconds 1
    $min = Window-Logical; $sizes += "min $($min.w)x$($min.h)"
    Shot '11_minimum_size'
    [void][NexaWin]::ShowWindow($script:hwnd, 3); Start-Sleep -Seconds 1.5
    $max = Window-Logical; $sizes += "max $($max.w)x$($max.h)"
    Shot '12_maximised'
    [void][NexaWin]::ShowWindow($script:hwnd, 9); Start-Sleep -Seconds 1
    foreach ($s in @(@(1600, 900), @(1100, 700), @(1300, 760))) {
        [void][NexaWin]::MoveWindow($script:hwnd, 40, 40, $s[0], $s[1], $true); Start-Sleep -Milliseconds 700
    }
    [void][NexaWin]::ShowWindow($script:hwnd, 3); Start-Sleep -Seconds 1
    [void][NexaWin]::ShowWindow($script:hwnd, 9); Start-Sleep -Seconds 1
    # After resizing, the accessibility tree must still follow the UI.
    $null = Click-Text 'Wave'
    $treeFollows = $null -ne (Find-El 'Your Wave' -Contains -TimeoutSec 6)
    Check 'EX-29-resize' 'FT-29' 'Resize / maximise with a UI Automation client: no crash, tree still updates' `
        ((Alive) -and $treeFollows) ("sizes $($sizes -join ', '); tree follows navigation after resizing $treeFollows; alive $(Alive)")
    Check 'EX-30-minsize' 'FT-30' 'Window cannot be made smaller than 1024 x 640' `
        ($min.w -ge 1020 -and $min.h -ge 636) ("smallest window $($min.w)x$($min.h) (dpi $($min.dpi))")

    # Cyrillic search last (a filter left in the field cannot change what
    # the playback checks above play).
    $null = Click-Text 'Library'
    $null = Click-Text 'Songs'
    # Cyrillic song through the search field (the list shows only what fits).
    $box = Find-El 'Search your library' -Contains -TimeoutSec 4
    $song = $null
    if ($box -and (Click-El $box)) {
        # Typed as Unicode characters (works with any keyboard layout).
        Focus-Nexa
        [void][NexaWin]::TypeText('тестовая')
        Start-Sleep -Seconds 1
        $song = Find-El 'Тестовая песня' -Contains -TimeoutSec 6
        Shot '03b_search_cyrillic'
        # Clear the search again: focus the field, Ctrl+A, Backspace, Esc.
        $null = Click-El (Find-El 'Search your library' -Contains -TimeoutSec 2)
        if (-not (Find-El 'Search your library' -Contains -TimeoutSec 1)) {
            $null = Click-El $box
        }
        Focus-Nexa
        [NexaWin]::Press(0x41, $true)
        [NexaWin]::Press(0x08, $false)
        [NexaWin]::Press(0x1B, $false)
        Start-Sleep -Milliseconds 500
    }
    Check 'EX-05-search' 'FT-05' 'Release exe: the search field finds the Cyrillic song (typed in Cyrillic)' `
        ($null -ne $song) ("search 'тестовая': $(if ($song) { "found '$((Label $song) -replace "`n", ' / ')'" } else { 'not found' })")

    # ------------------------------------------------- 6. restart
    # What the profile shows before the restart must still be there after
    # it (the test playlist exists only when the library group ran).
    $null = Click-Text 'Library'
    $null = Click-Text 'Songs'
    $playlistBefore = $null -ne (Find-El 'AutoTest playlist' -Contains -TimeoutSec 3)
    Stop-Nexa
    $restarted = Start-Nexa 'exe_app_restart.log'
    $null = Click-Text 'Library'
    $null = Click-Text 'Songs'
    $still = $null -ne (Find-El 'Seq 01' -Contains -TimeoutSec 10)
    $playlist = $null -ne (Find-El 'AutoTest playlist' -Contains -TimeoutSec 3)
    Check 'EX-03-restart' 'FT-03' 'Release exe restarted: library (and playlist, if the profile has one) still there' `
        ($restarted -and $still -and ($playlist -or -not $playlistBefore)) `
        "restarted $restarted, test song visible $still, playlist before / after restart $playlistBefore / $playlist"
    Stop-Nexa
}

# ----------------------------------------------------------- 7. log
$logText = ''
foreach ($f in @('exe_app.log', 'exe_app_restart.log')) {
    $pth = Join-Path $RunDir $f
    if (Test-Path $pth) { $logText += (Get-Content -Path $pth -Raw -Encoding UTF8) }
}
$captured = $logText -match 'NEXA AutoTest profile active'
$axErrors = ([regex]::Matches($logText, 'Failed to update ui::AXTree')).Count
$flutterErrors = ([regex]::Matches($logText, 'EXCEPTION CAUGHT|Another exception was thrown|Unhandled Exception')).Count
if (-not $captured) {
    Add-Result 'EX-29-axtree-log' 'FT-29' 'No "Failed to update ui::AXTree" messages (TD-02)' 'MANUAL REQUIRED' 'app output could not be captured from the Release exe'
} else {
    Check 'EX-29-axtree-log' 'FT-29' 'No "Failed to update ui::AXTree" messages after resizing (TD-02)' ($axErrors -eq 0) "$axErrors messages in the app output"
}
if ($captured) {
    Check 'EX-flutter-errors' 'FT-28' 'No Flutter exceptions in the Release exe output' ($flutterErrors -eq 0) "$flutterErrors error blocks"
}

$out = [ordered]@{ stage = 'exe'; startedAt = $startTime.ToString('s'); finishedAt = (Get-Date).ToString('s'); checks = $results }
[System.IO.File]::WriteAllText((Join-Path $RunDir 'exe.json'), ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
