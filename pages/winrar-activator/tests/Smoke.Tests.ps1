[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryPath = Split-Path $PSScriptRoot -Parent
$temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryPath = Join-Path $temporaryParent ('WRA Smoke ' + [guid]::NewGuid().ToString('N'))
$organization = [char]::ConvertFromUtf32(0x1F12F) + ' Ashesh Development'
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$module = Import-Module (Join-Path $repositoryPath 'src\Registration.psm1') -Force -DisableNameChecking -PassThru

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Failure {
    param([scriptblock]$Action, [string]$Message)
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert-Condition $failed $Message
}

function Get-KeyLines {
    param([byte[]]$Data)
    Assert-Condition (-not ($Data[0] -eq 0xEF -and $Data[1] -eq 0xBB -and $Data[2] -eq 0xBF)) 'Key contains a UTF-8 BOM.'
    $text = $utf8.GetString($Data)
    Assert-Condition (-not ($text -match '(?<!\r)\n')) 'Key does not use CRLF line endings.'
    $lines = $text.TrimEnd([char[]]"`r`n") -split '\r?\n'
    Assert-Condition ($lines.Count -eq 11 -and $lines[0] -eq 'RAR registration data') 'Invalid key structure.'
    Assert-Condition ($lines[2] -ceq ('utf8:' + $organization)) 'Organization is not the exact fixed UTF-8 value.'
    Assert-Condition ($lines[3] -cmatch '^UID=[0-9a-f]{20}$') 'Invalid UID.'
    foreach ($line in $lines[4..10]) {
        Assert-Condition ($line -cmatch '^[0-9a-f]{54}$') 'Invalid key payload.'
    }
    return $lines
}

function Invoke-TestProcess {
    param([string]$FilePath, [string[]]$ProcessArguments, [string]$RawArguments)
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    if ($PSBoundParameters.ContainsKey('RawArguments')) {
        $startInfo.Arguments = $RawArguments
    } else {
        $startInfo.Arguments = & $module {
            param($Values)
            ($Values | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
        } -Values $ProcessArguments
    }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = $utf8
    $startInfo.StandardErrorEncoding = $utf8
    $startInfo.WorkingDirectory = $temporaryPath
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $outputTask.GetAwaiter().GetResult()
            ErrorText = $errorTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

foreach ($relativePath in @('WRA.ps1', 'src\Registration.psm1', 'tests\Smoke.Tests.ps1')) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryPath $relativePath), [ref]$tokens, [ref]$parseErrors) | Out-Null
    Assert-Condition ($parseErrors.Count -eq 0) "PowerShell parser errors: $relativePath"
}

New-Item -ItemType Directory -Path $temporaryPath | Out-Null
try {
    foreach ($directory in @('src', 'tools\winrar-keygen', 'Mock WinRAR')) {
        New-Item -ItemType Directory -Path (Join-Path $temporaryPath $directory) | Out-Null
    }
    foreach ($relativePath in @('WRA.cmd', 'WRA.ps1', 'src\Registration.psm1', 'tools\winrar-keygen\winrar-keygen-x86.exe')) {
        Copy-Item -LiteralPath (Join-Path $repositoryPath $relativePath) -Destination (Join-Path $temporaryPath $relativePath)
    }

    Assert-Condition ((Get-RegistrationOrganization) -ceq $organization) 'Incorrect fixed organization.'
    Assert-Condition ((Resolve-RegistrationName) -eq 'Erich Alfred Bossert') 'Incorrect default registration name.'
    Assert-Condition ((Resolve-RegistrationName -Name '  New Person  ') -eq 'New Person') 'Name trimming failed.'
    $promptedName = & $module {
        function script:Read-Host { param($Prompt) return 'Selected At Activation' }
        try { Resolve-RegistrationName -Prompt } finally { Remove-Item Function:\Read-Host }
    }
    Assert-Condition ($promptedName -eq 'Selected At Activation') 'Interactive name selection failed.'
    $defaultPromptedName = & $module {
        function script:Read-Host { param($Prompt) return '' }
        try { Resolve-RegistrationName -Prompt } finally { Remove-Item Function:\Read-Host }
    }
    Assert-Condition ($defaultPromptedName -eq 'Erich Alfred Bossert') 'Enter should retain the default name.'
    Assert-Failure { Resolve-RegistrationName -Name '   ' } 'Blank names should fail.'
    Assert-Failure { Resolve-RegistrationName -Name "First`nSecond" } 'Multiline names should fail.'
    Assert-Failure { Resolve-RegistrationName -Name '--activate' } 'Names that resemble generator switches should fail.'

    $defaultData = New-RegistrationData -Name 'Erich Alfred Bossert'
    $defaultLines = Get-KeyLines $defaultData
    $sampleLines = Get-KeyLines ([System.IO.File]::ReadAllBytes((Join-Path $repositoryPath 'rarreg.key')))
    Assert-Condition ($defaultLines[1] -eq 'Erich Alfred Bossert' -and $sampleLines[1] -eq $defaultLines[1]) 'Default sample name is incorrect.'
    Assert-Condition ($sampleLines[3] -eq $defaultLines[3]) 'Default sample UID differs from generated data.'

    $customName = 'Ada & Bob! 100% "QA" \Path\'
    $customData = New-RegistrationData -Name $customName
    $customLines = Get-KeyLines $customData
    Assert-Condition ($customLines[1] -ceq $customName) 'Special characters in names were altered.'
    Assert-Condition ($customLines[3] -ne $defaultLines[3]) 'Changing the name did not regenerate its UID.'
    Assert-Condition (($customLines[4..10] -join '') -ne ($defaultLines[4..10] -join '')) 'Changing the name did not regenerate the payload.'
    $unicodeName = 'Zo' + [char]0x00EB + ' ' + [char]0x674E
    $unicodeLines = Get-KeyLines (New-RegistrationData -Name $unicodeName)
    Assert-Condition ($unicodeLines[1] -ceq ('utf8:' + $unicodeName)) 'Unicode name was not preserved.'

    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $copiedLauncher = Join-Path $temporaryPath 'WRA.ps1'
    $preview = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '-Preview', '-Name', $unicodeName)
    Assert-Condition ($preview.ExitCode -eq 0) ('Preview failed: ' + $preview.ErrorText)
    Assert-Condition ($preview.Output.Contains('Registration name: ' + $unicodeName)) 'Preview uses the wrong name.'
    Assert-Condition ($preview.Output.Contains($organization)) 'Preview lost the fixed organization symbol.'
    $copiedBatch = Join-Path $temporaryPath 'WRA.cmd'
    $batchPreview = Invoke-TestProcess -FilePath $env:ComSpec -RawArguments ('/d /s /c ""' + $copiedBatch + '" --preview --name "Batch & Person!""')
    Assert-Condition ($batchPreview.ExitCode -eq 0) ('Batch preview failed: ' + $batchPreview.ErrorText)
    Assert-Condition ($batchPreview.Output.Contains('Registration name: Batch & Person!')) 'Batch launcher lost the selected name.'
    $helpText = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '-Help')
    Assert-Condition ($helpText.ExitCode -eq 0 -and $helpText.Output.Contains('--name')) 'Help does not document name selection.'
    Assert-Condition (@(Get-ChildItem -LiteralPath $temporaryPath -File).Count -eq 2) 'Preview or help unexpectedly created files.'

    $exportPath = Join-Path $temporaryPath 'custom registration.key'
    $export = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '-Name', $customName, '-ExportPath', $exportPath)
    Assert-Condition ($export.ExitCode -eq 0) ('Custom export failed: ' + $export.ErrorText)
    $exportLines = Get-KeyLines ([System.IO.File]::ReadAllBytes($exportPath))
    Assert-Condition ($exportLines[1] -ceq $customName) 'Export ignored the selected name.'
    $exportHash = (Get-FileHash -LiteralPath $exportPath).Hash
    $repeatedExport = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '--export', $exportPath)
    Assert-Condition ($repeatedExport.ExitCode -ne 0) 'Export should refuse an existing file.'
    Assert-Condition ((Get-FileHash -LiteralPath $exportPath).Hash -eq $exportHash) 'Rejected export changed the file.'
    foreach ($invalidArguments in @(
        @('--export'), @('--name'), @('--unknown'), @('--preview', '--export', $exportPath),
        @('--preview', '--organization', 'Other Company'), @('--preview', '--name', '   '),
        @('--preview', '--name', "First`nSecond"), @('--export', (Join-Path $temporaryPath 'missing folder\rarreg.key'))
    )) {
        $invalidResult = Invoke-TestProcess $powerShellPath (@('-NoProfile', '-File', $copiedLauncher) + $invalidArguments)
        Assert-Condition ($invalidResult.ExitCode -ne 0) ('Invalid options should fail: ' + ($invalidArguments -join ' '))
    }

    $mockInstallation = Join-Path $temporaryPath 'Mock WinRAR'
    $mockKey = Join-Path $mockInstallation 'rarreg.key'
    $result = Install-RegistrationData -Data $customData -Directory $mockInstallation
    Assert-Condition (-not $result.BackupPath) 'First installation should not create a backup.'
    Assert-Condition ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($mockKey)) -eq [Convert]::ToBase64String($customData)) 'Installation changed the generated bytes.'
    $result = Install-RegistrationData -Data $defaultData -Directory $mockInstallation
    Assert-Condition ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($result.BackupPath)) -eq [Convert]::ToBase64String($customData)) 'Backup did not preserve the previous name and key.'
    Assert-Condition ((Get-KeyLines ([System.IO.File]::ReadAllBytes($mockKey)))[1] -eq 'Erich Alfred Bossert') 'Replacement did not update the name.'
    $installedHash = (Get-FileHash -LiteralPath $mockKey).Hash
    (Get-Item -LiteralPath $mockKey).IsReadOnly = $true
    try {
        Assert-Failure { Install-RegistrationData -Data $customData -Directory $mockInstallation } 'Read-only replacement should fail.'
    } finally {
        (Get-Item -LiteralPath $mockKey).IsReadOnly = $false
    }
    Assert-Condition ((Get-FileHash -LiteralPath $mockKey).Hash -eq $installedHash) 'Failed replacement changed the existing key.'
    Assert-Condition (@(Get-ChildItem -LiteralPath $mockInstallation -Filter '*.tmp').Count -eq 0) 'Failed installation left temporary files.'

    $copiedGenerator = Join-Path $temporaryPath 'tools\winrar-keygen\winrar-keygen-x86.exe'
    $stream = [System.IO.File]::Open($copiedGenerator, [System.IO.FileMode]::Append)
    try { $stream.WriteByte(0) } finally { $stream.Dispose() }
    $tamperedResult = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '-Preview')
    Assert-Condition ($tamperedResult.ExitCode -ne 0 -and $tamperedResult.ErrorText.Contains('checksum mismatch')) 'Tampered generator was not rejected.'
    [System.IO.File]::Delete($copiedGenerator)
    $missingResult = Invoke-TestProcess $powerShellPath @('-NoProfile', '-File', $copiedLauncher, '-Preview')
    Assert-Condition ($missingResult.ExitCode -ne 0 -and $missingResult.ErrorText.Contains('missing')) 'Missing generator was not reported.'

    Write-Output 'PASS: name prompt/options, fixed Unicode organization, UTF-8 keys, safe argument handling, preview/export, backups, failures, and generator integrity.'
} finally {
    # Verify the resolved absolute target is the GUID-named directory created above.
    if (Test-Path -LiteralPath $temporaryPath) {
        $resolvedTemporaryPath = (Resolve-Path -LiteralPath $temporaryPath).Path
        $resolvedParent = [System.IO.Path]::GetDirectoryName($resolvedTemporaryPath).TrimEnd('\')
        if ($resolvedParent -ne $temporaryParent.TrimEnd('\') -or
            [System.IO.Path]::GetFileName($resolvedTemporaryPath) -notmatch '^WRA Smoke [0-9a-f]{32}$') {
            throw "Refusing cleanup outside the isolated test directory: $resolvedTemporaryPath"
        }
        Remove-Item -LiteralPath $resolvedTemporaryPath -Recurse -Force
    }
}
