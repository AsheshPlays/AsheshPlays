# GPL-3.0-only. See LICENSE and NOTICE for attribution and modification details.
# Modified 2026-11-18: runtime names, fixed organization, UTF-8 generation.
Set-StrictMode -Version Latest

function Get-RegistrationOrganization {
    # U+1F12F is represented as a surrogate pair in Windows PowerShell 5.1.
    return [char]::ConvertFromUtf32(0x1F12F) + ' Ashesh Development'
}

function Resolve-RegistrationName {
    param([AllowEmptyString()][string]$Name = 'Erich Alfred Bossert', [switch]$Prompt)
    if ($Prompt) {
        $enteredName = Read-Host "Registration name [$Name]"
        if (-not [string]::IsNullOrWhiteSpace($enteredName)) { $Name = $enteredName }
    }
    if ([string]::IsNullOrWhiteSpace($Name)) { throw 'Registration name cannot be blank.' }
    if ($Name -match '[\x00-\x1F\x7F]') { throw 'Registration name must be a single line without control characters.' }
    $Name = $Name.Trim()
    if ($Name.StartsWith('-')) { throw 'Registration name cannot start with a hyphen.' }
    # Reject malformed surrogate pairs before passing the name to a native tool.
    $null = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($Name)
    return $Name
}

function ConvertTo-WindowsArgument {
    param([AllowEmptyString()][string]$Value)
    # Quote for the Windows C runtime, including embedded quotes and trailing slashes.
    $escaped = [regex]::Replace($Value, '(\\*)"', [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return ('\' * (2 * $match.Groups[1].Length + 1)) + '"'
    })
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function ConvertTo-RegistrationField {
    param([string]$Value)
    if ($Value -match '[^\x00-\x7F]' -and -not $Value.StartsWith('utf8:', [StringComparison]::Ordinal)) {
        return 'utf8:' + $Value
    }
    return $Value
}

function New-RegistrationData {
    param([Parameter(Mandatory = $true)][string]$Name)
    $Name = Resolve-RegistrationName -Name $Name
    $organization = Get-RegistrationOrganization
    $generatorPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\winrar-keygen\winrar-keygen-x86.exe'
    if (-not [System.IO.File]::Exists($generatorPath)) { throw "Bundled generator is missing: $generatorPath" }
    $expectedHash = '9b9be01389980dc3a22c995773671364f8823cc5ffab96f9b701a5e6220bbbb2'
    if ((Get-FileHash -LiteralPath $generatorPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
        throw 'Bundled generator checksum mismatch. Restore the pinned v4.3.0 executable.'
    }

    $arguments = @($Name, $organization, '--text', '--encoding', 'utf8')
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $generatorPath
    $startInfo.Arguments = ($arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false, $true)
    $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false, $true)
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        $null = $process.Start()
        $outputTask = $process.StandardOutput.ReadToEndAsync()
        $errorTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $output = $outputTask.GetAwaiter().GetResult()
        $errorText = $errorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) { throw "Registration generation failed: $errorText" }
    } finally {
        $process.Dispose()
    }

    $lines = $output.TrimStart([char]0xFEFF).TrimEnd([char[]]"`r`n") -split '\r?\n'
    if ($lines.Count -ne 11 -or $lines[0] -ne 'RAR registration data' -or
        $lines[1] -cne (ConvertTo-RegistrationField $Name) -or
        $lines[2] -cne (ConvertTo-RegistrationField $organization) -or
        $lines[3] -cnotmatch '^UID=[0-9a-f]{20}$') {
        throw 'Generator output did not match the selected name and fixed organization.'
    }
    foreach ($line in $lines[4..10]) {
        if ($line -cnotmatch '^[0-9a-f]{54}$') { throw 'Generator returned malformed registration data.' }
    }
    return ,([System.Text.UTF8Encoding]::new($false).GetBytes(($lines -join "`r`n") + "`r`n"))
}

function Export-RegistrationData {
    param([Parameter(Mandatory = $true)][byte[]]$Data, [Parameter(Mandatory = $true)][string]$Path)
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $completed = $false
    try {
        $stream.Write($Data, 0, $Data.Length)
        $stream.Flush()
        $completed = $true
    } finally {
        $stream.Dispose()
        if (-not $completed) { [System.IO.File]::Delete($Path) }
    }
}

function Install-RegistrationData {
    param([Parameter(Mandatory = $true)][byte[]]$Data, [Parameter(Mandatory = $true)][string]$Directory)
    if (-not [System.IO.Directory]::Exists($Directory)) { throw "Installation directory does not exist: $Directory" }
    $destination = Join-Path $Directory 'rarreg.key'
    $stagedPath = Join-Path $Directory ('rarreg.key.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backupPath = $null
    try {
        Export-RegistrationData -Data $Data -Path $stagedPath
        if ([System.IO.File]::Exists($destination)) {
            $backupPath = $destination + '.' + [guid]::NewGuid().ToString('N') + '.bak'
            [System.IO.File]::Replace($stagedPath, $destination, $backupPath)
        } else {
            [System.IO.File]::Move($stagedPath, $destination)
        }
        return [pscustomobject]@{ Destination = $destination; BackupPath = $backupPath }
    } finally {
        if ([System.IO.File]::Exists($stagedPath)) { [System.IO.File]::Delete($stagedPath) }
    }
}

function Find-WinRARDirectory {
    $candidates = @(
        if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'WinRAR' }
        if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'WinRAR' }
        if ($env:ProgramW6432) { Join-Path $env:ProgramW6432 'WinRAR' }
        if ($env:USERPROFILE) { Join-Path $env:USERPROFILE 'scoop\apps\winrar\current' }
    )
    $found = $null
    foreach ($candidate in $candidates) {
        if ([System.IO.File]::Exists((Join-Path $candidate 'WinRAR.exe'))) { $found = $candidate }
    }
    if (-not $found) { throw 'WinRAR was not found in Program Files or the user Scoop folder. Use --export for a custom installation.' }
    return $found
}

function Test-IsAdministrator {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-ElevatedRegistration {
    param([Parameter(Mandatory = $true)][string]$ScriptPath, [Parameter(Mandatory = $true)][string]$Name)
    $powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $arguments = @('-NoProfile', '-File', $ScriptPath, '-Name', $Name, '-Elevated')
    $commandLine = ($arguments | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join ' '
    $process = Start-Process -FilePath $powerShellPath -ArgumentList $commandLine -Verb RunAs -Wait -PassThru -ErrorAction Stop
    try { return $process.ExitCode } finally { $process.Dispose() }
}

Export-ModuleMember -Function Get-RegistrationOrganization, Resolve-RegistrationName, New-RegistrationData, Export-RegistrationData, Install-RegistrationData, Find-WinRARDirectory, Test-IsAdministrator, Start-ElevatedRegistration
