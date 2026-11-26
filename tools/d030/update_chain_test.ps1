# D-030 NEXA Update Center - the whole update chain on Windows, end to end.
#
# Two real Release builds of this commit: A = 1.1.1 (as released) and
# B = "1.1.2" (NEXA_APP_VERSION=1.1.2, NEXA_TEST_SCHEMA_BUMP=1: one database
# migration that 1.1.1 cannot read). A local stand-in for the GitHub
# releases API (tools/d030/fake_github.dart, 127.0.0.1 only) offers packages
# built here; NEXA is driven through Windows UI Automation like a person.
# Test profiles only (NEXA_DATA_DIR) - the owner's library is never opened.
#
# Writes <Work>\chain.json (checks) and <Work>\chain.log.
param(
    [Parameter(Mandatory = $true)][string]$Work,
    [Parameter(Mandatory = $true)][string]$Repo
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'uia.ps1')

$results = New-Object System.Collections.ArrayList
$chainLog = Join-Path $Work 'chain.log'
function Say([string]$m) {
    $line = '{0:HH:mm:ss}  {1}' -f (Get-Date), $m
    Write-Host $line
    Add-Content -LiteralPath $chainLog -Value $line -Encoding UTF8
}
function Check([string]$id, [string]$title, [bool]$ok, [string]$detail) {
    [void]$results.Add([ordered]@{ id = $id; title = $title; status = $(if ($ok) { 'PASS' } else { 'FAIL' }); detail = $detail })
    Say ("{0} {1} {2} - {3}" -f $(if ($ok) { 'PASS' } else { 'FAIL' }), $id, $title, $detail)
}

$utf8 = New-Object System.Text.UTF8Encoding $false
$buildA = Join-Path $Work 'build_A'
$buildB = Join-Path $Work 'build_B'
$prog = Join-Path $Work 'NEXA_Music_1.1.1_Windows_x64'
$profiles = Join-Path $Work 'profiles'
$srv = Join-Path $Work 'server'
$pkgDir = Join-Path $Work 'packages'
New-Item -ItemType Directory -Force -Path $srv, (Join-Path $srv 'assets'), $pkgDir | Out-Null

function Sha([string]$f) { return (Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower() }

# One hash over every file (relative name + content) of a folder.
function Folder-Hash([string]$dir) {
    if (-not (Test-Path -LiteralPath $dir)) { return 'missing' }
    $root = (Resolve-Path -LiteralPath $dir).Path.TrimEnd('\')
    # The package's own list (SHA256SUMS.txt in the top folder) is not part of
    # the build it was made from.
    $files = Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName |
        Where-Object { $_.FullName -ne (Join-Path $root 'SHA256SUMS.txt') }
    $lines = foreach ($f in $files) {
        '{0} {1}' -f $f.FullName.Substring($root.Length + 1).ToLower(), (Sha $f.FullName)
    }
    $bytes = $utf8.GetBytes(($lines -join "`n"))
    $sha = [System.Security.Cryptography.SHA256]::Create()
    return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Schema([string]$db) {
    if (-not (Test-Path -LiteralPath $db)) { return -1 }
    $fs = [System.IO.File]::Open($db, 'Open', 'Read', 'ReadWrite')
    try {
        $b = New-Object byte[] 100; [void]$fs.Read($b, 0, 100)
        return ($b[60] -shl 24) -bor ($b[61] -shl 16) -bor ($b[62] -shl 8) -bor $b[63]
    } finally { $fs.Close() }
}

function Fingerprint([string]$db) {
    Push-Location $Repo
    $out = & dart run tools/d030/db_fingerprint.dart $db 2>$null | Select-Object -Last 1
    Pop-Location
    try { return ($out | ConvertFrom-Json) } catch { return $null }
}

# The user's data only (schema and table list may change with a migration).
function Data-Of($fp) {
    if (-not $fp) { return 'none' }
    return ([ordered]@{ tracks = $fp.tracks; playlists = $fp.playlists; favorites = $fp.favorites;
            history = $fp.history; taste = $fp.taste; settings = $fp.settings } | ConvertTo-Json -Depth 5 -Compress)
}

# A Portable package as the release kit makes it: one top folder, its own
# SHA256SUMS.txt, entry names with '/'.
function New-Package([string]$from, [string]$version, [string]$zip, [switch]$BreakAppSo, [string]$Evil = '') {
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    $name = "NEXA_Music_${version}_Windows_x64"
    $stage = Join-Path $Work ("pkgstage\" + [guid]::NewGuid().ToString('N').Substring(0, 8) + "\$name")
    New-Item -ItemType Directory -Force -Path $stage | Out-Null
    & robocopy $from $stage /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($BreakAppSo) {
        $junk = New-Object byte[] 65536
        for ($i = 0; $i -lt $junk.Length; $i++) { $junk[$i] = 0x5A }
        [System.IO.File]::WriteAllBytes((Join-Path $stage 'data\app.so'), $junk)
    }
    $files = @(Get-ChildItem -LiteralPath $stage -Recurse -File | Sort-Object FullName)
    $sums = foreach ($f in $files) { '{0}  {1}' -f (Sha $f.FullName), $f.FullName.Substring($stage.Length + 1) }
    [System.IO.File]::WriteAllLines((Join-Path $stage 'SHA256SUMS.txt'), [string[]]$sums, $utf8)
    if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
    $fs = [System.IO.File]::Open($zip, [System.IO.FileMode]::CreateNew)
    $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    foreach ($f in Get-ChildItem -LiteralPath $stage -Recurse -File) {
        $rel = $name + '/' + $f.FullName.Substring($stage.Length + 1).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
    }
    if ($Evil) {
        $e = $za.CreateEntry("$name/../$Evil")
        $w = New-Object System.IO.StreamWriter($e.Open()); $w.Write('must never be written'); $w.Dispose()
    }
    $za.Dispose(); $fs.Dispose()
    return (Sha $zip)
}

$assets = @{}
function Release([string]$tag, [int]$id, [string]$zip, [string]$digest, [switch]$Draft, [switch]$Pre) {
    $v = $tag.TrimStart('v')
    Copy-Item -LiteralPath $zip -Destination (Join-Path $srv "assets\$id") -Force
    $asset = [ordered]@{ id = $id; name = "NEXA_Music_${v}_Windows_x64.zip"; size = (Get-Item -LiteralPath $zip).Length;
        url = "http://127.0.0.1/repos/KondexOFF/Nexa-Music/releases/assets/$id"; browser_download_url = "http://127.0.0.1/x/$id.zip" }
    if ($digest) { $asset.digest = "sha256:$digest" }
    return [ordered]@{ tag_name = $tag; name = "NEXA Music $v"; body = "D-030 test notes for $v - Nocturne preview."
        draft = [bool]$Draft; prerelease = [bool]$Pre; published_at = '2026-11-25T20:00:00Z'
        html_url = "https://github.com/KondexOFF/Nexa-Music/releases/tag/$tag"; assets = @($asset) }
}
function Serve($releases, [string]$status = '200') {
    [System.IO.File]::WriteAllText((Join-Path $srv 'releases.json'), (ConvertTo-Json -InputObject @($releases) -Depth 8), $utf8)
    [System.IO.File]::WriteAllText((Join-Path $srv 'status.txt'), $status, $utf8)
}
function Requests([string]$pattern) {
    $f = Join-Path $srv 'requests.log'
    if (-not (Test-Path -LiteralPath $f)) { return 0 }
    return @(Get-Content -LiteralPath $f | Where-Object { $_ -match $pattern }).Count
}

# ---------------------------------------------------------------- the app
$exe = Join-Path $prog 'nexa_music.exe'
function Wake {
    Start-Sleep -Seconds 2
    $script:view = [NexaWin]::FindWindowEx($script:hwnd, [IntPtr]::Zero, 'FLUTTERVIEW', $null)
    if ($script:view -eq [IntPtr]::Zero) { $script:view = $script:hwnd }
    $wake = (Get-Date).AddSeconds(20)
    do {
        if ([NexaMsaa]::All($script:view).Count -gt 10) { break }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $wake)
}
function Attach-App([int]$seconds = 40) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        $p = Get-Process -Name 'nexa_music' -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -eq $exe -and $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
        if ($p) { $script:proc = $p; $script:hwnd = $p.MainWindowHandle; Wake; return $true }
        Start-Sleep -Milliseconds 400
    }
    return $false
}
function Start-App([string]$prof, [switch]$RealGitHub) {
    $env:NEXA_DATA_DIR = $prof
    if ($RealGitHub) {
        Remove-Item Env:NEXA_UPDATE_API -ErrorAction SilentlyContinue
        $env:NEXA_UPDATE_SOURCE = 'gh'
    } else {
        $env:NEXA_UPDATE_API = "http://127.0.0.1:$port"
        Remove-Item Env:NEXA_UPDATE_SOURCE -ErrorAction SilentlyContinue
    }
    $null = Start-Process -FilePath $exe -WorkingDirectory $prog -PassThru
    return (Attach-App 40)
}
function Stop-App {
    if ($script:proc -and -not $script:proc.HasExited) {
        $null = $script:proc.CloseMainWindow()
        if (-not $script:proc.WaitForExit(10000)) { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue }
    }
    Get-Process -Name 'nexa_music' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe } |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}
function Open-Settings {
    $s = Find-El 'Settings' -TimeoutSec 10
    [void](Click-El $s)
    Start-Sleep -Seconds 1
}
function Manual-Check {
    $b = Find-Scroll 'Check for updates'
    [void](Click-El $b)
    Start-Sleep -Seconds 2
}
# The updater's result: result.json, or result_shown.json once the started
# version has read it.
function Clear-Result([string]$prof) {
    foreach ($n in @('result.json', 'result_shown.json')) {
        Remove-Item -LiteralPath (Join-Path $prof "updates\run\$n") -ErrorAction SilentlyContinue
    }
}
function Wait-Result([string]$prof, [int]$seconds = 300) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        foreach ($n in @('result.json', 'result_shown.json')) {
            $f = Join-Path $prof "updates\run\$n"
            if (Test-Path -LiteralPath $f) {
                Start-Sleep -Milliseconds 500
                try { return ([System.IO.File]::ReadAllText($f).TrimStart([char]0xFEFF) | ConvertFrom-Json) } catch { }
            }
        }
        Start-Sleep -Seconds 1
    }
    return $null
}
# After "Restart and install": NEXA must close within 30 s; otherwise the
# visible reason is kept for the report.
function Wait-Closed {
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        if (-not $script:proc -or $script:proc.HasExited) { return 'closed' }
        Start-Sleep -Milliseconds 500
    }
    $why = Find-El 'update' -Contains -TimeoutSec 2
    return "still open after 30 s: $(Label $why)"
}
function Close-Dialog { [void](Click-El (Find-El 'Close' -TimeoutSec 4)) }

# ---------------------------------------------------------------- setup
Say "work folder $Work"
$hashA = Folder-Hash $buildA
$hashB = Folder-Hash $buildB
& robocopy $buildA $prog /E /NFL /NDL /NJH /NJS /NP | Out-Null
Check 'D30-00' 'installed copy of 1.1.1 = build A' ((Folder-Hash $prog) -eq $hashA) "A $($hashA.Substring(0,12)), B $($hashB.Substring(0,12))"

$good = Join-Path $pkgDir 'good_1.1.2.zip'; $goodSha = New-Package $buildB '1.1.2' $good
$bad = Join-Path $pkgDir 'broken_1.1.2.zip'; $badSha = New-Package $buildB '1.1.2' $bad -BreakAppSo
$evil = Join-Path $pkgDir 'traversal_1.1.5.zip'; $evilSha = New-Package $buildB '1.1.5' $evil -Evil 'd030_evil.txt'
$corrupt = Join-Path $pkgDir 'corrupt_1.1.3.zip'
$bytes = [System.IO.File]::ReadAllBytes($good)
for ($i = 0; $i -lt 64; $i++) { $bytes[[int]($bytes.Length / 2) + $i] = $bytes[[int]($bytes.Length / 2) + $i] -bxor 0xFF }
[System.IO.File]::WriteAllBytes($corrupt, $bytes)
Say "packages: good $goodSha, broken $badSha, traversal $evilSha"

Serve @()
$server = Start-Process -FilePath 'cmd.exe' -ArgumentList '/d', '/c', "dart tools\d030\fake_github.dart `"$srv`" > `"$srv\server.log`" 2>&1" `
    -WorkingDirectory $Repo -WindowStyle Hidden -PassThru
$port = ''
for ($i = 0; $i -lt 120 -and -not $port; $i++) {
    Start-Sleep -Milliseconds 500
    if (Test-Path (Join-Path $srv 'port.txt')) { $port = (Get-Content (Join-Path $srv 'port.txt') -Raw).Trim() }
}
Check 'D30-01' 'local GitHub stand-in listens (127.0.0.1 only)' ([bool]$port) "port $port"

$pErr = Join-Path $profiles 'err'; $pMain = Join-Path $profiles 'main'; $pOff = Join-Path $profiles 'off'
$fp0 = Fingerprint (Join-Path $pMain 'nexa_library.sqlite')
$data0 = Data-Of $fp0
Check 'D30-02' 'test profiles seeded (songs, playlists, favourites, history, taste, settings)' ($fp0 -and $fp0.tracks -eq 6 -and $fp0.playlists.Count -eq 2 -and $fp0.history -eq 7) $data0

try {
    # ------------------------------------------------ updates switched off
    Serve @((Release 'v1.1.2' 12 $good $goodSha))
    $ok = Start-App $pOff
    Start-Sleep -Seconds 20
    $n = Requests 'GET /repos/KondexOFF/Nexa-Music/releases '
    $popup = Find-El 'Skip this version' -TimeoutSec 2
    Check 'D30-03' 'daily check switched off: no request, no notification' ($ok -and $n -eq 0 -and -not $popup) "started $ok, release requests $n"
    Stop-App

    # ------------------------------------------------ the notification
    $ok = Start-App $pErr
    $now = Find-El 'Update now' -TimeoutSec 45
    $new = Find-El "What's new" -TimeoutSec 3
    $later = Find-El 'Later' -TimeoutSec 3
    $skip = Find-El 'Skip this version' -TimeoutSec 3
    Check 'D30-04' 'daily check at start: notification with Update now / What''s new / Later / Skip this version' ($ok -and $now -and $new -and $later -and $skip) "requests $(Requests 'releases ')"
    [void](Click-El $new)
    $notes = Find-El 'D-030 test notes' -Contains -TimeoutSec 8
    Check 'D30-05' '"What''s new" shows the release notes' ([bool]$notes) (Label $notes)
    Close-Dialog
    [void](Click-El (Find-El 'Skip this version' -TimeoutSec 5))
    Start-Sleep -Seconds 2
    $gone = -not (Find-El 'Skip this version' -TimeoutSec 2)
    Stop-App
    $before = Requests 'GET /repos/KondexOFF/Nexa-Music/releases '
    $ok = Start-App $pErr
    Start-Sleep -Seconds 12
    $again = Find-El 'Skip this version' -TimeoutSec 2
    $after = Requests 'GET /repos/KondexOFF/Nexa-Music/releases '
    Check 'D30-06' 'at most once a day: no second automatic check after a restart' ($ok -and $after -eq $before) "requests $before -> $after"
    Open-Settings
    Manual-Check
    $skipped = Find-El 'Version 1.1.2 is skipped' -Contains -TimeoutSec 15
    Check 'D30-07' '"Skip this version": no notification; Settings > About still shows it' ($gone -and -not $again -and $skipped) (Label $skipped)

    # ------------------------------------------------ check results
    Serve @((Release 'v1.1.9' 19 $good $goodSha -Draft), (Release 'v1.2.0-rc.1' 20 $good $goodSha -Pre), (Release 'v1.1.1' 21 $good $goodSha))
    Manual-Check
    $e = Find-El 'is the newest version' -Contains -TimeoutSec 15
    Check 'D30-08' 'manual check: drafts and prereleases ignored, 1.1.1 is the newest' ([bool]$e) (Label $e)
    Serve @() '403-ratelimit'
    Manual-Check
    $e = Find-El 'rate limit' -Contains -TimeoutSec 15
    Check 'D30-09' 'GitHub rate limit is explained' ([bool]$e) (Label $e)
    Serve @() '404'
    Manual-Check
    $e = Find-El 'No releases were found' -Contains -TimeoutSec 15
    Check 'D30-10' 'not found / no access is explained' ([bool]$e) (Label $e)

    # ------------------------------------------------ refused packages
    function Try-Download([string]$expect) {
        Manual-Check
        $u = Find-Scroll 'Update now'
        [void](Click-El $u)
        return (Find-El $expect -Contains -TimeoutSec 90)
    }
    Serve @((Release 'v1.1.3' 13 $corrupt $goodSha))
    $e = Try-Download 'does not match its SHA-256'
    $staging = @(Get-ChildItem -LiteralPath (Join-Path $pErr 'updates\staging') -ErrorAction SilentlyContinue).Count
    Check 'D30-11' 'damaged download: SHA-256 differs, deleted, nothing installed' ($e -and $staging -eq 0 -and (Folder-Hash $prog) -eq $hashA) "$(Label $e); staging entries $staging"
    Close-Dialog
    Serve @((Release 'v1.1.4' 14 $good ''))
    $e = Try-Download 'has no SHA-256 checksum'
    Check 'D30-12' 'release without SHA-256: refused before downloading' ($e -and (Requests '/assets/14 ') -eq 0) (Label $e)
    Close-Dialog
    Serve @((Release 'v1.1.5' 15 $evil $evilSha))
    $e = Try-Download 'not safe to unpack'
    $leaked = @(Get-ChildItem -LiteralPath $Work -Recurse -Filter 'd030_evil.txt' -ErrorAction SilentlyContinue).Count
    Check 'D30-13' 'package with ../ (correct SHA-256): refused, nothing written outside' ($e -and $leaked -eq 0 -and (Folder-Hash $prog) -eq $hashA) "$(Label $e); evil files $leaked"
    Close-Dialog

    # ------------------------------------------------ failed start -> rollback
    Serve @((Release 'v1.1.2' 16 $bad $badSha))
    Manual-Check
    [void](Click-El (Find-Scroll 'Update now'))
    $restart = Find-El 'Restart and install' -TimeoutSec 120
    Clear-Result $pErr
    [void](Click-El $restart)
    $closed = Wait-Closed
    Say "after Restart and install: $closed"
    $r = Wait-Result $pErr 300
    $back = Attach-App 60
    $health = Get-Content -LiteralPath (Join-Path $pErr 'updates\run\health.txt') -Raw -ErrorAction SilentlyContinue
    Check 'D30-14' 'new version does not start: old program put back and started' ($r -and $r.state -eq 'failed_rolled_back' -and $back -and (Folder-Hash $prog) -eq $hashA -and "$health".Trim() -eq '1.1.1') "$($r.state): $($r.detail)"
    Check 'D30-15' 'previous version kept for a rollback' ((Folder-Hash (Join-Path $pErr 'updates\previous\1.1.1')) -eq $hashA) ''
    Stop-App

    # ------------------------------------------------ update with migration
    Serve @((Release 'v1.1.2' 12 $good $goodSha))
    $ok = Start-App $pMain
    $now = Find-El 'Update now' -TimeoutSec 45
    [void](Click-El $now)
    $pct = Find-El '%' -Contains -TimeoutSec 20
    $restart = Find-El 'Restart and install' -TimeoutSec 180
    Check 'D30-16' 'Update now: download with progress, SHA-256 checked, ready to install' ([bool]$restart) "progress seen: $(Label $pct)"
    Clear-Result $pMain
    [void](Click-El $restart)
    $closed = Wait-Closed
    Say "after Restart and install: $closed"
    $r = Wait-Result $pMain 300
    $up = Attach-App 60
    $db = Join-Path $pMain 'nexa_library.sqlite'
    $fp1 = Fingerprint $db
    Check 'D30-17' 'installed after NEXA closed; 1.1.2 starts; program = build B' ($r -and $r.state -eq 'ok' -and $r.to -eq '1.1.2' -and $up -and (Folder-Hash $prog) -eq $hashB) "$($r.state) $($r.detail)"
    Check 'D30-18' 'previous program kept = build A' ((Folder-Hash (Join-Path $pMain 'updates\previous\1.1.1')) -eq $hashA) ''
    $v4 = @(Get-ChildItem -LiteralPath (Join-Path $pMain 'backups') -Filter 'nexa_library_v4_*.sqlite' -ErrorAction SilentlyContinue)
    Check 'D30-19' 'database migrated (schema 5) with a copy made before' ((Schema $db) -eq 5 -and $v4.Count -ge 1 -and ($fp1.tables -contains 'd030_test_marker')) "schema $(Schema $db), copies $($v4.Count)"
    Check 'D30-20' 'library, playlists, favourites, history, taste and settings kept' ((Data-Of $fp1) -eq $data0) (Data-Of $fp1)
    Open-Settings
    $ver = Find-Scroll 'Version 1.1.2' -Contains
    $pl = Find-El 'Update Night Mix' -Contains -TimeoutSec 5
    Check 'D30-21' 'the updated app shows 1.1.2 and the playlists' ($ver -and $pl) (Label $ver)

    # ------------------------------------------------ rollback after migration
    $rb = Find-Scroll 'Roll back to 1.1.1'
    [void](Click-El $rb)
    $warn = Find-El 'cannot read it' -Contains -TimeoutSec 10
    Check 'D30-22' 'rollback explains the database copy and asks first' ([bool]$warn) (Label $warn)
    Clear-Result $pMain
    [void](Click-El (Find-El 'Roll back' -TimeoutSec 5))
    $r = Wait-Result $pMain 300
    $down = Attach-App 60
    Start-Sleep -Seconds 3
    $fp2 = Fingerprint $db
    Check 'D30-23' 'rolled back: 1.1.1 runs; program = build A' ($r -and $r.state -eq 'ok' -and $r.mode -eq 'rollback' -and $down -and (Folder-Hash $prog) -eq $hashA) "$($r.state) $($r.detail)"
    Check 'D30-24' 'database put back to the copy before the migration (schema 4), data kept' ((Schema $db) -eq 4 -and (Data-Of $fp2) -eq $data0) "schema $(Schema $db)"
    $kept = @(Get-ChildItem -LiteralPath (Join-Path $pMain 'backups') -Filter '*_before_rollback_*.sqlite' -ErrorAction SilentlyContinue)
    $fpk = if ($kept.Count) { Fingerprint $kept[0].FullName } else { $null }
    Check 'D30-25' 'newer library saved first (protected copy, schema 5) - no data lost' ($kept.Count -eq 1 -and $fpk.schema -eq 5 -and (Data-Of $fpk) -eq $data0) "$($kept.Count) copy"
    Open-Settings
    $ver = Find-Scroll 'Version 1.1.1' -Contains
    Check 'D30-26' '1.1.1 opens the library again' ([bool]$ver) (Label $ver)
    Stop-App

    # ------------------------------------------------ newer library in 1.1.1
    if ($kept.Count -ge 1 -and $v4.Count -ge 1) {
        $pNew = Join-Path $profiles 'newer'
        New-Item -ItemType Directory -Force -Path (Join-Path $pNew 'backups') | Out-Null
        Copy-Item -LiteralPath $kept[0].FullName -Destination (Join-Path $pNew 'nexa_library.sqlite')
        Copy-Item -LiteralPath $v4[0].FullName -Destination (Join-Path $pNew 'backups')
        $h0 = Sha (Join-Path $pNew 'nexa_library.sqlite')
        $ok = Start-App $pNew
        $msg = Find-El 'This library is from a newer NEXA' -TimeoutSec 20
        Check 'D30-27' '1.1.1 never opens a newer library; file unchanged' ($ok -and $msg -and (Sha (Join-Path $pNew 'nexa_library.sqlite')) -eq $h0) ''
        [void](Click-El (Find-El 'Put back' -Contains -TimeoutSec 5))
        $done = Find-El 'The copy was put back' -Contains -TimeoutSec 10
        $protected = @(Get-ChildItem -LiteralPath (Join-Path $pNew 'backups') -Filter '*_before_restore_*.sqlite').Count
        Check 'D30-28' 'it can put back the older copy, keeping the newer file' ($done -and (Schema (Join-Path $pNew 'nexa_library.sqlite')) -eq 4 -and $protected -eq 1) ''
        Stop-App
    } else {
        Check 'D30-27' '1.1.1 never opens a newer library; file unchanged' $false 'no newer library to test with (earlier steps failed)'
    }

    # ------------------------------------------------ the real private-capable account
    $pGh = Join-Path $profiles 'gh'
    New-Item -ItemType Directory -Force -Path $pGh | Out-Null
    $ok = Start-App $pGh -RealGitHub
    Start-Sleep -Seconds 8
    Open-Settings
    $e = $null
    for ($i = 0; $i -lt 8 -and -not $e; $i++) {
        $e = Find-Scroll 'is the newest version' -Contains
        if (-not $e) { Manual-Check }
    }
    $err = Find-El 'GitHub' -Contains -TimeoutSec 2
    Check 'D30-29' 'real GitHub through the signed-in GitHub CLI: v1.1.0 is older, 1.1.1 is the newest' ([bool]$e) "$(Label $e) $(if (-not $e) { Label $err })"
    Stop-App
} finally {
    Stop-App
    Get-CimInstance Win32_Process -Filter "Name='dart.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*fake_github.dart*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}

$auth = Requests 'auth=yes'
Check 'D30-30' 'NEXA never sent an Authorization header or cookie' ($auth -eq 0 -and (Requests ' -> ') -gt 0) "requests $(Requests ' -> '), with authorization $auth"
# GitHub token shapes (assembled here, so this file holds none itself).
$tokenShapes = @(('g' + 'h[opsu]_') + '[A-Za-z0-9]{20,}', ('github' + '_pat_') + '[A-Za-z0-9_]{20,}')
$leak = @(Get-ChildItem -LiteralPath $Work -Recurse -File -Include '*.log', '*.json', '*.txt' -ErrorAction SilentlyContinue |
        Where-Object { $_.Length -lt 5MB } | Select-String -Pattern $tokenShapes -List)
Check 'D30-31' 'no GitHub token in any log, plan or result' ($leak.Count -eq 0) "$($leak.Count) files"

$pass = @($results | Where-Object { $_.status -eq 'PASS' }).Count
$all = $results.Count
Say "SUMMARY $pass / $all PASS"
[System.IO.File]::WriteAllText((Join-Path $Work 'chain.json'), ($results | ConvertTo-Json -Depth 4), $utf8)
exit $(if ($pass -eq $all) { 0 } else { 1 })
