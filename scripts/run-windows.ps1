Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/inputs.ps1"
for ($i = 0; $i -lt $apps.Count; $i++) {
    & "$PSScriptRoot/windows.ps1" -AppName $apps[$i] -OutputFile $outputs[$i] -WindowTimeout $windowTimeout -CaptureDelay $captureDelay
}
if ($env:GITHUB_OUTPUT) {
    $text = "files<<WINDOW_SCREENSHOT_FILES`n" + ($outputs -join "`n") + "`nWINDOW_SCREENSHOT_FILES`ncount=$($outputs.Count)`n"
    [System.IO.File]::AppendAllText($env:GITHUB_OUTPUT, $text, [System.Text.UTF8Encoding]::new($false))
}
