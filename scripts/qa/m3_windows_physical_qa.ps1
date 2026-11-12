# M3 actual Windows desktop acceptance: MANUAL, never automated CI GUI proof.
# Requires an unlocked *real* user desktop, and a disposable Windows QA profile.
# Does not modify another user profile or issue success without manual observations.
param(
    [string]$ExePath = (Join-Path $PSScriptRoot "..\..\builds\AstralChronicle-M1-Windows-x64.exe"),
    [string]$EvidenceDir = (Join-Path $PSScriptRoot "..\..\qa_artifacts\m3_windows_physical"),
    [switch]$ValidateOnly
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$win32 = @'
using System;
using System.Runtime.InteropServices;
public static class M3PhysicalWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll", SetLastError = true)]
    public static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool CloseDesktop(IntPtr handle);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out RECT rect);
}
'@
Add-Type -TypeDefinition $win32 -ErrorAction Stop
if ($ValidateOnly) {
    Write-Host "M3 WINDOWS QA HARNESS VALIDATION PASS: PowerShell and Win32 interop only; no real GUI tested"
    exit 0
}
if (-not [Environment]::UserInteractive) {
    throw "No interactive Windows account. Refusing Session 0 / CI as physical GUI QA."
}
$desktop = [M3PhysicalWindow]::OpenInputDesktop(0, $false, 1)
if ($desktop -eq [IntPtr]::Zero) { throw "Cannot access unlocked interactive desktop" }
[M3PhysicalWindow]::CloseDesktop($desktop) | Out-Null
$ExePath = (Resolve-Path -LiteralPath $ExePath -ErrorAction Stop).Path
if (-not (Test-Path $ExePath -PathType Leaf)) { throw "Windows exported EXE not found" }
$save = Join-Path $env:APPDATA "Godot\app_userdata\Astral Chronicle\astral_profile_v2.json"
if (Test-Path -LiteralPath $save) {
    throw "Existing M3 save found: $save. Protect it: run in a separate disposable Windows QA account."
}
New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
$EvidenceDir = (Resolve-Path -LiteralPath $EvidenceDir).Path
$report = Join-Path $EvidenceDir "acceptance.txt"
$stamp = (Get-Date).ToString("o")
"UNVERIFIED PHYSICAL M3 QA - tester evidence, not independent approval" | Set-Content -LiteralPath $report -Encoding utf8
"Time=$stamp" | Add-Content -LiteralPath $report
"OS=$([Environment]::OSVersion.VersionString); machine=$env:COMPUTERNAME" | Add-Content -LiteralPath $report
"EXE_SHA256=$((Get-FileHash -LiteralPath $ExePath -Algorithm SHA256).Hash)" | Add-Content -LiteralPath $report
$game = $null

function WaitForLog([string]$path, [string]$token) {
    $limit = [DateTime]::UtcNow.AddSeconds(60)
    while ([DateTime]::UtcNow -lt $limit) {
        if (Test-Path -LiteralPath $path) {
            $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
            if ($content -and $content.Contains($token)) { return }
        }
        Start-Sleep -Milliseconds 350
    }
    throw "Expected Godot log '$token' not observed within 60 seconds: $path"
}
function OpenGame([string]$log) {
    $args = '--log-file "' + $log + '"'
    $proc = Start-Process -FilePath $ExePath -ArgumentList $args -PassThru
    $limit = [DateTime]::UtcNow.AddSeconds(30)
    while ([DateTime]::UtcNow -lt $limit) {
        $proc.Refresh()
        if ($proc.HasExited) { throw "Exported Godot game exited before GUI was visible" }
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) { break }
        Start-Sleep -Milliseconds 300
    }
    $proc.Refresh()
    if ($proc.MainWindowHandle -eq [IntPtr]::Zero) { throw "No real visible game window handle" }
    WaitForLog $log "M1_UI_READY:"
    return $proc
}
function Capture([System.Diagnostics.Process]$proc, [string]$filename) {
    $proc.Refresh()
    if ($proc.HasExited -or $proc.MainWindowHandle -eq [IntPtr]::Zero) { throw "Game window not visible" }
    $rect = New-Object M3PhysicalWindow+RECT
    if (-not [M3PhysicalWindow]::GetWindowRect($proc.MainWindowHandle, [ref]$rect)) { throw "Win32 GetWindowRect failed" }
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -lt 320 -or $h -lt 600) { throw "Game window too small for screenshot ($w x $h)" }
    $area = [System.Windows.Forms.Screen]::FromHandle($proc.MainWindowHandle).Bounds
    if (-not $area.Contains($rect.Left, $rect.Top) -or -not $area.Contains($rect.Right - 1, $rect.Bottom - 1)) {
        throw "Move the entire game window onto one visible monitor before screenshot."
    }
    Start-Sleep -Milliseconds 500
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    try {
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        try { $gfx.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size) } finally { $gfx.Dispose() }
        $bmp.Save((Join-Path $EvidenceDir $filename), [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $bmp.Dispose() }
    "CAPTURED $filename ($w x $h)" | Add-Content -LiteralPath $report
}
function ConfirmAndCapture([System.Diagnostics.Process]$proc, [string]$label, [string]$file) {
    Write-Host ""
    Write-Host "직접 게임 창에서 $label 확인 후, 이 콘솔에 PASS 또는 FAIL을 입력하세요."
    $answer = (Read-Host "물리 기기 육안 판정").Trim().ToUpperInvariant()
    "MANUAL $label = $answer" | Add-Content -LiteralPath $report
    if ($answer -ne "PASS") { throw "Manual check not passed: $label" }
    Capture $proc $file
}
function ReadProfile([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "M3 profile save missing: $path" }
    $envData = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($envData.file_format -ne 1 -or -not $envData.payload_text) { throw "Malformed M3 save envelope" }
    $payload = [string]$envData.payload_text
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($payload))).ToLowerInvariant()
    if ($hash -ne [string]$envData.sha256) { throw "M3 checksum mismatch" }
    $profile = $payload | ConvertFrom-Json -AsHashtable
    if ($profile.schema_version -ne 2 -or $profile.heroes.Count -ne 8) { throw "Profile schema/roster mismatch" }
    return $profile
}
function CloseGame([System.Diagnostics.Process]$proc) {
    $proc.Refresh()
    if ($proc.HasExited) { return }
    if (-not $proc.CloseMainWindow()) { throw "Game refused normal OS window close" }
    if (-not $proc.WaitForExit(15000)) { throw "Game did not close after a normal close request; do not force terminate" }
}

try {
    $firstLog = Join-Path $EvidenceDir "first.log"
    $game = OpenGame $firstLog
    Write-Host "게임에서 '동료 성장·장비 화면 열기'를 실제 마우스로 클릭하십시오."
    WaitForLog $firstLog "M3_UI_READY:"
    ConfirmAndCapture $game "성장 탭: 8명 선택, 한글, 레벨·승급 버튼 비활성 및 폰트/잘림" "01_growth.png"
    ConfirmAndCapture $game "장비 탭: 무기·방어구·장신구 2슬롯, 빈 인벤토리 안내, 스크롤" "02_gear.png"
    ConfirmAndCapture $game "방치 탭: 최대 8시간/80% 정책과 수령 버튼 상태, 글자 겹침 없음" "03_idle.png"
    CloseGame $game
    $game = $null
    $p1 = ReadProfile $save
    "PROFILE_REVISION_BEFORE_RESTART=$($p1.revision)" | Add-Content -LiteralPath $report
    $secondLog = Join-Path $EvidenceDir "restart.log"
    $game = OpenGame $secondLog
    Write-Host "다시 실제 마우스로 M3 화면에 진입하고 같은 8명/재화/장비 상태를 확인하십시오."
    WaitForLog $secondLog "M3_UI_READY:"
    ConfirmAndCapture $game "게임 재실행 후 8명/재화/장비/한글 상태 복구" "04_restart.png"
    $p2 = ReadProfile $save
    if ($p1.economy_state.seen_events.Count -ne $p2.economy_state.seen_events.Count) {
        throw "Unexpected receipt count changed during restart"
    }
    "PROFILE_REVISION_AFTER_RESTART=$($p2.revision)" | Add-Content -LiteralPath $report
    CloseGame $game
    $game = $null
    "M3 WINDOWS PHYSICAL QA EVIDENCE COLLECTED: screenshot/logs recorded; screenshots require independent review" |
        Tee-Object -FilePath $report -Append
} finally {
    if ($null -ne $game) {
        $game.Refresh()
        if (-not $game.HasExited) {
            Write-Warning "QA aborted: close the game manually to retain any saved progress."
        }
    }
}
