[CmdletBinding()]
param([string]$PackageArchive)

$ErrorActionPreference = 'Stop'
$repositoryPath = Split-Path $PSScriptRoot -Parent
$bootstrapSource = [System.IO.File]::ReadAllText((Join-Path $repositoryPath 'Install.ps1'))
$packageName = [regex]::Match($bootstrapSource, '\$packageName = ''([^'']+)''').Groups[1].Value
if (-not $packageName) { throw 'Could not read the package root folder.' }
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryPath = Join-Path $temporaryParent ('WRA Bootstrap Tests-' + [guid]::NewGuid().ToString('N'))
$originalLocation = Get-Location
$organization = [char]::ConvertFromUtf32(0x1F12F) + ' Ashesh Development'
$script:MockMode = 'Success'
$script:ObservedDownloadPath = $null
$script:ExpansionObserved = $false

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-PackageCleanup {
    Assert-Condition (-not [string]::IsNullOrEmpty($script:ObservedDownloadPath)) 'No package download was observed.'
    $packageDirectory = Split-Path $script:ObservedDownloadPath -Parent
    Assert-Condition (-not (Test-Path -LiteralPath $packageDirectory)) 'Temporary package files were not removed.'
}

function Assert-BootstrapFailure {
    param([scriptblock]$Action, [string]$ExpectedMessage)
    $failureMessage = $null
    $originalProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    $originalErrorWriter = [Console]::Error
    $capturedError = [System.IO.StringWriter]::new()
    try {
        [Console]::SetError($capturedError)
        try { & $Action | Out-Null } catch { $failureMessage = $_.Exception.Message }
    } finally {
        [Console]::SetError($originalErrorWriter)
        $capturedError.Dispose()
    }
    Assert-Condition ($failureMessage -like "*$ExpectedMessage*") "Expected bootstrap failure containing '$ExpectedMessage', got '$failureMessage'."
    Assert-Condition ([System.Net.ServicePointManager]::SecurityProtocol -eq $originalProtocol) 'Failed bootstrap did not restore the TLS setting.'
    Assert-PackageCleanup
}

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseInput($bootstrapSource, [ref]$tokens, [ref]$parseErrors) | Out-Null
Assert-Condition ($parseErrors.Count -eq 0) 'Bootstrap has PowerShell parser errors.'

New-Item -ItemType Directory -Path $temporaryPath | Out-Null
try {
    if ($PackageArchive) {
        $script:FixturePath = (Resolve-Path -LiteralPath $PackageArchive).ProviderPath
    } else {
        $script:FixturePath = Join-Path $temporaryPath 'fixture.zip'
        $fixtureUri = [regex]::Match($bootstrapSource, '\$packageUri = ''([^'']+)''').Groups[1].Value
        Microsoft.PowerShell.Utility\Invoke-WebRequest -Uri $fixtureUri -OutFile $script:FixturePath -UseBasicParsing -ErrorAction Stop
    }

    # Substitute only network I/O; extraction, integrity checks, key generation,
    # argument forwarding, and cleanup execute the real bootstrap and runtime.
    # Load the archive module before defining its wrapper so autoloading cannot
    # replace the wrapper after the first call.
    Import-Module Microsoft.PowerShell.Archive -ErrorAction Stop
    function Invoke-WebRequest {
        [CmdletBinding()]
        param([uri]$Uri, [switch]$UseBasicParsing, [string]$OutFile)
        $script:ObservedDownloadPath = $OutFile
        $script:ExpansionObserved = $false
        if ($script:MockMode -eq 'NetworkFailure') { throw 'Simulated download failure.' }
        Copy-Item -LiteralPath $script:FixturePath -Destination $OutFile
        if ($script:MockMode -eq 'CorruptArchive') {
            $stream = [System.IO.File]::Open($OutFile, [System.IO.FileMode]::Append)
            try { $stream.WriteByte(0) } finally { $stream.Dispose() }
        }
    }

    function Expand-Archive {
        [CmdletBinding()]
        param([string]$LiteralPath, [string]$DestinationPath)
        $script:ExpansionObserved = $true
        Microsoft.PowerShell.Archive\Expand-Archive -LiteralPath $LiteralPath -DestinationPath $DestinationPath -ErrorAction Stop
        $runtimeRoot = Join-Path $DestinationPath $packageName
        if ($script:MockMode -eq 'MissingModule') {
            Remove-Item -LiteralPath (Join-Path $runtimeRoot 'src\Registration.psm1')
        } elseif ($script:MockMode -eq 'CorruptGenerator') {
            $generatorPath = Join-Path $runtimeRoot 'tools\winrar-keygen\winrar-keygen-x86.exe'
            $stream = [System.IO.File]::Open($generatorPath, [System.IO.FileMode]::Append)
            try { $stream.WriteByte(0) } finally { $stream.Dispose() }
        }
    }

    # A dynamically-created script block has no local script directory. Run it
    # from a directory containing no runtime files, as with irm ... | iex.
    Set-Location -LiteralPath $temporaryPath
    $selectedName = 'Zo' + [char]0x00EB + ' & "Online"!'
    $oldProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    $preview = @(& ([scriptblock]::Create($bootstrapSource)) -Preview -Name $selectedName)
    Assert-Condition ($preview -contains "Registration name: $selectedName") 'Streamed preview lost the selected name.'
    Assert-Condition ($preview -contains $organization) 'Streamed preview lost the fixed organization.'
    Assert-Condition ([System.Net.ServicePointManager]::SecurityProtocol -eq $oldProtocol) 'Bootstrap did not restore the TLS setting.'
    Assert-PackageCleanup

    $exportPath = Join-Path $temporaryPath 'online exported.key'
    & ([scriptblock]::Create($bootstrapSource)) -ExportPath $exportPath -Name $selectedName | Out-Null
    $exportText = [System.IO.File]::ReadAllText($exportPath, [System.Text.Encoding]::UTF8)
    Assert-Condition ($exportText.Contains("`r`nutf8:$selectedName`r`nutf8:$organization`r`n")) 'Streamed export has the wrong registration fields.'
    Assert-PackageCleanup

    # Exercise the exact no-argument IEX entry point, but stop at the name prompt
    # before installation discovery, UAC, or writing registration to WinRAR.
    $previousReadHost = Get-Item Function:\Read-Host -ErrorAction SilentlyContinue
    $global:WraBootstrapPromptObserved = $false
    function global:Read-Host {
        param([string]$Prompt)
        $global:WraBootstrapPromptObserved = $true
        throw 'TEST_STOP_AT_REGISTRATION_PROMPT'
    }
    try {
        Assert-BootstrapFailure { $bootstrapSource | Invoke-Expression } 'exit code 1'
        Assert-Condition $global:WraBootstrapPromptObserved 'The default one-liner did not reach name selection.'
    } finally {
        Remove-Item Function:\Read-Host
        if ($previousReadHost) { Set-Item Function:\global:Read-Host -Value $previousReadHost.ScriptBlock }
        Remove-Variable -Name WraBootstrapPromptObserved -Scope Global
    }

    $script:MockMode = 'NetworkFailure'
    Assert-BootstrapFailure { & ([scriptblock]::Create($bootstrapSource)) -Preview } 'Simulated download failure'
    $script:MockMode = 'CorruptArchive'
    Assert-BootstrapFailure { & ([scriptblock]::Create($bootstrapSource)) -Preview } 'Downloaded package checksum mismatch'
    Assert-Condition (-not $script:ExpansionObserved) 'Corrupted archive was extracted before validation.'
    $script:MockMode = 'MissingModule'
    Assert-BootstrapFailure { & ([scriptblock]::Create($bootstrapSource)) -Preview } 'Required package file is missing'
    $script:MockMode = 'CorruptGenerator'
    Assert-BootstrapFailure { & ([scriptblock]::Create($bootstrapSource)) -Preview } 'Bundled generator checksum mismatch'
    $script:MockMode = 'Success'
    Assert-BootstrapFailure { & ([scriptblock]::Create($bootstrapSource)) -UnknownOption } 'exit code 1'

    Write-Output 'PASS: streamed invocation, name/Unicode forwarding, export, prompt entry, download/integrity failures, and temporary-package cleanup.'
} finally {
    Set-Location -LiteralPath $originalLocation.Path
    if (Test-Path -LiteralPath $temporaryPath) {
        $resolvedTemporaryPath = (Resolve-Path -LiteralPath $temporaryPath).ProviderPath
        $resolvedParent = [System.IO.Path]::GetDirectoryName($resolvedTemporaryPath).TrimEnd('\')
        if ($resolvedParent -ne $temporaryParent.TrimEnd('\') -or
            [System.IO.Path]::GetFileName($resolvedTemporaryPath) -notmatch '^WRA Bootstrap Tests-[0-9a-f]{32}$') {
            throw "Refusing cleanup outside the isolated test directory: $resolvedTemporaryPath"
        }
        Remove-Item -LiteralPath $resolvedTemporaryPath -Recurse -Force
    }
}
