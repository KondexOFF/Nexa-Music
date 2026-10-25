# NEXA AutoTest - automated final check of the Windows version.
#
# Stages (each writes JSON into the run folder; the report merges them):
#   1. environment and the generated test library (SHA-256 verified)
#   2. flutter analyze + the existing unit / widget tests
#   3. integration tests with the real stack (media_kit, SQLite, files,
#      HTTP) and WASAPI loopback audio measurements
#   4. Release build -> Portable folder -> real nexa_music.exe driven by
#      Windows UI Automation, keyboard, media keys, Windows media controls
#   5. Windows Event Log (crashes), report
#
# Everything runs in <root>\_autotest_runs\<time>\ with its own profile
# (NEXA_DATA_DIR / overridden database) - the owner's library, playlists,
# history and settings are never opened.
param(
    [string]$Groups = '',
    [switch]$NoPause,
    [switch]$SkipUnit,
    [switch]$SkipIntegration,
    [switch]$SkipExe
)

$ErrorActionPreference = 'Continue'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = (Resolve-Path (Join-Path $here '..\..')).Path
$root = Split-Path -Parent $repo
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$run = Join-Path $root "_autotest_runs\$stamp"
New-Item -ItemType Directory -Force -Path $run | Out-Null
$mainLog = Join-Path $run 'autotest.log'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $env:PATH = "$env:USERPROFILE\dev\flutter\bin;$env:PATH"
}
$env:GIT_REDIRECT_STDERR = '2>&1'
$startTime = Get-Date
$system = New-Object System.Collections.ArrayList

function Log([string]$m) {
    $line = "[$(Get-Date -Format HH:mm:ss)] $m"
    Add-Content -Path $mainLog -Value $line -Encoding UTF8
    Write-Host $line
}
function Sys([string]$id, [string]$ft, [string]$title, [string]$status, [string]$detail, [string]$level = 'Windows system') {
    [void]$system.Add([ordered]@{ id = $id; ft = $ft; title = $title; status = $status; detail = $detail; level = $level })
    Log "$status $id $title - $detail"
}
# Runs a command line through cmd, output appended to $log; returns exit code.
function Run([string]$cmdline, [string]$log, [int]$timeoutSec) {
    Add-Content -Path $log -Value "`r`n===== $cmdline =====" -Encoding UTF8
    $p = Start-Process -FilePath 'cmd.exe' -ArgumentList "/d /c chcp 65001 >nul & $cmdline >> `"$log`" 2>&1" `
        -WorkingDirectory $repo -NoNewWindow -PassThru
    $null = $p.Handle
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        & taskkill /T /F /PID $p.Id | Out-Null
        Add-Content -Path $log -Value 'TIMEOUT' -Encoding UTF8
        return -1
    }
    return $p.ExitCode
}

Write-Host ''
Write-Host '=================== NEXA AutoTest ===================' -ForegroundColor Cyan
Write-Host 'Takes about 15 minutes. Test tones will sound through the speakers.'
Write-Host 'Please close other players / videos. During the last stage (about'
Write-Host '3 minutes, "Release exe") do not use the mouse or keyboard.'
Write-Host "Results: $run"
Write-Host '======================================================' -ForegroundColor Cyan
Log "run folder $run"

# ------------------------------------------------------------ 1. setup
$git = (& git -C $repo rev-parse --short HEAD 2>$null | Out-String).Trim()
$dirty = (& git -C $repo status --porcelain 2>$null | Out-String).Trim()
$flutterVersion = ((& flutter --version 2>$null | Select-Object -First 1) | Out-String).Trim()
$version = ((Get-Content (Join-Path $repo 'pubspec.yaml') | Where-Object { $_ -match '^version:' }) -replace 'version:\s*', '').Trim()
$os = (Get-CimInstance Win32_OperatingSystem).Caption
Log "commit $git$(if ($dirty) { ' (+ uncommitted changes)' }), app $version, $flutterVersion, $os"

$srcLib = if ($env:NEXA_AUTOTEST_LIBRARY) { $env:NEXA_AUTOTEST_LIBRARY } else { Join-Path $root '_autotest_library' }
$lib = Join-Path $run 'library'
$libOk = $false
# Library update package (base64 text of a zip): files that must arrive
# byte-exact, e.g. standard FLAC files. Unpacked over the library once.
$update = Join-Path $root '_autotest_library_update.b64.txt'
if (Test-Path $update) {
    try {
        $zip = Join-Path $env:TEMP "nexa_autotest_library_update.zip"
        [System.IO.File]::WriteAllBytes($zip, [Convert]::FromBase64String((Get-Content $update -Raw)))
        Expand-Archive -Path $zip -DestinationPath $srcLib -Force
        Remove-Item $zip -Force
        Move-Item $update "$update.applied" -Force
        Log 'test library updated from the update package'
    } catch {
        Log "test library update FAILED: $($_.Exception.Message)"
    }
}
$manifestPath = Join-Path $srcLib 'manifest.json'
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $bad = @()
    foreach ($t in @($manifest.tracks) + @($manifest.extraFiles)) {
        $f = Join-Path $srcLib ($t.file -replace '/', '\')
        if (-not (Test-Path -LiteralPath $f)) { $bad += "$($t.file) missing"; continue }
        $h = (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()
        if ($h -ne $t.sha256) { $bad += "$($t.file) changed" }
    }
    $libOk = $bad.Count -eq 0
    Sys 'SYS-library' '-' 'Test library present and unchanged (SHA-256)' $(if ($libOk) { 'PASS' } else { 'BLOCKED' }) `
        $(if ($libOk) { "$(@($manifest.tracks).Count) tracks" } else { $bad -join '; ' })
    if ($libOk) {
        New-Item -ItemType Directory -Force -Path $lib | Out-Null
        Copy-Item -Path (Join-Path $srcLib '*') -Destination $lib -Recurse -Force
    }
} else {
    Sys 'SYS-library' '-' 'Test library present' 'BLOCKED' "no manifest.json in $srcLib (run tools\autotest\library\make_test_library.py)"
}

# WASAPI loopback recorder, built from source with Visual Studio.
$tools = Join-Path $run 'tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
$loopExe = Join-Path $tools 'loopback_capture.exe'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $vs = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | Select-Object -First 1)
    $vcvars = Join-Path $vs 'VC\Auxiliary\Build\vcvars64.bat'
    $src = Join-Path $here 'loopback\loopback_capture.cpp'
    $buildLog = Join-Path $run 'loopback_build.log'
    $code = Run "call `"$vcvars`" >nul && cd /d `"$tools`" && cl /nologo /EHsc /O2 `"$src`" ole32.lib /Fe:loopback_capture.exe" $buildLog 300
    Sys 'SYS-loopback' '-' 'WASAPI loopback recorder built' $(if ($code -eq 0 -and (Test-Path $loopExe)) { 'PASS' } else { 'BLOCKED' }) "exit $code"
} else {
    Sys 'SYS-loopback' '-' 'WASAPI loopback recorder built' 'BLOCKED' 'vswhere.exe not found'
}
if (-not (Test-Path $loopExe)) { $loopExe = '' }

# ------------------------------------------------------- 2. unit tests
$unit = New-Object System.Collections.ArrayList
if (-not $SkipUnit) {
    Log 'stage 2: flutter analyze + unit / widget tests'
    $ulog = Join-Path $run 'unit.log'
    $c1 = Run 'flutter analyze' $ulog 900
    $c2 = Run 'flutter test' $ulog 1800
    $text = Get-Content $ulog -Raw -Encoding UTF8
    $m = [regex]::Matches($text, '\+(\d+)(?: ~(\d+))?(?: -(\d+))?: (All tests passed!|Some tests failed\.)')
    $summary = if ($m.Count) { $m[$m.Count - 1].Value } else { 'no summary' }
    [void]$unit.Add([ordered]@{ id = 'UNIT-analyze'; ft = '-'; title = 'flutter analyze'; status = $(if ($c1 -eq 0) { 'PASS' } else { 'FAIL' });
        detail = "exit $c1"; level = 'static analysis' })
    [void]$unit.Add([ordered]@{ id = 'UNIT-tests'; ft = '-'; title = 'Existing unit / widget tests (FakeEngine, in-memory database)';
        status = $(if ($c2 -eq 0) { 'PASS' } else { 'FAIL' }); detail = "exit $c2; $summary"; level = 'unit / widget tests' })
    Log "analyze exit $c1, tests exit $c2 ($summary)"
}

# ------------------------------------------------ 3. integration tests
if (-not $SkipIntegration -and $libOk) {
    Log 'stage 3: integration tests with media_kit, SQLite, files, HTTP and loopback (about 8 minutes)'
    $itOut = Join-Path $run 'it'
    New-Item -ItemType Directory -Force -Path $itOut | Out-Null
    $jamendo = Join-Path $root '_phase1_ctl\jamendo_client_id.txt'
    $defines = "--dart-define=NEXA_AT_LIBRARY=`"$lib`" --dart-define=NEXA_AT_OUT=`"$itOut`" " +
        "--dart-define=NEXA_AT_LOOPBACK=`"$loopExe`" --dart-define=NEXA_AT_GROUPS=$Groups " +
        $(if (Test-Path $jamendo) { "--dart-define=NEXA_AT_JAMENDO_ID_FILE=`"$jamendo`"" } else { '' })
    $code = Run "flutter test integration_test/autotest_test.dart -d windows $defines" (Join-Path $run 'integration.log') 2700
    Log "integration exit $code"
    if (-not (Test-Path (Join-Path $itOut 'integration.json'))) {
        Sys 'SYS-integration' '-' 'Integration tests produced results' 'FAIL' "exit $code, no integration.json - see integration.log"
    }
}

# --------------------------------------------- 4. Release build + exe
if (-not $SkipExe) {
    Log 'stage 4: Release build and the Portable exe'
    $blog = Join-Path $run 'release_build.log'
    $code = Run 'flutter build windows --release' $blog 1800
    $release = Join-Path $repo 'build\windows\x64\runner\Release'
    $portable = Join-Path $run 'portable\NEXA_Music'
    if ($code -eq 0 -and (Test-Path (Join-Path $release 'nexa_music.exe'))) {
        New-Item -ItemType Directory -Force -Path $portable | Out-Null
        & robocopy $release $portable /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
        $missing = @()
        foreach ($pattern in @('nexa_music.exe', 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'libmpv*.dll',
                '*sqlite3*.dll', 'url_launcher_windows_plugin.dll', 'media_kit_libs_windows_audio_plugin.dll',
                'vcruntime140.dll', 'vcruntime140_1.dll', 'msvcp140.dll', 'data\flutter_assets\assets\fonts\OFL.txt')) {
            if (-not (Get-ChildItem -Path (Join-Path $portable $pattern) -ErrorAction SilentlyContinue)) { $missing += $pattern }
        }
        $size = [math]::Round(((Get-ChildItem $portable -Recurse -File | Measure-Object -Sum Length).Sum / 1MB), 1)
        Sys 'SYS-package' 'FT-01' 'Release build copied to a Portable folder with every required file' `
            $(if ($missing.Count -eq 0) { 'PASS' } else { 'FAIL' }) $(if ($missing.Count) { "missing: $($missing -join ', ')" } else { "$size MB" })
        $db = Join-Path $run 'it\profile\nexa_library.sqlite'
        if (-not (Test-Path $db)) {
            # Integration stage skipped: reuse the test profile of the latest
            # earlier run (its library copy is still in that run folder).
            $prev = Get-ChildItem (Split-Path $run) -Directory | Where-Object { $_.FullName -ne $run } |
                Sort-Object Name -Descending | ForEach-Object { Join-Path $_.FullName 'it\profile\nexa_library.sqlite' } |
                Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($prev) { $db = $prev; Log "exe stage uses the test profile of an earlier run" }
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'exe_uia_test.ps1') `
            -Exe (Join-Path $portable 'nexa_music.exe') -RunDir $run -ProfileDb $db *>&1 |
            Out-File -FilePath (Join-Path $run 'exe_stage.log') -Encoding UTF8 -Append
        Get-Process -Name 'nexa_music' -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$portable*" } |
            Stop-Process -Force -ErrorAction SilentlyContinue
    } else {
        Sys 'SYS-package' 'FT-01' 'Release build' 'FAIL' "flutter build windows --release exit $code"
    }
}

# ------------------------------------------------------ 5. event log
$ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $startTime } -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -in @('Application Error', 'Windows Error Reporting') -and $_.Message -match 'nexa_music' })
Sys 'SYS-eventlog' 'FT-28' 'Windows Event Log: no crash of nexa_music.exe during the whole run' `
    $(if ($ev.Count -eq 0) { 'PASS' } else { 'FAIL' }) "$($ev.Count) crash records"
foreach ($e in $ev) { Add-Content -Path (Join-Path $run 'crash_records.txt') -Value "$($e.TimeCreated.ToString('s')) $($e.ProviderName)`r`n$($e.Message)`r`n" -Encoding UTF8 }

$meta = [ordered]@{
    run = $stamp; commit = $git; uncommitted = [bool]$dirty; appVersion = $version; flutter = $flutterVersion; windows = $os
    startedAt = $startTime.ToString('s'); finishedAt = (Get-Date).ToString('s')
    loopback = [bool]$loopExe
}
$sysOut = [ordered]@{ stage = 'system'; meta = $meta; checks = @($system) + @($unit) }
[System.IO.File]::WriteAllText((Join-Path $run 'system.json'), ($sysOut | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))

# ---------------------------------------------------------- report
Log 'report'
$code = Run "dart run tools/autotest/make_report.dart `"$run`" `"$repo`"" (Join-Path $run 'report.log') 300
Log "report exit $code"
Write-Host ''
Write-Host "Report: $repo\reports\FINAL_AUTOTEST_REPORT.md" -ForegroundColor Green
Write-Host "Run folder (logs, recordings, screenshots): $run"
if (Test-Path (Join-Path $run 'summary.txt')) { Get-Content (Join-Path $run 'summary.txt') -Encoding UTF8 | Write-Host }
if (-not $NoPause) { Read-Host 'Press Enter to close' }
