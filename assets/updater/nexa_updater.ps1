# NEXA Update Center - the Windows updater (D-030).
#
# Started by NEXA Music with a plan (plan.json) just before NEXA closes:
#   1. waits until NEXA has closed;
#   2. install: keeps a copy of the current program in updates\previous;
#      rollback: keeps a safety copy of the current program;
#   3. puts the new program next to the old one and swaps the folders
#      (rename), or - when a folder cannot be renamed - copies it in place;
#   4. starts the new program and waits until it reports that it runs;
#   5. if it does not start, the old program is put back and started.
# The library, playlists, history and settings (%APPDATA%) are never
# touched; only a database restore that the user confirmed for a rollback
# is requested (restore_request.txt, done by NEXA itself at its start).
param([Parameter(Mandatory = $true)][string]$Plan)

$ErrorActionPreference = 'Stop'
$p = [System.IO.File]::ReadAllText($Plan, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

function Log([string]$m) {
    $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $m
    [System.IO.File]::AppendAllText($p.logFile, $line + "`r`n", (New-Object System.Text.UTF8Encoding $false))
}

function Write-Result([string]$state, [string]$detail) {
    $r = [ordered]@{ state = $state; mode = $p.mode; from = $p.oldVersion; to = $p.newVersion; detail = $detail; at = (Get-Date).ToString('o') }
    [System.IO.File]::WriteAllText($p.resultFile, ($r | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
    Log "result: $state $detail"
}

function Get-Stats([string]$dir) {
    $files = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction Stop)
    $bytes = 0
    foreach ($f in $files) { $bytes += $f.Length }
    return @($files.Count, $bytes)
}

function Copy-Folder([string]$from, [string]$to) {
    # A fresh copy, checked by file count and size.
    if (Test-Path -LiteralPath $to) { Remove-Item -LiteralPath $to -Recurse -Force }
    New-Item -ItemType Directory -Path $to -Force | Out-Null
    & robocopy $from $to /E /COPY:DAT /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy $from -> $to failed ($LASTEXITCODE)" }
    $a = Get-Stats $from; $b = Get-Stats $to
    if ($a[0] -ne $b[0] -or $a[1] -ne $b[1]) { throw "copy of $from incomplete ($($b[0])/$($a[0]) files)" }
}

function Mirror-Into([string]$from, [string]$to) {
    # In place: $to becomes exactly $from (files of $to not in $from go).
    & robocopy $from $to /MIR /COPY:DAT /R:3 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy /MIR $from -> $to failed ($LASTEXITCODE)" }
    $a = Get-Stats $from; $b = Get-Stats $to
    if ($a[0] -ne $b[0] -or $a[1] -ne $b[1]) { throw "mirror into $to incomplete" }
}

function Wait-Unlocked([string]$file, [int]$seconds) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        try {
            $s = [System.IO.File]::Open($file, 'Open', 'ReadWrite', 'None'); $s.Close(); return $true
        } catch { Start-Sleep -Milliseconds 300 }
    }
    return $false
}

function Start-Checked([string]$dir, [string]$version) {
    # Starts nexa_music.exe and waits until it writes its version into the
    # health file (after its database opened and its first frame).
    if (Test-Path -LiteralPath $p.healthFile) { Remove-Item -LiteralPath $p.healthFile -Force }
    $env:NEXA_UPDATE_HEALTH = $p.healthFile
    $proc = Start-Process -FilePath (Join-Path $dir $p.exeName) -WorkingDirectory $dir -PassThru
    $end = (Get-Date).AddSeconds([int]$p.startTimeoutSeconds)
    while ((Get-Date) -lt $end) {
        if (Test-Path -LiteralPath $p.healthFile) {
            # NEXA may still be writing it: read again a moment later.
            $v = $null
            try { $v = ([System.IO.File]::ReadAllText($p.healthFile)).Trim() } catch { }
            if ($v -eq $version) { return @($true, $proc, "started $version") }
            if ($v) { return @($false, $proc, "started version '$v', expected $version") }
        }
        if ($proc.HasExited) { return @($false, $proc, "exited with code $($proc.ExitCode)") }
        Start-Sleep -Milliseconds 400
    }
    return @($false, $proc, "no answer within $($p.startTimeoutSeconds) s")
}

$app = [System.IO.Path]::GetFullPath($p.appDir).TrimEnd('\')
$parent = Split-Path -Parent $app
$leaf = Split-Path -Leaf $app
$new = Join-Path $parent ".$leaf.nexa-new"
$old = Join-Path $parent ".$leaf.nexa-old"
$exe = Join-Path $app $p.exeName
Log "---- $($p.mode) $($p.oldVersion) -> $($p.newVersion), program folder $app"

# 1. NEXA closes.
try {
    $nexa = Get-Process -Id ([int]$p.pid) -ErrorAction Stop
    if (-not $nexa.WaitForExit(120000)) {
        Write-Result 'not_closed' 'NEXA did not close within 2 minutes; nothing was changed'
        exit 2
    }
} catch { }
if (-not (Wait-Unlocked $exe 60)) {
    Write-Result 'not_closed' 'nexa_music.exe is still in use; nothing was changed'
    exit 2
}
Log 'NEXA closed'

# Leftovers of an interrupted run: the program folder always wins back.
if ((Test-Path -LiteralPath $old) -and -not (Test-Path -LiteralPath $app)) {
    Move-Item -LiteralPath $old -Destination $app
    Log 'restored the program folder from an interrupted run'
}
foreach ($d in @($new, $old)) {
    if (Test-Path -LiteralPath $d) {
        $aside = "$d." + (Get-Date -Format 'yyyyMMddHHmmss')
        Move-Item -LiteralPath $d -Destination $aside
        Log "kept an older leftover as $aside"
    }
}

$swapped = $false
$inPlace = $false
try {
    # 2. A copy of the current program.
    if ($p.mode -eq 'install') {
        $keep = $p.previousDir
        Copy-Folder $app "$keep.tmp"
        if (Test-Path -LiteralPath $keep) { Remove-Item -LiteralPath $keep -Recurse -Force }
        Move-Item -LiteralPath "$keep.tmp" -Destination $keep
        $info = [ordered]@{ version = $p.oldVersion; schema = [int]$p.oldSchema; savedAt = (Get-Date).ToString('o') }
        [System.IO.File]::WriteAllText($p.previousInfo, ($info | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
        $safety = $keep
        Log "previous version kept in $keep"
    } else {
        Copy-Folder $app $p.safetyDir
        $safety = $p.safetyDir
        Log "current version kept in $safety"
    }

    # 3. The new program next to the old one, then the swap.
    Copy-Folder $p.source $new
    try {
        Move-Item -LiteralPath $app -Destination $old
        try {
            Move-Item -LiteralPath $new -Destination $app
        } catch {
            Move-Item -LiteralPath $old -Destination $app
            throw
        }
        $swapped = $true
        Log 'folders swapped'
    } catch {
        Log "rename not possible ($($_.Exception.Message)); copying in place"
        if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Recurse -Force }
        $inPlace = $true
        Mirror-Into $p.source $app
        Log 'copied in place'
    }

    if ($p.restoreRequest -and $p.restoreBackup) {
        [System.IO.File]::WriteAllText($p.restoreRequest, [string]$p.restoreBackup, (New-Object System.Text.UTF8Encoding $false))
        Log "database restore requested: $($p.restoreBackup)"
    }

    # 4. The new program starts.
    $r = Start-Checked $app $p.newVersion
    if ($r[0]) {
        if ($swapped -and (Test-Path -LiteralPath $old)) { Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue }
        if ($p.mode -eq 'install' -and (Test-Path -LiteralPath $p.source)) { Remove-Item -LiteralPath $p.source -Recurse -Force -ErrorAction SilentlyContinue }
        if ($p.mode -ne 'install' -and (Test-Path -LiteralPath $p.safetyDir)) { Remove-Item -LiteralPath $p.safetyDir -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Result 'ok' $r[2]
        exit 0
    }
    throw "the new program did not start: $($r[2])"
} catch {
    $why = $_.Exception.Message
    Log "FAILED: $why"
    # 5. Back to the old program.
    try {
        Get-Process -Name ([System.IO.Path]::GetFileNameWithoutExtension($p.exeName)) -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -and $_.Path.StartsWith($app, [System.StringComparison]::OrdinalIgnoreCase) } |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        [void](Wait-Unlocked $exe 30)
        if ($p.restoreRequest -and (Test-Path -LiteralPath $p.restoreRequest)) {
            Remove-Item -LiteralPath $p.restoreRequest -Force
            Log 'database restore request withdrawn'
        }
        if ($swapped -and (Test-Path -LiteralPath $old)) {
            Remove-Item -LiteralPath $app -Recurse -Force
            Move-Item -LiteralPath $old -Destination $app
            Log 'old program folder put back'
        } elseif ($inPlace -or -not (Test-Path -LiteralPath $exe)) {
            Mirror-Into $safety $app
            Log 'old program copied back'
        }
        if (Test-Path -LiteralPath $new) { Remove-Item -LiteralPath $new -Recurse -Force -ErrorAction SilentlyContinue }
        $back = Start-Checked $app $p.oldVersion
        Write-Result 'failed_rolled_back' "$why; $($back[2])"
        exit 1
    } catch {
        Write-Result 'failed' "$why; putting the old program back failed: $($_.Exception.Message). A copy is in $safety"
        exit 3
    }
}
