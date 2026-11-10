# M1 interactive Windows GUI QA. Runs ONLY on an unlocked, visible desktop.
# Never invoke without -ValidateOnly on GitHub-hosted noninteractive windows-latest.
param(
    [string]$ExePath = (Join-Path $PSScriptRoot "..\..\builds\AstralChronicle-M1-Windows-x64.exe"),
    [string]$EvidenceDir = (Join-Path $PSScriptRoot "..\..\qa_artifacts\windows_gui"),
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$win32Code = @'
using System;
using System.Runtime.InteropServices;
public static class M1WinGuiQA
{
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", SetLastError = true)] public static extern bool ClientToScreen(IntPtr handle, ref POINT point);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool GetClientRect(IntPtr handle, out RECT rect);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool GetWindowRect(IntPtr handle, out RECT rect);
    [DllImport("user32.dll", SetLastError = true)] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
}
'@
Add-Type -TypeDefinition $win32Code -ErrorAction Stop
if ($ValidateOnly) {
    Write-Host "WINDOWS GUI HARNESS VALIDATION PASS: PowerShell syntax and Win32 interop compiled; no GUI accessed."
    exit 0
}

if (-not [Environment]::UserInteractive) {
    throw "No interactive Windows user session; use an unlocked local desktop, not a GitHub-hosted Session 0 runner."
}
$desktop = [M1WinGuiQA]::OpenInputDesktop(0, $false, 1)
if ($desktop -eq [IntPtr]::Zero) {
    throw "OpenInputDesktop failed. Unlock a real user desktop; do not claim GUI QA success."
}
[M1WinGuiQA]::CloseDesktop($desktop) | Out-Null
$ExePath = (Resolve-Path -LiteralPath $ExePath).Path
if (-not (Test-Path -LiteralPath $ExePath -PathType Leaf)) { throw "EXE missing" }
if (-not (Test-Path -LiteralPath $EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
}
$EvidenceDir = (Resolve-Path -LiteralPath $EvidenceDir).Path

# Refuse to overwrite a developer's preexisting M1 save file. Use a clean QA account.
$savePath = Join-Path $env:APPDATA "Godot\app_userdata\Astral Chronicle\astral_dev_save_v1.json"
if (Test-Path -LiteralPath $savePath) {
    throw "Existing development save found at $savePath. Run this on a disposable/clean Windows QA account."
}

$processes = New-Object "System.Collections.Generic.List[System.Diagnostics.Process]"
$report = Join-Path $EvidenceDir "interactive_windows_qa.txt"
"Windows GUI real-desktop QA; EXE=$ExePath" | Set-Content -LiteralPath $report -Encoding UTF8

function Wait-Log([string]$File, [string]$Token, [int]$Seconds = 18) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if (Test-Path -LiteralPath $File) {
            try {
                $raw = Get-Content -LiteralPath $File -Raw -ErrorAction Stop
                if ($raw -and $raw.Contains($Token)) { return $raw }
            } catch { }
        }
        Start-Sleep -Milliseconds 200
    }
    throw "Timed out waiting for '$Token' in $File"
}
function Start-Game([string]$LogFile) {
    $argList = '--log-file "' + $LogFile + '"'
    $game = Start-Process -FilePath $ExePath -ArgumentList $argList -PassThru
    $processes.Add($game)
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while ([DateTime]::UtcNow -lt $deadline) {
        $game.Refresh()
        if ($game.HasExited) { throw "Godot GUI process exited unexpectedly" }
        if ($game.MainWindowHandle -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 250
    }
    $game.Refresh()
    if ($game.MainWindowHandle -eq [IntPtr]::Zero) { throw "Godot visible window not detected" }
    [M1WinGuiQA]::SetForegroundWindow($game.MainWindowHandle) | Out-Null
    Wait-Log $LogFile "M1_QA_WIN_CLIENT_TARGET SAVE" | Out-Null
    return $game
}
function Click-GameButton([System.Diagnostics.Process]$Game, [string]$LogFile, [string]$Name, [string]$Expected) {
    $raw = Get-Content -LiteralPath $LogFile -Raw
    $pattern = "M1_QA_WIN_CLIENT_TARGET " + $Name + " x=(\d+) y=(\d+) visible=1"
    $matches = [regex]::Matches($raw, $pattern)
    if ($matches.Count -lt 1) { throw "No visible Windows GUI center found for $Name" }
    $match = $matches[$matches.Count - 1]
    $target = New-Object M1WinGuiQA+POINT
    $target.X = [int]$match.Groups[1].Value
    $target.Y = [int]$match.Groups[2].Value
    $rect = New-Object M1WinGuiQA+RECT
    if (-not [M1WinGuiQA]::GetClientRect($Game.MainWindowHandle, [ref]$rect)) { throw "GetClientRect failed" }
    if ($target.X -lt 0 -or $target.Y -lt 0 -or $target.X -ge $rect.Right -or $target.Y -ge $rect.Bottom) {
        throw "Button $Name at ($($target.X),$($target.Y)) is outside the visible client ($($rect.Right)x$($rect.Bottom))"
    }
    if (-not [M1WinGuiQA]::ClientToScreen($Game.MainWindowHandle, [ref]$target)) { throw "ClientToScreen failed" }
    $bounds = [System.Windows.Forms.Screen]::FromHandle($Game.MainWindowHandle).Bounds
    if (-not $bounds.Contains($target.X, $target.Y)) { throw "Button $Name is off the visible monitor" }
    [M1WinGuiQA]::SetForegroundWindow($Game.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 160
    if (-not [M1WinGuiQA]::SetCursorPos($target.X, $target.Y)) { throw "SetCursorPos failed" }
    [M1WinGuiQA]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 95
    [M1WinGuiQA]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Wait-Log $LogFile $Expected | Out-Null
    "PASS $Name -> $Expected at screen ($($target.X),$($target.Y))" |
        Add-Content -LiteralPath $report -Encoding UTF8
}
function Capture-Game([System.Diagnostics.Process]$Game, [string]$Filename) {
    $rect = New-Object M1WinGuiQA+RECT
    if (-not [M1WinGuiQA]::GetWindowRect($Game.MainWindowHandle, [ref]$rect)) {
        throw "Cannot measure window rectangle for screenshot"
    }
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -lt 300 -or $h -lt 400) { throw "Unexpected GUI window dimensions $w x $h" }
    $bounds = [System.Windows.Forms.Screen]::FromHandle($Game.MainWindowHandle).Bounds
    if (-not $bounds.Contains($rect.Left, $rect.Top) -or
        -not $bounds.Contains($rect.Right - 1, $rect.Bottom - 1)) {
        throw "Whole game window is not visible. Move it fully onto the monitor before QA."
    }
    [M1WinGuiQA]::SetForegroundWindow($Game.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 350
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    try {
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $gfx.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
        } finally { $gfx.Dispose() }
        $bmp.Save((Join-Path $EvidenceDir $Filename), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $bmp.Dispose() }
    "CAPTURED $Filename $w x $h" | Add-Content -LiteralPath $report
}
function Stop-Game([System.Diagnostics.Process]$Game) {
    if ($null -ne $Game) {
        $Game.Refresh()
        if (-not $Game.HasExited) {
            Stop-Process -Id $Game.Id -Force -ErrorAction Stop
            $Game.WaitForExit(6000) | Out-Null
        }
    }
}

try {
    $log1 = Join-Path $EvidenceDir "windows_first_process.log"
    $log2 = Join-Path $EvidenceDir "windows_second_process.log"
    $first = Start-Game $log1
    Wait-Log $log1 "M1_QA_RESTORED turn=-1" | Out-Null
    Capture-Game $first "first_launch.png"
    Click-GameButton $first $log1 "STEP" "M1_QA_EVENT STEP turn=1"
    Click-GameButton $first $log1 "RESET" "M1_QA_EVENT RESET turn=0"
    Click-GameButton $first $log1 "STEP" "M1_QA_EVENT STEP turn=1"
    Click-GameButton $first $log1 "SAVE" "M1_QA_EVENT SAVE turn=1 success=1"
    Start-Sleep -Milliseconds 450
    Capture-Game $first "after_save.png"
    if (-not (Test-Path -LiteralPath $savePath)) {
        throw "Expected developer save file not found after GUI save click"
    }
    Stop-Game $first
    $second = Start-Game $log2
    Wait-Log $log2 "M1_QA_RESTORED turn=1" | Out-Null
    Capture-Game $second "after_restore.png"
    Stop-Game $second
    "WINDOWS INTERACTIVE GUI QA PASS: real mouse STEP RESET STEP SAVE and new process restored turn=1" |
        Tee-Object -FilePath $report -Append
    Write-Host "Review all three screenshots MANUALLY for typography, clipping, and errors; automation only confirms input/log events."
}
finally {
    foreach ($game in $processes) {
        Stop-Game $game
    }
    # This QA run refused preexisting data: delete only the disposable file it created.
    if (Test-Path -LiteralPath $savePath) {
        Remove-Item -LiteralPath $savePath -Force
    }
}
