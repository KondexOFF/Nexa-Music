# NEXA Music - E2.0 YouTube prototype test (Windows, real Portable build).
#
#   powershell -File tools\e2_0\e2_0_prototype_test.ps1 -Portable NEXA_Music_<...>
#
# Starts the Portable exe with a clean temporary profile (NEXA_DATA_DIR) and
# the prototype self-test (NEXA_E20_SELFTEST = run folder), then drives it
# through <run>\commands.txt while doing the Windows side itself: window
# size / minimise / restore, the Play/Pause media key, CPU and GPU samples,
# Windows media-session (SMTC) snapshots and screenshots.
# Results: <run>\results.json and <run>\summary.txt (run folders live next to
# the repository, never inside it). Videos play muted, except one short
# unmuted start check. Never touches the owner's library or settings.
param(
    [Parameter(Mandatory = $true)][string]$Portable,
    [string[]]$Videos = @('M7lc1UVf-VE', 'aqz-KE-bpKQ', 'eRsGyueVLvQ'),
    [string]$PerfVideo = 'aqz-KE-bpKQ',
    [int]$PerfSeconds = 300,
    [switch]$NoPause
)
$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$base = Split-Path -Parent $repo
$folder = Join-Path $base $Portable
$exe = Join-Path $folder 'nexa_music.exe'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$run = Join-Path $base "_e2_0_runs\$stamp"
New-Item -ItemType Directory -Force -Path $run, (Join-Path $run 'profile'), (Join-Path $run 'shots') | Out-Null
$events = Join-Path $run 'events.jsonl'
$commands = Join-Path $run 'commands.txt'
$summary = Join-Path $run 'summary.txt'
Set-Content -Path $commands -Value '' -Encoding ASCII
function Say([string]$m) { $line = "[$(Get-Date -Format HH:mm:ss)] $m"; Add-Content -Path $summary -Value $line -Encoding UTF8; Write-Host $line }

Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class E20Win {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void MediaPlayPause() { keybd_event(0xB3, 0x22, 1, UIntPtr.Zero); keybd_event(0xB3, 0x22, 3, UIntPtr.Zero); }
}
'@

$results = [ordered]@{
    run = $stamp; portable = $Portable; videos = $Videos; perfVideo = $PerfVideo
    R1 = [ordered]@{}; R2 = [ordered]@{}; R3 = [ordered]@{}; R4 = [ordered]@{}; R5 = [ordered]@{}
}
if (-not (Test-Path $exe)) { Say "ERROR: $Portable\nexa_music.exe not found"; exit 2 }

# ---- events.jsonl reader ----
$script:seen = 0
$script:all = New-Object System.Collections.ArrayList
function Read-Events {
    if (-not (Test-Path $events)) { return }
    $lines = @(Get-Content -Path $events -Encoding UTF8)
    for ($i = $script:seen; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim()) {
            try { [void]$script:all.Add(($lines[$i] | ConvertFrom-Json)) } catch { }
        }
    }
    $script:seen = $lines.Count
}
function Since([int]$from) { Read-Events; if ($from -ge $script:all.Count) { return @() }; return @($script:all[$from..($script:all.Count - 1)]) }
function Mark { Read-Events; return $script:all.Count }
function Wait-Event([int]$from, [scriptblock]$test, [int]$seconds) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        foreach ($e in (Since $from)) { if (& $test $e) { return $e } }
        Start-Sleep -Milliseconds 250
    }
    return $null
}
function Cmd([string]$c, [int]$seconds = 30) {
    $from = Mark
    Add-Content -Path $commands -Value $c -Encoding ASCII
    $ack = Wait-Event $from { param($e) $e.type -eq 'ack' -and $e.cmd -eq $c } $seconds
    if (-not $ack) { Say "  command '$c': no answer in $seconds s" }
    elseif (-not $ack.ok) { Say "  command '$c' failed: $($ack.error)" }
    return $from
}
function Kind([object]$e, [string]$k) { return ($e.type -eq 'log' -and $e.kind -eq $k) }
function YtState([object]$e) { if ((Kind $e 'yt.state') -and $e.state -ne $null) { return [int]$e.state }; return $null }
function Last-Status {
    $from = Cmd 'status' 10
    return (Wait-Event $from { param($e) $e.type -eq 'status' } 5)
}
function Wait-YtState([int]$from, [int[]]$states, [int]$seconds) {
    return (Wait-Event $from { param($e) (Kind $e 'yt.state') -and $states -contains [int]$e.state } $seconds)
}

# ---- Windows helpers ----
$script:hwnd = [IntPtr]::Zero
function Window { return $script:hwnd }
function Front { [void][E20Win]::ShowWindow((Window), 9); [void][E20Win]::SetForegroundWindow((Window)); Start-Sleep -Milliseconds 400 }
function Place([int]$w, [int]$h) { [void][E20Win]::ShowWindow((Window), 9); [void][E20Win]::SetWindowPos((Window), [IntPtr]::Zero, 40, 40, $w, $h, 0x0040); Start-Sleep -Milliseconds 600 }
function Maximize { [void][E20Win]::ShowWindow((Window), 3); [void][E20Win]::SetForegroundWindow((Window)); Start-Sleep -Milliseconds 800 }
function Shot([string]$name) {
    try {
        $r = New-Object E20Win+RECT; [void][E20Win]::GetWindowRect((Window), [ref]$r)
        $w = $r.R - $r.L; $h = $r.B - $r.T
        if ($w -le 0 -or $h -le 0) { return }
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
        $bmp.Save((Join-Path $run "shots\$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $g.Dispose(); $bmp.Dispose()
    } catch { Say "  screenshot $name failed: $_" }
}
function Tree([int]$root) {
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Select-Object ProcessId, ParentProcessId, Name)
    $ids = New-Object System.Collections.Generic.HashSet[int]; [void]$ids.Add($root)
    do { $added = $false; foreach ($p in $procs) { if ($ids.Contains([int]$p.ParentProcessId) -and $ids.Add([int]$p.ProcessId)) { $added = $true } } } while ($added)
    return @($procs | Where-Object { $ids.Contains([int]$_.ProcessId) })
}

# ---- Windows media sessions (SMTC); other apps only counted ----
$script:smtc = $null
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $mgrType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
    $task = $asTask.MakeGenericMethod($mgrType).Invoke($null, @($mgrType::RequestAsync()))
    [void]$task.Wait(5000); $script:smtc = $task.Result
} catch { Say "SMTC not readable: $_" }
function Sessions {
    if (-not $script:smtc) { return @{ readable = $false } }
    $list = @(); $other = 0
    foreach ($s in @($script:smtc.GetSessions())) {
        $app = "$($s.SourceAppUserModelId)"
        if ($app -match '(?i)nexa|msedgewebview2|webview') { $list += [ordered]@{ app = $app; status = "$($s.GetPlaybackInfo().PlaybackStatus)" } } else { $other++ }
    }
    $cur = $script:smtc.GetCurrentSession()
    $curApp = if ($cur) { "$($cur.SourceAppUserModelId)" } else { '' }
    if ($curApp -and $curApp -notmatch '(?i)nexa|msedgewebview2|webview') { $curApp = 'other app' }
    return [ordered]@{ readable = $true; sessions = $list; otherApps = $other; current = $curApp }
}

# ======================= start =======================
$t0 = Get-Date
Say "E2.0 prototype test - $Portable"
$psi = New-Object System.Diagnostics.ProcessStartInfo $exe
$psi.WorkingDirectory = $folder
$psi.UseShellExecute = $false
$psi.EnvironmentVariables['NEXA_DATA_DIR'] = (Join-Path $run 'profile')
$psi.EnvironmentVariables['NEXA_E20_SELFTEST'] = $run
$proc = [System.Diagnostics.Process]::Start($psi)
$started = Wait-Event 0 { param($e) $e.type -eq 'selftest' } 60
for ($i = 0; $i -lt 40 -and $proc.MainWindowHandle -eq [IntPtr]::Zero; $i++) { Start-Sleep -Milliseconds 250; $proc.Refresh() }
$script:hwnd = $proc.MainWindowHandle
$results.R5.started = [bool]$started -and $script:hwnd -ne [IntPtr]::Zero
Say "app started: $($results.R5.started) (pid $($proc.Id))"
if (-not $results.R5.started) { $results | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $run 'results.json') -Encoding UTF8; exit 3 }
Place 1280 800; Front

$from = Cmd 'open' 40
$opened = Wait-Event $from { param($e) $e.type -eq 'opened' } 5
$results.R5.webview2 = $opened.runtime
$results.R5.embed = [bool]$opened.embed
$results.R5.unavailable = $opened.unavailable
Say "player page: embed $($opened.embed), WebView2 $($opened.runtime), unavailable '$($opened.unavailable)'"
$page = Wait-Event 0 { param($e) Kind $e 'yt.page' } 20
$results.R1.pageOrigin = $page.origin
$api = Wait-Event 0 { param($e) (Kind $e 'yt.api') -or (Kind $e 'yt.apiLoadError') } 30
$results.R1.iframeApi = if (-not $api) { 'no answer' } elseif ($api.kind -eq 'yt.api') { 'loaded' } else { 'could not load (offline?)' }
Say "page origin $($page.origin); IFrame API $($results.R1.iframeApi)"

if ($opened.embed) {
    # ---------------- R1 negative control: no app identity ----------------
    Say 'R1 negative control: same page without origin (expected: error 153)'
    $from = Cmd 'unidentified' 20
    Start-Sleep -Seconds 4
    $from = Cmd "load $($Videos[0]) muted" 20
    $neg = Wait-Event $from { param($e) (Kind $e 'yt.error') -or ((YtState $e) -eq 1) } 30
    $results.R1.negative = if ($neg -and $neg.kind -eq 'yt.error') { "error $($neg.code)" } elseif ($neg) { 'played (no error)' } else { 'no answer' }
    Say "  without identity: $($results.R1.negative)"
    Shot 'r1_negative'

    # ---------------- R1: identified page, three videos ----------------
    $from = Cmd 'identified' 20
    Start-Sleep -Seconds 4
    $r1 = @()
    foreach ($v in $Videos) {
        $from = Cmd "load $v muted" 20
        $playing = Wait-YtState $from @(1) 40
        $err = @(Since $from | Where-Object { Kind $_ 'yt.error' })
        $progress = $false; $quality = $null
        if ($playing) {
            $tick = Wait-Event $from { param($e) (Kind $e 'yt.tick') -and [double]$e.time -ge 3 } 25
            $progress = [bool]$tick
            $q = @(Since $from | Where-Object { ((Kind $_ 'yt.tick') -or (Kind $_ 'yt.quality')) -and $_.quality })
            if ($q.Count) { $quality = $q[-1].quality }
        }
        Shot "r1_$v"
        $item = [ordered]@{ video = $v; playing = [bool]$playing; progress3s = $progress; errors = @($err | ForEach-Object { $_.code }); quality = $quality }
        $r1 += $item
        Say "  $v : playing $([bool]$playing), >=3 s $progress, errors [$(@($err | ForEach-Object { $_.code }) -join ',')], quality $quality"
    }
    $results.R1.videos = $r1

    # Error mapping with a video id that does not exist.
    $from = Cmd 'load aaaaaaaaaaa muted' 20
    $bad = Wait-Event $from { param($e) Kind $e 'yt.error' } 25
    $results.R1.missingVideoError = if ($bad) { [int]$bad.code } else { $null }
    Say "  missing video -> error $($results.R1.missingVideoError)"

    # Unmuted start by script (no click inside the page): allowed or blocked?
    $from = Cmd "load $($Videos[1]) unmuted" 20
    $un = Wait-Event $from { param($e) ((YtState $e) -eq 1) -or (Kind $e 'yt.autoplayBlocked') } 20
    $results.R1.unmutedScriptedStart = if (-not $un) { 'no answer' } elseif ($un.kind -eq 'yt.autoplayBlocked') { 'blocked by the browser' } else { 'played' }
    Say "  unmuted start without a click in the page: $($results.R1.unmutedScriptedStart)"
    Start-Sleep -Seconds 3
    [void](Cmd 'pause' 10)

    # ---------------- R4: hidden window, switching, leaving ----------------
    Say 'R4: minimise / restore, YouTube <-> NEXA, leaving the page'
    $from = Cmd "load $($Videos[0]) muted" 20
    [void](Wait-YtState $from @(1) 30)
    Start-Sleep -Seconds 2
    $from = Mark
    [void][E20Win]::ShowWindow((Window), 6)
    $paused = Wait-YtState $from @(2) 8
    $life = @(Since $from | Where-Object { Kind $_ 'lifecycle' } | ForEach-Object { $_.state })
    $results.R4.minimisePauses = [bool]$paused
    $results.R4.lifecycle = $life
    Say "  minimised: YouTube paused $([bool]$paused); lifecycle [$($life -join ',')]"
    Front; Start-Sleep -Seconds 3
    $st = Last-Status
    $results.R4.restoreStaysPaused = ($st -and -not $st.ytActive)
    Say "  restored: YouTube still paused $($results.R4.restoreStaysPaused)"

    $from = Cmd 'play' 10
    [void](Wait-YtState $from @(1) 15)
    $from = Cmd 'localplay' 15
    $ytPaused = Wait-YtState $from @(2) 8
    $nexaOn = Wait-Event $from { param($e) $e.type -eq 'nexaPlaying' -and $e.playing } 8
    $results.R4.nexaStartPausesYouTube = [bool]$ytPaused -and [bool]$nexaOn
    Say "  NEXA started: YouTube paused $([bool]$ytPaused), NEXA playing $([bool]$nexaOn)"
    $from = Cmd 'play' 10
    $ytOn = Wait-YtState $from @(1) 15
    $nexaOff = Wait-Event $from { param($e) $e.type -eq 'nexaPlaying' -and -not $e.playing } 8
    $results.R4.youtubeStartPausesNexa = [bool]$ytOn -and [bool]$nexaOff
    Say "  YouTube started: playing $([bool]$ytOn), NEXA paused $([bool]$nexaOff)"
    # Overlap: both reported playing at the same time, longer than 1 s?
    $results.R4.bothPlayingEvents = @(Since 0 | Where-Object { $_.type -eq 'status' -and $_.ytActive -and $_.nexaPlaying }).Count

    $from = Cmd 'leave' 15
    $closed = Wait-Event $from { param($e) Kind $e 'closed' } 10
    $pauseOnLeave = @(Since $from | Where-Object { (Kind $_ 'command') -and $_.reason -eq 'page-closed' })
    $results.R4.leaveStops = [bool]$closed
    $results.R4.leavePauseCommand = $pauseOnLeave.Count -gt 0
    Say "  page left: player closed $([bool]$closed), pause sent $($pauseOnLeave.Count -gt 0)"
    Start-Sleep -Seconds 2
    $after = Sessions
    $results.R4.sessionsAfterLeave = $after

    # ---------------- R3: media keys and Windows media sessions ----------------
    Say 'R3: Play/Pause media key with YouTube and with NEXA'
    $from = Cmd 'open' 40
    Start-Sleep -Seconds 4
    $from = Cmd "load $($Videos[0]) muted" 20
    [void](Wait-YtState $from @(1) 30)
    Start-Sleep -Seconds 2
    $results.R3.sessionsWhileYouTube = Sessions
    $from = Mark
    [E20Win]::MediaPlayPause()
    Start-Sleep -Seconds 3
    $ev = @(Since $from)
    $results.R3.key1 = [ordered]@{
        reachedNexa = @($ev | Where-Object { Kind $_ 'mediaKey' }).Count -gt 0
        youtubePaused = @($ev | Where-Object { (YtState $_) -eq 2 }).Count -gt 0
        nexaStarted = @($ev | Where-Object { $_.type -eq 'nexaPlaying' -and $_.playing }).Count -gt 0
        sessions = Sessions
    }
    Say "  key with YouTube playing: reached NEXA $($results.R3.key1.reachedNexa), YouTube paused $($results.R3.key1.youtubePaused), NEXA started $($results.R3.key1.nexaStarted)"
    $from = Mark
    [E20Win]::MediaPlayPause()
    Start-Sleep -Seconds 3
    $ev = @(Since $from)
    $results.R3.key2 = [ordered]@{
        youtubeResumed = @($ev | Where-Object { (YtState $_) -eq 1 }).Count -gt 0
        nexaStarted = @($ev | Where-Object { $_.type -eq 'nexaPlaying' -and $_.playing }).Count -gt 0
    }
    Say "  key again: YouTube resumed $($results.R3.key2.youtubeResumed), NEXA started $($results.R3.key2.nexaStarted)"
    $from = Cmd 'localplay' 15
    Start-Sleep -Seconds 2
    $from = Mark
    [E20Win]::MediaPlayPause()
    Start-Sleep -Seconds 3
    $ev = @(Since $from)
    $results.R3.key3 = [ordered]@{
        nexaPaused = @($ev | Where-Object { $_.type -eq 'nexaPlaying' -and -not $_.playing }).Count -gt 0
        youtubeStarted = @($ev | Where-Object { (YtState $_) -eq 1 }).Count -gt 0
        sessions = Sessions
    }
    Say "  key with NEXA playing: NEXA paused $($results.R3.key3.nexaPaused), YouTube started $($results.R3.key3.youtubeStarted)"
    [void](Cmd 'localpause' 10)

    # ---------------- R2: 1080p, resizing, 5 minutes, CPU / GPU ----------------
    Say "R2: $PerfVideo for $PerfSeconds s, maximised and resized; CPU / GPU every 5 s"
    Maximize
    $from = Cmd "load $PerfVideo muted" 20
    [void](Wait-YtState $from @(1) 40)
    $perfFrom = $from
    $cores = [Environment]::ProcessorCount
    $samples = @()
    $prev = @{}
    $tStart = Get-Date
    $plan = @{ 30 = 'shot:r2_030_max'; 60 = 'size:1280x720'; 100 = 'shot:r2_100_1280'; 150 = 'max'; 170 = 'shot:r2_170_max'; 240 = 'size:1024x640'; 260 = 'shot:r2_260_min'; 275 = 'max'; 290 = 'shot:r2_290_max' }
    $done = @{}
    while (((Get-Date) - $tStart).TotalSeconds -lt $PerfSeconds) {
        $sec = [int]((Get-Date) - $tStart).TotalSeconds
        foreach ($k in $plan.Keys) {
            if ($sec -ge $k -and -not $done.ContainsKey($k)) {
                $done[$k] = $true; $a = $plan[$k]
                if ($a -like 'shot:*') { Shot $a.Substring(5) }
                elseif ($a -eq 'max') { Maximize }
                elseif ($a -like 'size:*') { $wh = $a.Substring(5).Split('x'); Place ([int]$wh[0]) ([int]$wh[1]); Front }
                Say "  t=$sec s: $a"
            }
        }
        $tree = Tree $proc.Id
        $cpu = 0.0; $now = Get-Date
        foreach ($p in $tree) {
            try { $gp = Get-Process -Id $p.ProcessId -ErrorAction Stop } catch { continue }
            $key = [int]$p.ProcessId
            if ($prev.ContainsKey($key)) {
                $dt = ($now - $prev[$key].at).TotalSeconds
                if ($dt -gt 0) { $cpu += (($gp.TotalProcessorTime - $prev[$key].cpu).TotalSeconds / $dt / $cores) * 100 }
            }
            $prev[$key] = @{ cpu = $gp.TotalProcessorTime; at = $now }
        }
        # GPU engines per process (WMI class names are not localised, unlike
        # the performance counter paths on a Russian Windows).
        $gpu = $null
        try {
            $pids = @($tree | ForEach-Object { "pid_$($_.ProcessId)_" })
            $eng = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop)
            $gpu = ($eng | Where-Object { $n = $_.Name; @($pids | Where-Object { $n -like "*$_*" }).Count -gt 0 } | Measure-Object -Property UtilizationPercentage -Sum).Sum
        } catch { }
        $ws = (@($tree | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).WorkingSet64 } catch { 0 } }) | Measure-Object -Sum).Sum
        $samples += [pscustomobject]@{ t = $sec; cpu = [math]::Round($cpu, 1); gpu = if ($gpu -ne $null) { [math]::Round($gpu, 1) } else { $null }; memMB = [math]::Round($ws / 1MB); processes = $tree.Count }
        Start-Sleep -Seconds 4
    }
    $results.R2.samples = $samples
    $vals = @($samples | Where-Object { $_.t -ge 10 })
    $results.R2.cpuAvg = [math]::Round((($vals | Measure-Object -Property cpu -Average).Average), 1)
    $results.R2.cpuMax = ($vals | Measure-Object -Property cpu -Maximum).Maximum
    $g = @($vals | Where-Object { $_.gpu -ne $null })
    $results.R2.gpuAvg = if ($g.Count) { [math]::Round((($g | Measure-Object -Property gpu -Average).Average), 1) } else { $null }
    $results.R2.gpuMax = if ($g.Count) { ($g | Measure-Object -Property gpu -Maximum).Maximum } else { $null }
    $results.R2.memMaxMB = ($vals | Measure-Object -Property memMB -Maximum).Maximum
    $perf = @(Since $perfFrom)
    $q = @($perf | Where-Object { ((Kind $_ 'yt.tick') -or (Kind $_ 'yt.quality')) -and $_.quality } | ForEach-Object { $_.quality })
    $results.R2.qualities = @($q | Select-Object -Unique)
    $ticks = @($perf | Where-Object { Kind $_ 'yt.tick' })
    $stalls = 0; $buffering = 0; $last = $null
    foreach ($t in $ticks) {
        if ([int]$t.state -eq 3) { $buffering++ }
        if ($last -and [int]$t.state -eq 1 -and [int]$last.state -eq 1 -and ([double]$t.time - [double]$last.time) -lt 0.5) { $stalls++ }
        $last = $t
    }
    $results.R2.ticks = $ticks.Count
    $results.R2.stalledSeconds = $stalls
    $results.R2.bufferingSeconds = $buffering
    $results.R2.videoTimeEnd = if ($ticks.Count) { [double]$ticks[-1].time } else { $null }
    $fr = @($perf | Where-Object { $_.type -eq 'frames' -and $_.count -gt 0 })
    $results.R2.flutterFrames = [ordered]@{
        perSecondAvg = if ($fr.Count) { [math]::Round((($fr | Measure-Object -Property count -Sum).Sum / ($fr.Count * 10)), 1) } else { $null }
        rasterP95Max = if ($fr.Count) { ($fr | Measure-Object -Property rasterP95 -Maximum).Maximum } else { $null }
        over16ms = if ($fr.Count) { ($fr | Measure-Object -Property over16ms -Sum).Sum } else { $null }
    }
    $fs = @($perf | Where-Object { (Kind $_ 'commandFailed') -or (Kind $_ 'unavailable') -or (Kind $_ 'yt.error') })
    $results.R2.problems = $fs.Count
    Say "  CPU avg $($results.R2.cpuAvg) % (max $($results.R2.cpuMax)), GPU avg $($results.R2.gpuAvg) % (max $($results.R2.gpuMax)), memory max $($results.R2.memMaxMB) MB"
    Say "  quality [$($results.R2.qualities -join ',')], stalled $stalls s, buffering $buffering s, video at $($results.R2.videoTimeEnd) s"
    Say "  Flutter frames/s $($results.R2.flutterFrames.perSecondAvg), raster p95 max $($results.R2.flutterFrames.rasterP95Max) ms, frames > 16 ms $($results.R2.flutterFrames.over16ms)"
    [void](Cmd 'pause' 10)
}

# ---------------- end, crash records ----------------
Add-Content -Path $commands -Value 'exit' -Encoding ASCII
if (-not $proc.WaitForExit(20000)) { Say 'app did not exit - stopped'; try { $proc.Kill() } catch { } }
$crash = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $t0 } -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -in @('Application Error', 'Windows Error Reporting') -and $_.Message -match 'nexa_music|msedgewebview2' })
$results.R5.crashRecords = $crash.Count
$results.R5.exitCode = $proc.ExitCode
$results.R5.webview2ProfileInPortable = Test-Path (Join-Path $folder 'nexa_music.exe.WebView2')
$results.R5.webview2ProfileInRun = Test-Path (Join-Path $run 'profile\webview2')
$results.R5.portableFiles = @(Get-ChildItem -Path $folder -File | ForEach-Object { $_.Name })
Say "end: exit code $($proc.ExitCode), crash records $($crash.Count), WebView2 profile in Portable folder $($results.R5.webview2ProfileInPortable), in the test profile $($results.R5.webview2ProfileInRun)"
$results | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $run 'results.json') -Encoding UTF8
Say "results: $run"
Write-Output "E20_RUN=$stamp"
if (-not $NoPause) { Read-Host 'Press Enter to close' }
