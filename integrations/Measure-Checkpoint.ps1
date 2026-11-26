# Run from a fresh PowerShell 7 process. All renderer writes use a per-run working directory.
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Executable,
    [Parameter(Mandatory)][string]$Game,
    [Parameter(Mandatory)][string]$ProfileSeed,
    [Parameter(Mandatory)][string]$CacheSeed,
    [Parameter(Mandatory)][string]$LauncherDefaults,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][ValidateSet('load','intro','prison','exterior','driving','transition','soak')][string]$Scenario,
    [ValidateSet('Warm','ColdShaders')][string]$CacheMode = 'Warm',
    [ValidateSet('series-s','series-x')][string]$Console = 'series-s',
    [ValidateRange(1,86400)][int]$Seconds = 425,
    [ValidateRange(1,16384)][int]$BufferMiB = 512,
    [string]$Keys = '',
    [switch]$TraceBuilder,
    [switch]$PackTextureHeaps,
    [ValidatePattern('^[A-Za-z]:$')][string]$RequireDrive
)
$ErrorActionPreference = 'Stop'
$exe = (Get-Item -LiteralPath $Executable).FullName
$gameFile = (Get-Item -LiteralPath $Game).FullName
$profile = (Get-Item -LiteralPath $ProfileSeed).FullName
$cache = (Get-Item -LiteralPath $CacheSeed).FullName
$defaults = (Get-Item -LiteralPath $LauncherDefaults).FullName
$dest = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputRoot)
if ($RequireDrive) {
    foreach ($path in $exe,$gameFile,$profile,$cache,$defaults,$dest) {
        if ([IO.Path]::GetPathRoot($path).TrimEnd('\') -ne $RequireDrive) {
            throw "Expected every benchmark path on $RequireDrive but received $path"
        }
    }
}
foreach ($seed in $profile,$cache) {
    $prefix = $seed.TrimEnd('\') + '\'
    if (($dest.TrimEnd('\') + '\').StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'OutputRoot must be outside the seed directories'
    }
}
if (Get-Process | Where-Object { $_.ProcessName -match '^(victory.*|scripted|stock|queue|game_scarlett_master)$' }) {
    throw 'A renderer is already running'
}
$run = Join-Path $dest ("{0}-{1}-{2:yyyyMMdd-HHmmss}-{3}" -f $Scenario,$CacheMode,(Get-Date),([guid]::NewGuid().ToString('N').Substring(0,8)))
New-Item -ItemType Directory -Path $run | Out-Null
Copy-Item -LiteralPath $profile -Destination "$run/data" -Recurse
if ($CacheMode -eq 'Warm') {
    Copy-Item -LiteralPath $cache -Destination "$run/cache" -Recurse
} else {
    New-Item -ItemType Directory -Path "$run/cache" | Out-Null
    # Keep loader images constant while starting both shader and PSO caches empty.
    foreach ($hint in 'early-pipelines.txt','slow-pipelines.txt') {
        if (Test-Path -LiteralPath "$cache/pipelines/$hint") {
            [void][IO.Directory]::CreateDirectory("$run/cache/pipelines")
            Copy-Item -LiteralPath "$cache/pipelines/$hint" -Destination "$run/cache/pipelines/$hint"
        }
    }
    if (Test-Path -LiteralPath "$cache/images") {
        Copy-Item -LiteralPath "$cache/images" -Destination "$run/cache/images" -Recurse
    }
}
$settings = [ordered]@{}
foreach ($line in Get-Content -LiteralPath $defaults) {
    if ($line -match '^if not defined (VICTORY_\w+) set "\1=([0-9.]+)"$') {
        $settings[$Matches[1]] = $Matches[2]
    }
}
$settings['VICTORY_DATA_DIR'] = "$run/data"
$settings['VICTORY_CACHE_DIR'] = "$run/cache"
$settings['VICTORY_CARD_BUFFERS_MB'] = [string]$BufferMiB
$settings['VICTORY_BENCH_PRESENTS'] = '1'
$settings['VICTORY_FRAME_LOG'] = '1'
$settings['VICTORY_LOG'] = 'warn,checkpoint_bench=info,victory_gpu::ambient=info'
if ($Keys) { $settings['VICTORY_KEYS'] = $Keys }
if ($PackTextureHeaps) { $settings['VICTORY_PACK_TEXTURE_HEAPS'] = '1' }
if ($TraceBuilder) {
    $settings['VICTORY_BVH_BUILDER'] = '1'
    $settings['VICTORY_LOG'] += ',victory_gpu::pipeline=info'
}
$profileFiles = Get-ChildItem -LiteralPath "$run/data" -File -Recurse | Where-Object {
    $_.FullName -match '[\\/]saves[\\/]' -or $_.Name -eq 'settings.xml'
} | ForEach-Object {
    [ordered]@{path=[IO.Path]::GetRelativePath("$run/data",$_.FullName); sha256=(Get-FileHash -LiteralPath $_.FullName).Hash}
}
$pso = "$run/cache/pipelines/host-pipelines.bin"
$shaderCount = 0
if (Test-Path -LiteralPath "$run/cache/shaders") {
    $shaderCount = (Get-ChildItem -LiteralPath "$run/cache/shaders" -File -Recurse | Measure-Object).Count
}
$manifest = [ordered]@{
    scenario=$Scenario; console=$Console; renderer=(Get-FileHash -LiteralPath $exe).Hash
    guest=(Get-FileHash -LiteralPath $gameFile).Hash; profile=@($profileFiles)
    cacheSeed=$cache; cacheMode=$CacheMode; initialPsoSha256=if (Test-Path -LiteralPath $pso) {(Get-FileHash -LiteralPath $pso).Hash}
    initialShaderEntries=$shaderCount; seconds=$Seconds; settings=$settings; launcherDefaults=(Get-FileHash -LiteralPath $defaults).Hash
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$run/manifest.json"
$info = [Diagnostics.ProcessStartInfo]::new($exe)
$info.UseShellExecute = $false
$info.WorkingDirectory = $run
foreach ($name in @($info.Environment.Keys)) {
    if ($name -like 'VICTORY_*') { [void]$info.Environment.Remove($name) }
}
foreach ($name in $settings.Keys) { $info.Environment[$name] = $settings[$name] }
$tempDirectory = [IO.Directory]::CreateDirectory("$run/tmp").FullName
$info.Environment['TEMP'] = $tempDirectory
$info.Environment['TMP'] = $tempDirectory
$info.Environment['RUST_LOG'] = $settings['VICTORY_LOG']
foreach ($arg in 'run',$gameFile,'--console',$Console,'--execute') { $info.ArgumentList.Add($arg) }
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$stdout = [IO.File]::Open("$run/out.log", "CreateNew", "Write", "Read")
$stderr = [IO.File]::Open("$run/err.log", "CreateNew", "Write", "Read")
$p = [Diagnostics.Process]::Start($info)
$startUtc = $p.StartTime.ToUniversalTime().ToString("o")
$outCopy = $p.StandardOutput.BaseStream.CopyToAsync($stdout)
$errCopy = $p.StandardError.BaseStream.CopyToAsync($stderr)
$timedStop = $false
Write-Output $run
try {
    $clock=[Diagnostics.Stopwatch]::StartNew()

    while(!$p.WaitForExit([Math]::Min(15000, [Math]::Max(1, $Seconds * 1000 - [int]$clock.ElapsedMilliseconds)))) {
        $p.Refresh()
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) {
            try {
                Add-Type -AssemblyName System.Drawing
                if (!('VictoryCapture' -as [type])) {
                    Add-Type 'using System;using System.Runtime.InteropServices; public class VictoryCapture {[DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags); [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hwnd,out Rect r); public struct Rect { public int x,y,w,h; }}'
                }
                $rect = New-Object VictoryCapture+Rect
                if ([VictoryCapture]::GetClientRect($p.MainWindowHandle,[ref]$rect) -and $rect.w -gt 0 -and $rect.h -gt 0) {
                    $bmp = [Drawing.Bitmap]::new($rect.w,$rect.h)
                    $g = [Drawing.Graphics]::FromImage($bmp)
                    $dc = $g.GetHdc()
                    try { $ok = [VictoryCapture]::PrintWindow($p.MainWindowHandle,$dc,3) } finally { $g.ReleaseHdc($dc); $g.Dispose() }
                    if ($ok) {
                        if (!(Test-Path "$run/client-size.txt")) {"$($rect.w)x$($rect.h)" | Set-Content "$run/client-size.txt"}
                        $utc=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        $preview=$bmp.GetThumbnailImage(760,[int]($bmp.Height*760/$bmp.Width),$null,[IntPtr]::Zero)
                        try {$preview.Save("$run\frame-$utc.png",[Drawing.Imaging.ImageFormat]::Png)} finally {$preview.Dispose()}
                    }
                    $bmp.Dispose()
                }
            } catch { Write-Warning $_ }
        }
        if ($clock.Elapsed.TotalSeconds -lt $Seconds) {continue}
        $timedStop = $true
        [void]$p.CloseMainWindow()
        if (!$p.WaitForExit(10000)) { $p.Kill(); $p.WaitForExit() }
    }
} finally {
    if (!$p.HasExited) { $p.Kill(); $p.WaitForExit() }
    try {
        [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($outCopy,$errCopy))
    } finally {
        $stdout.Dispose()
        $stderr.Dispose()
    }
    [ordered]@{ startUtc=$startUtc; exitCode=$p.ExitCode; timedStop=$timedStop; elapsedSeconds=$clock.Elapsed.TotalSeconds } |
        ConvertTo-Json | Set-Content -LiteralPath "$run/result.json"
    $pExit = $p.ExitCode
    $p.Dispose()
}
if (!$timedStop -and $pExit -ne 0) { throw "Renderer exited with code $pExit. See $run/err.log" }
