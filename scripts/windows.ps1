param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

Write-Host "Starting Windows window screenshot process for $AppName"

# Add Win32 API definitions once when capturing several applications.
if (-not ('Win32' -as [type])) {
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class Win32 {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("dwmapi.dll")]
    public static extern int DwmGetWindowAttribute(IntPtr hwnd, int dwAttribute, out RECT pvAttribute, int cbAttribute);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    public const int SW_RESTORE = 9;
    public const int DWMWA_EXTENDED_FRAME_BOUNDS = 9;
}

[StructLayout(LayoutKind.Sequential)]
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}
"@
}

try {
    # Launch the application
    $process = Start-Process -FilePath ".\$AppName" -PassThru
    Write-Host "Application launched with PID: $($process.Id)"

    # Wait for application to fully load
    Start-Sleep -Seconds 2

    # Find the main window for the process
    $mainWindow = $null
    $guiWindowFound = $false
    $bitmap = $null
    $graphics = $null
    $processId = $process.Id

    # Enumerate windows to find the one belonging to our process
    $callback = {
        param($hWnd, $lParam)

        [uint32]$windowProcessId = 0
        [Win32]::GetWindowThreadProcessId($hWnd, [ref]$windowProcessId)

        if ($windowProcessId -eq $processId -and [Win32]::IsWindowVisible($hWnd)) {
            $windowTitle = New-Object System.Text.StringBuilder 256
            [Win32]::GetWindowText($hWnd, $windowTitle, 256)

            if ($windowTitle.Length -gt 0) {
                $titleString = $windowTitle.ToString()

                # Prioritize GUI application windows over console windows
                # Look for windows that don't end with .exe (console windows typically do)
                if ($titleString -notlike "*.exe") {
                    Write-Host "Selecting GUI window: $titleString"
                    $script:mainWindow = $hWnd
                    $script:guiWindowFound = $true
                    return $false  # Stop enumeration
                }
            }
        }
        return $true  # Continue enumeration
    }

    for ($attempt = 0; $attempt -lt 20 -and !$guiWindowFound; $attempt++) {
        [void][Win32]::EnumWindows($callback, [IntPtr]::Zero)
        if (!$guiWindowFound) {
            Start-Sleep -Milliseconds 500
        }
    }

    if ($mainWindow -eq $null) {
        throw "No application window found for $AppName"
    }
    else {
        Write-Host "Capturing window with handle: $mainWindow"

        # Bring window to foreground
        [Win32]::ShowWindow($mainWindow, [Win32]::SW_RESTORE)
        [Win32]::SetForegroundWindow($mainWindow)
        Start-Sleep -Seconds 1

        # Get the visible DWM frame bounds. GetWindowRect includes the invisible
        # resize border on modern Windows, which leaves wallpaper around edges.
        $rect = New-Object RECT
        $dwmResult = [Win32]::DwmGetWindowAttribute(
            $mainWindow,
            [Win32]::DWMWA_EXTENDED_FRAME_BOUNDS,
            [ref]$rect,
            [System.Runtime.InteropServices.Marshal]::SizeOf([type][RECT])
        )
        if ($dwmResult -eq 0) {
            Write-Host "Using DWM extended frame bounds"
        }
        elseif ([Win32]::GetWindowRect($mainWindow, [ref]$rect)) {
            Write-Host "DWM frame bounds unavailable (HRESULT: $dwmResult); using GetWindowRect"
        }
        else {
            throw "Could not get window rectangle for $AppName"
        }

        $width = $rect.Right - $rect.Left
        $height = $rect.Bottom - $rect.Top
        if ($width -le 0 -or $height -le 0) {
            throw "Invalid window bounds: Left=$($rect.Left), Top=$($rect.Top), Right=$($rect.Right), Bottom=$($rect.Bottom)"
        }

        Write-Host "Window bounds: Left=$($rect.Left), Top=$($rect.Top), Width=$width, Height=$height"
        Add-Type -AssemblyName System.Drawing
        $bitmap = New-Object System.Drawing.Bitmap $width, $height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))
    }

    # Save as PNG
    $outputDirectory = Split-Path -Parent $OutputFile
    if ($outputDirectory) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $bitmap.Save($OutputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Screenshot saved to: $OutputFile"

    # Cleanup graphics objects
    $graphics.Dispose()
    $bitmap.Dispose()

    # Stop the application
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    Write-Host "Application process terminated"

    # Verify screenshot was created
    if (Test-Path $OutputFile) {
        Write-Host "Screenshot created successfully"
        Get-Item $OutputFile | Format-List Name, Length, LastWriteTime
    } else {
        Write-Error "Failed to create screenshot"
        exit 1
    }

    Write-Host "Windows window screenshot process completed successfully"
}
catch {
    Write-Error "Error during screenshot process: $($_.Exception.Message)"

    # Cleanup: try to stop the process if it's still running
    if ($process -and !$process.HasExited) {
        try {
            Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up application process"
        }
        catch {
            Write-Warning "Could not clean up application process: $($_.Exception.Message)"
        }
    }

    exit 1
}
