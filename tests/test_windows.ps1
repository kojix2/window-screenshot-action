Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($file in Get-ChildItem "$root/scripts/*.ps1") {
    $parseErrors = $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
}
$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ('screenshot input tests ' + [guid]::NewGuid().ToString('N'))
[void][System.IO.Directory]::CreateDirectory($workspace)
Push-Location $workspace
try {
    [System.IO.File]::WriteAllText((Join-Path $workspace 'app.exe'), '')
    [System.IO.File]::WriteAllText((Join-Path $workspace 'second.EXE'), '')
    function Read-Inputs([hashtable]$Changes) {
        $env:APP_NAMES = 'app.exe'
        $env:OUTPUT_FILES = ''
        $env:OUTPUT_PATTERN = '{name}-{os}.png'
        $env:REQUESTED_OS = 'windows'
        $env:WINDOW_TIMEOUT = '15'
        $env:CAPTURE_DELAY = '1'
        foreach ($key in $Changes.Keys) { [Environment]::SetEnvironmentVariable($key, $Changes[$key]) }
        & {
            . "$root/scripts/inputs.ps1"
            [pscustomobject]@{ Apps = $apps; Outputs = $outputs; Timeout = $windowTimeout; Delay = $captureDelay }
        }
    }
    $value = Read-Inputs @{}
    if ($value.Apps.Count -ne 1 -or $value.Outputs[0] -ne 'app-windows.png') { throw 'Default input parsing failed' }
    $value = Read-Inputs @{ APP_NAMES = "app.exe`r`nsecond.EXE"; OUTPUT_FILES = "./one.png`nshots//two.png" }
    if ($value.Apps.Count -ne 2 -or $value.Outputs[0] -ne 'one.png' -or $value.Outputs[1] -ne 'shots/two.png') { throw 'Multiline input parsing failed' }
    $value = Read-Inputs @{ OUTPUT_FILES = 'x.png'; OUTPUT_PATTERN = '{ignored}'; CAPTURE_DELAY = '0'; WINDOW_TIMEOUT = '300' }
    if ($value.Outputs[0] -ne 'x.png' -or $value.Delay -ne 0 -or $value.Timeout -ne 300) { throw 'Explicit input parsing failed' }
    $value = Read-Inputs @{ APP_NAMES = 'app' }
    if ($value.Apps[0] -ne 'app.exe' -or $value.Outputs[0] -ne 'app-windows.png') { throw 'Optional .exe lookup failed' }
    $cases = @(
        @{ APP_NAMES = '' },
        @{ APP_NAMES = 'missing.exe' },
        @{ APP_NAMES = 'app.exe second.EXE'; OUTPUT_FILES = 'one.png' },
        @{ APP_NAMES = 'app.exe second.EXE'; OUTPUT_FILES = 'x.png ./X.png' },
        @{ OUTPUT_FILES = '../x.png' },
        @{ OUTPUT_FILES = 'C:/x.png' },
        @{ OUTPUT_FILES = 'x.jpg' },
        @{ OUTPUT_FILES = 'NUL.png' },
        @{ OUTPUT_FILES = 'x?.png' },
        @{ OUTPUT_PATTERN = '{unknown}.png' },
        @{ WINDOW_TIMEOUT = '0' },
        @{ WINDOW_TIMEOUT = '01' },
        @{ WINDOW_TIMEOUT = '301' },
        @{ WINDOW_TIMEOUT = '999999999999999999' },
        @{ CAPTURE_DELAY = '-1' },
        @{ CAPTURE_DELAY = '0.5' },
        @{ CAPTURE_DELAY = '61' }
    )
    foreach ($case in $cases) {
        $rejected = $false
        try { $null = Read-Inputs $case } catch { $rejected = $true }
        if (!$rejected) { throw "Expected rejection: $($case | ConvertTo-Json -Compress)" }
    }
    Write-Host "Passed 4 valid cases, $($cases.Count) invalid cases, and PowerShell syntax checks."
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $workspace -Recurse -Force
}
