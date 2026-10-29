# NEXA Music - Crossfade / gapless check on the REAL Release exe of one or
# more Portable folders (regression investigation 2026-10-29).
#
#   powershell -File tools\exe_audio\exe_mix_check.ps1 -Portables NEXA_Music_1.0.0_Windows_x64,NEXA_Music_..._b47f334_2
#
# For every Portable folder and scenario:
#   * a fresh copy of the AutoTest test profile (generated test songs only;
#     the owner's library, settings and history are never opened), with the
#     mix settings of the scenario and a two-song playlist "Mix Check";
#   * the Portable nexa_music.exe is started with NEXA_DATA_DIR = that copy,
#     the playlist is opened and its first song clicked (Windows UI
#     Automation / MSAA, like the AutoTest exe stage);
#   * NEXA's own sound is recorded with WASAPI process loopback and the song
#     transition measured by tools\exe_audio\analyze_mix.dart (the same
#     analysis and pass criteria as the AutoTest mix checks).
# Test tones are audible. Results: <root>\_exe_mix_runs\<time>\results.json
param(
    [Parameter(Mandatory = $true)][string]$Portables,
    [string]$Scenarios = 'cf6,cf0,cf12,album'
)
$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent (Split-Path -Parent $here)
$root = Split-Path -Parent $repo
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$run = Join-Path $root "_exe_mix_runs\$stamp"
New-Item -ItemType Directory -Force -Path $run | Out-Null
$summary = Join-Path $run 'summary.txt'
function Say([string]$m) { $l = "[$(Get-Date -Format HH:mm:ss)] $m"; Add-Content -Path $summary -Value $l -Encoding UTF8; Write-Host $l }

# Test profile and recorder from the latest AutoTest run that has both.
$src = Get-ChildItem (Join-Path $root '_autotest_runs') -Directory | Sort-Object Name -Descending |
    Where-Object { (Test-Path (Join-Path $_.FullName 'it\profile\nexa_library.sqlite')) -and (Test-Path (Join-Path $_.FullName 'tools\loopback_capture.exe')) } |
    Select-Object -First 1
if (-not $src) { Say 'BLOCKED: no AutoTest run with a test profile and loopback_capture.exe'; exit 3 }
$profileDb = Join-Path $src.FullName 'it\profile\nexa_library.sqlite'
$loopExe = Join-Path $src.FullName 'tools\loopback_capture.exe'
Say "test profile and recorder from AutoTest run $($src.Name)"

Add-Type -AssemblyName Accessibility
$accessibilityDll = ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'Accessibility' } | Select-Object -First 1).Location
Add-Type -ReferencedAssemblies $accessibilityDll @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Accessibility;
public class MixNode { public string Label; public int X, Y, W, H; public IAccessible Acc; }
public static class MixUi {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr e);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("oleacc.dll")] static extern int AccessibleObjectFromWindow(IntPtr hwnd, uint id, ref Guid iid, [MarshalAs(UnmanagedType.IUnknown)] out object obj);
    [DllImport("oleacc.dll")] static extern int AccessibleChildren(IAccessible parent, int start, int count, [Out] object[] children, out int obtained);
    static Guid IID = new Guid("618736E0-3C3D-11CF-810C-00AA00389B71");
    public static List<MixNode> All(IntPtr hwnd) {
        var list = new List<MixNode>();
        object o;
        try { if (AccessibleObjectFromWindow(hwnd, 0xFFFFFFFC, ref IID, out o) != 0 || o == null) return list; } catch { return list; }
        Walk(o as IAccessible, list, 0);
        return list;
    }
    static void Walk(IAccessible acc, List<MixNode> list, int depth) {
        if (acc == null || depth > 60 || list.Count > 4000) return;
        int count = 0;
        try { count = acc.accChildCount; } catch { return; }
        if (count <= 0) return;
        var children = new object[count];
        int got = 0;
        try { if (AccessibleChildren(acc, 0, count, children, out got) != 0) return; } catch { return; }
        for (int i = 0; i < got; i++) {
            var c = children[i] as IAccessible;
            if (c == null) continue;
            var n = new MixNode { Acc = c };
            string name = null, desc = null;
            try { name = c.get_accName(0); } catch { }
            try { desc = c.get_accDescription(0); } catch { }
            n.Label = ((name ?? "") + " " + (desc ?? "")).Trim();
            try { int x, y, w, h; c.accLocation(out x, out y, out w, out h, 0); n.X = x; n.Y = y; n.W = w; n.H = h; } catch { }
            list.Add(n);
            Walk(c, list, depth + 1);
        }
    }
    public static void Click(MixNode n) {
        SetCursorPos(n.X + n.W / 2, n.Y + n.H / 2);
        System.Threading.Thread.Sleep(120);
        mouse_event(2, 0, 0, 0, UIntPtr.Zero); mouse_event(4, 0, 0, 0, UIntPtr.Zero);
    }
}
public static class MixDb {
    [DllImport("sqlite3.dll", CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_open_v2(byte[] path, out IntPtr db, int flags, IntPtr vfs);
    [DllImport("sqlite3.dll", CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_exec(IntPtr db, byte[] sql, IntPtr cb, IntPtr arg, out IntPtr err);
    [DllImport("sqlite3.dll", CallingConvention = CallingConvention.Cdecl)] static extern int sqlite3_close(IntPtr db);
    [DllImport("sqlite3.dll", CallingConvention = CallingConvention.Cdecl)] static extern IntPtr sqlite3_errmsg(IntPtr db);
    static byte[] Z(string s) { var b = System.Text.Encoding.UTF8.GetBytes(s); Array.Resize(ref b, b.Length + 1); return b; }
    public static string Exec(string path, string sql) {
        IntPtr db, err;
        if (sqlite3_open_v2(Z(path), out db, 2, IntPtr.Zero) != 0) return "open failed";
        var rc = sqlite3_exec(db, Z(sql), IntPtr.Zero, IntPtr.Zero, out err);
        string msg = rc == 0 ? "" : Marshal.PtrToStringAnsi(sqlite3_errmsg(db));
        sqlite3_close(db);
        return msg;
    }
}
'@

# Scenario: mix settings, the two songs (titles in the test library), their
# tone frequencies, what to expect and how long to record from the click.
$all = [ordered]@{
    cf6   = @{ mode = 'crossfade'; seconds = 6;  a = 'Mix A';  b = 'Mix B';  fa = 440;  fb = 660;  expect = 'crossfade'; record = 46 }
    cf0   = @{ mode = 'crossfade'; seconds = 0;  a = 'Mix A';  b = 'Mix D';  fa = 440;  fb = 1100; expect = 'gapless';   record = 46 }
    cf12  = @{ mode = 'crossfade'; seconds = 12; a = 'Mix A';  b = 'Mix B';  fa = 440;  fb = 660;  expect = 'crossfade'; record = 46 }
    album = @{ mode = 'crossfade'; seconds = 6;  a = 'Live 1'; b = 'Live 2'; fa = 1300; fb = 1500; expect = 'gapless';   record = 18 }
}
$results = [ordered]@{ run = $stamp; profileFrom = $src.Name; builds = [ordered]@{} }

function Find-Node([IntPtr]$view, [string]$text, [int]$sec = 10) {
    $end = (Get-Date).AddSeconds($sec)
    do {
        $n = [MixUi]::All($view) | Where-Object { $_.W -gt 0 -and $_.Label -like "*$text*" } | Select-Object -First 1
        if ($n) { return $n }
        Start-Sleep -Milliseconds 400
    } while ((Get-Date) -lt $end)
    return $null
}

foreach ($folder in ($Portables -split ',')) {
    $folder = $folder.Trim()
    if ($folder -notmatch '^NEXA_Music_[A-Za-z0-9_.]+$') { Say "invalid folder '$folder' - skipped"; continue }
    $dir = Join-Path $root $folder
    $exe = Join-Path $dir 'nexa_music.exe'
    if (-not (Test-Path $exe)) { Say "$folder : no nexa_music.exe - skipped"; continue }
    $build = [ordered]@{}
    $results.builds[$folder] = $build
    Say "=== $folder"
    # sqlite3.dll of this build edits the test profile copy.
    $env:PATH = "$dir;$env:PATH"
    foreach ($name in ($Scenarios -split ',')) {
        $sc = $all[$name.Trim()]
        if (-not $sc) { continue }
        $out = Join-Path $run "$folder\$name"
        $prof = Join-Path $out 'profile'
        New-Item -ItemType Directory -Force -Path $prof | Out-Null
        Copy-Item $profileDb (Join-Path $prof 'nexa_library.sqlite')
        $db = Join-Path $prof 'nexa_library.sqlite'
        $sql = @"
DELETE FROM playlist_entries WHERE playlist_id = 9001;
DELETE FROM playlists WHERE id = 9001;
INSERT INTO playlists (id, name, created_at, updated_at) VALUES (9001, 'Mix Check', strftime('%s','now'), strftime('%s','now'));
INSERT INTO playlist_entries (playlist_id, track_id, position, added_at) SELECT 9001, id, 0, strftime('%s','now') FROM tracks WHERE title = '$($sc.a)' LIMIT 1;
INSERT INTO playlist_entries (playlist_id, track_id, position, added_at) SELECT 9001, id, 1, strftime('%s','now') FROM tracks WHERE title = '$($sc.b)' LIMIT 1;
DELETE FROM app_settings WHERE key IN ('player.shuffle', 'player.repeat', 'player.muted');
INSERT OR REPLACE INTO app_settings (key, value) VALUES ('mix.mode', '$($sc.mode)'), ('mix.seconds', '$($sc.seconds).0'),
  ('mix.smartAdjust', 'false'), ('mix.albumGapless', 'true'), ('player.volume', '0.5');
"@
        $err = [MixDb]::Exec($db, $sql)
        if ($err) { Say "  $name : profile edit failed: $err"; $build[$name] = @{ status = 'BLOCKED'; detail = "profile: $err" }; continue }

        $env:NEXA_DATA_DIR = $prof
        $proc = Start-Process -FilePath $exe -WorkingDirectory $dir -PassThru
        Remove-Item Env:NEXA_DATA_DIR
        $hwnd = [IntPtr]::Zero
        $end = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $end) {
            $proc.Refresh()
            if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { $hwnd = $proc.MainWindowHandle; break }
            Start-Sleep -Milliseconds 300
        }
        $status = 'BLOCKED'; $detail = ''
        if ($hwnd -eq [IntPtr]::Zero) { $detail = 'no window' }
        else {
            [MixUi]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero); [void][MixUi]::SetForegroundWindow($hwnd); [MixUi]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
            Start-Sleep -Seconds 2
            $view = [MixUi]::FindWindowEx($hwnd, [IntPtr]::Zero, 'FLUTTERVIEW', $null)
            if ($view -eq [IntPtr]::Zero) { $view = $hwnd }
            $pl = Find-Node $view 'Mix Check' 20
            if (-not $pl) { $detail = 'playlist "Mix Check" not found in the window' }
            else {
                [MixUi]::Click($pl); Start-Sleep -Seconds 2
                # The song row on the playlist page: one row high (not the whole
                # list, whose label contains every song), widest such node.
                $row = [MixUi]::All($view) | Where-Object { $_.W -gt 200 -and $_.H -gt 20 -and $_.H -lt 120 -and $_.Label -like "*$($sc.a)*" -and $_.Label -notlike "*$($sc.b)*" } |
                    Sort-Object W -Descending | Select-Object -First 1
                if ($row) { Add-Content -Path (Join-Path $out 'clicked.txt') -Value "clicked: '$($row.Label)' at $($row.X),$($row.Y) size $($row.W)x$($row.H)" -Encoding UTF8 }
                if (-not $row) { $detail = "song '$($sc.a)' not found on the playlist page" }
                else {
                    $wav = Join-Path $out 'recording.wav'
                    $rlog = Join-Path $out 'recorder.txt'
                    $rec = Start-Process -FilePath $loopExe -ArgumentList "`"$wav`"", $sc.record, $proc.Id `
                        -RedirectStandardOutput $rlog -NoNewWindow -PassThru
                    $ready = (Get-Date).AddSeconds(10)
                    while ((Get-Date) -lt $ready -and -not ((Get-Content $rlog -ErrorAction SilentlyContinue) -match 'READY')) { Start-Sleep -Milliseconds 100 }
                    [MixUi]::Click($row)
                    $null = $rec.WaitForExit(($sc.record + 20) * 1000)
                    if (-not (Test-Path $wav)) { $detail = "no recording: $((Get-Content $rlog -ErrorAction SilentlyContinue) -join ' ')" }
                    else {
                        $json = (& dart (Join-Path $here 'analyze_mix.dart') $wav $sc.fa $sc.fb $sc.expect $sc.seconds 2>&1 | Out-String).Trim()
                        $line = ($json -split "`r?`n" | Where-Object { $_.StartsWith('{') } | Select-Object -Last 1)
                        if (-not $line) { $detail = "analysis failed: $json" }
                        else {
                            $m = $line | ConvertFrom-Json
                            $status = if ($m.ok) { 'PASS' } else { 'FAIL' }
                            $detail = "overlap $([math]::Round($m.overlapSeconds, 2)) s, gap $([math]::Round($m.gapSeconds, 3)) s, peak $([math]::Round($m.peak, 3)), level $([math]::Round($m.minLevelRatio, 2))-$([math]::Round($m.maxLevelRatio, 2)), A last $([math]::Round($m.lastA, 2)) s, B first $([math]::Round($m.firstB, 2)) s, both heard $($m.found)"
                            $build[$name] = [ordered]@{ status = $status; detail = $detail; measure = $m; recorder = ((Get-Content $rlog -ErrorAction SilentlyContinue) -join ' ') }
                        }
                    }
                }
            }
        }
        if (-not $build.Contains($name)) { $build[$name] = [ordered]@{ status = $status; detail = $detail } }
        Say "  $name ($($sc.mode) $($sc.seconds) s, '$($sc.a)' -> '$($sc.b)', expect $($sc.expect)): $status - $detail"
        if (-not $proc.HasExited) { $null = $proc.CloseMainWindow(); if (-not $proc.WaitForExit(6000)) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } }
        Start-Sleep -Seconds 1
    }
}
$results | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $run 'results.json') -Encoding UTF8
Say "results: $run"
