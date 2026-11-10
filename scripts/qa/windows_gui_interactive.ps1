#requires -Version 5.1
<#
.SYNOPSIS
  M1 Windows local interactive GUI QA for the standalone DEBUG EXE (unlocked desktop only).
.DESCRIPTION
  Sends REAL Windows cursor clicks, captures window screenshots, and verifies the
  debug-only turn save across two independent processes. Not suitable for a locked
  Session-0 GitHub-hosted runner. Uses an isolated APPDATA sandbox.
.EXAMPLE
  pwsh -NoProfile -File scripts/qa/windows_gui_interactive.ps1 -ExePath builds/AstralChronicle-M1-Windows-x64.exe
#>
param(
  [Parameter(Mandatory=$true)][string] $ExePath,
  [string] $OutputDir = "qa_artifacts/windows_gui"
)
$ErrorActionPreference = "Stop"
$exe = (Resolve-Path -LiteralPath $ExePath).Path
if (-not $exe.ToLowerInvariant().EndsWith(".exe")) { throw "Specify a Windows debug executable." }
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AstralDesktopQAWin32 {
    [StructLayout(LayoutKind.Sequential)] public struct Point { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hwnd, ref Point pt);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
$baseDir = [IO.Path]::GetFullPath($OutputDir)
$runDir = Join-Path $baseDir ("run-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 6)))
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$sandbox = Join-Path $runDir "isolated_appdata"
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$oldAppData = $env:APPDATA
$env:APPDATA = $sandbox
$proc = $null
$logFile = ""
$report = Join-Path $runDir "windows-gui-e2e-report.txt"

function Read-Log {
    if (-not (Test-Path -LiteralPath $script:logFile)) { return "" }
    try { return [IO.File]::ReadAllText($script:logFile) }
    catch { return "" }
}
function Wait-Log([string]$needle, [int]$offset = 0, [int]$seconds = 25) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        $script:proc.Refresh()
        if ($script:proc.HasExited) { throw "App exited before log marker: $needle" }
        $all = Read-Log
        if ($all.Length -ge $offset -and $all.Substring($offset).Contains($needle)) { return }
        Start-Sleep -Milliseconds 250
    }
    throw "Missing QA event in Windows game log: $needle"
}
function Start-Game([string]$label) {
    $script:logFile = Join-Path $runDir ($label + ".log")
    $args = '--log-file "' + $script:logFile + '"'
    $script:proc = Start-Process -FilePath $exe -ArgumentList $args -PassThru
    Wait-Log "M1_UI_READY:" 0 40
    Wait-Log "M1_QA_TARGET STEP" 0 15
    Wait-Log "M1_QA_USERDATA=" 0 10
    # Refuse to modify the person's normal Godot save directory.
    $paths = [regex]::Matches((Read-Log), "M1_QA_USERDATA=([^\r\n]+)")
    if ($paths.Count -lt 1) { throw "Godot did not report its user-data directory" }
    $actual = [IO.Path]::GetFullPath($paths[$paths.Count - 1].Groups[1].Value.Trim())
    $prefix = [IO.Path]::GetFullPath($sandbox).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $actual.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "ABORT: Godot user data resolves OUTSIDE test sandbox ($actual). No clicks or saves performed."
    }

    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        $script:proc.Refresh()
        if ($script:proc.MainWindowHandle -ne [IntPtr]::Zero) { return }
        Start-Sleep -Milliseconds 250
    }
    throw "No interactive window handle. Run this locally on an unlocked Windows desktop, not a CI service."
}
function Target-Coordinate([string]$action) {
    $log = Read-Log
    $matches = [regex]::Matches($log, "M1_QA_TARGET $action x=(\d+) y=(\d+) visible=(\d)")
    if ($matches.Count -lt 1) { throw "No debug UI geometry for $action" }
    $entry = $matches[$matches.Count - 1]
    if ($entry.Groups[3].Value -ne "1") { throw "Button $action is outside the visible scroll view" }
    $point = New-Object AstralDesktopQAWin32+Point
    $point.X = [int]$entry.Groups[1].Value
    $point.Y = [int]$entry.Groups[2].Value
    $handle = $script:proc.MainWindowHandle
    if (-not [AstralDesktopQAWin32]::ClientToScreen($handle, [ref]$point)) { throw "ClientToScreen failed" }
    return $point
}
function Click-Action([string]$action, [string]$eventMarker) {
    $start = (Read-Log).Length
    $point = Target-Coordinate $action
    $hwnd = $script:proc.MainWindowHandle
    if (-not [AstralDesktopQAWin32]::SetForegroundWindow($hwnd)) {
       throw "Windows refused to foreground the game. Unlock the desktop and close focus-stealing dialogs."
    }
    Start-Sleep -Milliseconds 220
    if (-not [AstralDesktopQAWin32]::SetCursorPos($point.X, $point.Y)) { throw "Cannot move desktop cursor" }
    Start-Sleep -Milliseconds 90
    [AstralDesktopQAWin32]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 110
    [AstralDesktopQAWin32]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
    Wait-Log $eventMarker $start 15
    Add-Content -Path $report -Value "PASS $action at $($point.X),$($point.Y): $eventMarker"
}
function Capture-Window([string]$label) {
    $rect = New-Object AstralDesktopQAWin32+Rect
    if (-not [AstralDesktopQAWin32]::GetWindowRect($script:proc.MainWindowHandle, [ref]$rect)) {
        throw "GetWindowRect failed"
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 300 -or $height -lt 400) { throw "Game window dimensions invalid: $width x $height" }
    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    try {
        $graphics = [Drawing.Graphics]::FromImage($bmp)
        try {
            $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
        } finally { $graphics.Dispose() }
        $filename = Join-Path $runDir ($label + ".png")
        $bmp.Save($filename, [Drawing.Imaging.ImageFormat]::Png)
        $samples = New-Object "System.Collections.Generic.HashSet[string]"
        for ($y = 25; $y -lt $height-25; $y += 23) {
            for ($x = 25; $x -lt $width-25; $x += 23) {
                $pixel = $bmp.GetPixel($x, $y)
                [void]$samples.Add("$($pixel.R),$($pixel.G),$($pixel.B)")
            }
        }
        if ($samples.Count -lt 8) { throw "Screenshot is nearly uniform/black; not valid visual proof" }
        Add-Content -Path $report -Value "SCREENSHOT $label $width x $height color_samples=$($samples.Count)"
    } finally { $bmp.Dispose() }
}
try {
    Add-Content -Path $report -Value "M1 WINDOWS INTERACTIVE DESKTOP QA START"
    Add-Content -Path $report -Value "EXE: $exe"
    Add-Content -Path $report -Value "ISOLATED APPDATA: $sandbox"
    Start-Game "initial"
    Capture-Window "initial"
    Click-Action "STEP" "M1_QA_EVENT STEP turn=1"
    Click-Action "RESET" "M1_QA_EVENT RESET turn=0"
    Click-Action "STEP" "M1_QA_EVENT STEP turn=1"
    Click-Action "SAVE" "M1_QA_EVENT SAVE turn=1 success=1"
    Start-Sleep -Milliseconds 450
    Capture-Window "after_save"
    $firstId = $proc.Id
    Stop-Process -Id $firstId -Force
    $proc.WaitForExit(10000) | Out-Null
    Start-Game "after_restart"
    Wait-Log "M1_QA_RESTORED turn=1" 0 15
    if ($firstId -eq $proc.Id) { throw "PID unchanged; cannot prove independent process restart" }
    Capture-Window "after_restart"
    Add-Content -Path $report -Value "PASS: independent Windows process $firstId -> $($proc.Id), restored turn 1"
    Write-Host "WINDOWS REAL-DESKTOP QA PASS: $runDir"
} catch {
    Add-Content -Path $report -Value ("FAIL: " + $_.Exception.Message)
    throw
} finally {
    if ($null -ne $proc) {
        $proc.Refresh()
        if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    }
    $env:APPDATA = $oldAppData
}
