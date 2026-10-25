param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('ScreenshotWindow' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;

public class ScreenshotWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hwnd, out Rect rect);
    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out Rect rect, int size);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr param);
    public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr param);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr dc, uint flags);
    [DllImport("user32.dll")]
    public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);

    public static IntPtr Find(uint pid) {
        IntPtr result = IntPtr.Zero;
        EnumWindows((hwnd, param) => {
            uint owner;
            Rect rect;
            GetWindowThreadProcessId(hwnd, out owner);
            if (owner == pid && IsWindowVisible(hwnd) && GetWindowRect(hwnd, out rect)
                && rect.Right > rect.Left && rect.Bottom > rect.Top) {
                result = hwnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }
}
'@
}

$process = $bitmap = $graphics = $cropped = $null
# Use physical pixels for both Win32 and DWM bounds (per-monitor DPI aware v2).
$previousDpi = [ScreenshotWindow]::SetThreadDpiAwarenessContext([IntPtr](-4))
if ($previousDpi -eq [IntPtr]::Zero) { throw 'Could not set DPI awareness' }
try {
    $process = Start-Process -FilePath ".\$AppName" -PassThru
    $window = [IntPtr]::Zero
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        $window = [ScreenshotWindow]::Find([uint32]$process.Id)
        if ($window -ne [IntPtr]::Zero -or $process.HasExited) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($window -eq [IntPtr]::Zero) { throw "No application window found for $AppName" }

    [void][ScreenshotWindow]::ShowWindow($window, 9) # SW_RESTORE
    [void][ScreenshotWindow]::SetForegroundWindow($window)
    Start-Sleep -Seconds 1
    $rect = New-Object ScreenshotWindow+Rect
    if (![ScreenshotWindow]::GetWindowRect($window, [ref]$rect)) {
        throw "Could not get window bounds for $AppName"
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) { throw 'Invalid window bounds' }

    $bitmap = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    try {
        # PW_RENDERFULLCONTENT: capture this window even if another window overlaps it.
        if (![ScreenshotWindow]::PrintWindow($window, $dc, 2)) {
            throw "PrintWindow failed for $AppName"
        }
    }
    finally { $graphics.ReleaseHdc($dc) }

    # Trim the invisible resize border using DWM's visible frame bounds.
    $frame = New-Object ScreenshotWindow+Rect
    if ([ScreenshotWindow]::DwmGetWindowAttribute($window, 9, [ref]$frame, 16) -ne 0) {
        $frame = $rect
    }
    $crop = [System.Drawing.Rectangle]::FromLTRB(
        [Math]::Max(0, $frame.Left - $rect.Left),
        [Math]::Max(0, $frame.Top - $rect.Top),
        [Math]::Min($width, $frame.Right - $rect.Left),
        [Math]::Min($height, $frame.Bottom - $rect.Top)
    )
    if ($crop.Width -le 0 -or $crop.Height -le 0) { throw 'Invalid visible frame bounds' }
    $cropped = $bitmap.Clone($crop, $bitmap.PixelFormat)
    $OutputFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputFile)
    New-Item -ItemType Directory -Path (Split-Path -Parent $OutputFile) -Force | Out-Null
    $cropped.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Saved window screenshot: $OutputFile"
}
finally {
    if ($cropped) { $cropped.Dispose() }
    if ($graphics) { $graphics.Dispose() }
    if ($bitmap) { $bitmap.Dispose() }
    if ($process -and !$process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    [void][ScreenshotWindow]::SetThreadDpiAwarenessContext($previousDpi)
}
