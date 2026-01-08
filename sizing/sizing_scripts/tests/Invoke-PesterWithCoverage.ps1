$ErrorActionPreference = 'Stop'

if (-not (Test-Path './coverage')) {
    New-Item -ItemType Directory -Path './coverage' | Out-Null
}

$config = New-PesterConfiguration
$config.Run.Path = './tests'
$config.Output.Verbosity = 'Detailed'
$config.Run.PassThru = $true

$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.Path = './*.ps1'
$config.CodeCoverage.OutputPath = './coverage/coverage.xml'

$result = Invoke-Pester -Configuration $config

if ($result.FailedCount -gt 0) {
    exit 1
} else {
    exit 0
}

