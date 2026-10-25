# Sourced by run-windows.ps1. Keep the input contract aligned with inputs.sh.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-IntegerInput([string]$Value, [int]$Minimum, [int]$Maximum, [string]$Label) {
    if ($Value -cnotmatch '^(0|[1-9][0-9]{0,2})$' -or [int]$Value -lt $Minimum -or [int]$Value -gt $Maximum) {
        throw "$Label must be an integer from $Minimum to $Maximum"
    }
    return [int]$Value
}

function Get-NormalizedPath([string]$Path) {
    $Path = $Path.Replace('\', '/')
    if (-not $Path -or $Path.StartsWith('/') -or $Path.Contains(':') -or $Path -match '[\x00-\x1f\x7f]' -or $Path -match '/$|(^|/)\.\.?$|(^|/)\.\.(/|$)') {
        throw "Use a nonempty workspace-relative file path without parent traversal: $Path"
    }
    $parts = @($Path.Split('/') | Where-Object { $_ -and $_ -ne '.' })
    foreach ($part in $parts) {
        if ($part -match '[<>"|?*]' -or $part -match '[ .]$' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)') {
            throw "Invalid Windows path component: $part"
        }
    }
    return ($parts -join '/')
}

$timeoutText = if ($env:WINDOW_TIMEOUT) { $env:WINDOW_TIMEOUT } else { '15' }
$delayText = if ($env:CAPTURE_DELAY) { $env:CAPTURE_DELAY } else { '1' }
$windowTimeout = Get-IntegerInput $timeoutText 1 300 'window-timeout'
$captureDelay = Get-IntegerInput $delayText 0 60 'capture-delay'
$apps = @($env:APP_NAMES -split '[ \t\r\n]+' | Where-Object { $_ })
$outputs = @($env:OUTPUT_FILES -split '[ \t\r\n]+' | Where-Object { $_ })
if ($apps.Count -eq 0) { throw 'app-names must be nonempty' }
$apps = @($apps | ForEach-Object { Get-NormalizedPath $_ })
for ($i = 0; $i -lt $apps.Count; $i++) {
    $app = $apps[$i]
    # Preserve Start-Process's convenient .exe lookup when the suffix is omitted.
    if (-not (Test-Path -LiteralPath "./$app" -PathType Leaf)) {
        if (Test-Path -LiteralPath "./$app.exe" -PathType Leaf) { $apps[$i] = "$app.exe" }
        else { throw "Executable not found: $app" }
    }
}
if ($outputs.Count -eq 0) {
    $outputs = @($apps | ForEach-Object {
        $name = [System.IO.Path]::GetFileName($_) -replace '(?i)\.exe$', ''
        $env:OUTPUT_PATTERN.Replace('{name}', $name).Replace('{os}', $env:REQUESTED_OS)
    })
}
if ($apps.Count -ne $outputs.Count) { throw 'app-names and output-files must have the same length' }
$outputs = @($outputs | ForEach-Object { Get-NormalizedPath $_ })
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($output in $outputs) {
    if ($output -notmatch '\.png$') { throw "Output must have a .png extension: $output" }
    if ($output -match '[{}]') { throw "Unknown placeholder in output path: $output" }
    if (Test-Path -LiteralPath "./$output" -PathType Container) { throw "Output is a directory: $output" }
    if ($apps -contains $output) { throw "Output would overwrite an executable: $output" }
    if (-not $seen.Add($output)) { throw "Duplicate output path: $output" }
}
