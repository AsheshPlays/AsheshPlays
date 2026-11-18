# GPL-3.0-only. Inspired by NaeemBolchhi's original WinRAR Activator.
# Modified 2026-11-18 for Erich Alfred Bossert / Ashesh Development.
# Streamable entry point: this file does not depend on PSScriptRoot or local files.
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

& {
    param([string[]]$LauncherArguments)
    $ErrorActionPreference = 'Stop'

    # build-package.ps1 refreshes the package and its pinned digest together.
    $packageName = 'WinRAR-Activator'
    $packageSha256 = 'c4f68ba0d172eaa90c7bf0b6c855abd12799f71cf705754ffb046de35203a2ac'
    $generatorSha256 = '9b9be01389980dc3a22c995773671364f8823cc5ffab96f9b701a5e6220bbbb2'
    $packageUri = 'https://asheshplays.github.io/AsheshPlays/winrar-activator/downloads/winrar-activator.zip'
    $temporaryParent = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $workingPath = Join-Path $temporaryParent ('WinRAR-Activator-' + [guid]::NewGuid().ToString('N'))
    $ownsWorkingDirectory = $false
    $originalProtocol = [System.Net.ServicePointManager]::SecurityProtocol

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $null = New-Item -ItemType Directory -Path $workingPath
        $ownsWorkingDirectory = $true
        $archivePath = Join-Path $workingPath 'package.zip'
        Write-Host 'Downloading the WinRAR Activator package...'
        Invoke-WebRequest -Uri $packageUri -UseBasicParsing -OutFile $archivePath -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $packageSha256) {
            throw 'Downloaded package checksum mismatch. The package will not be run.'
        }

        $extractionPath = Join-Path $workingPath 'package'
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractionPath -ErrorAction Stop
        $packageRoot = Join-Path $extractionPath $packageName
        foreach ($requiredFile in @('WRA.ps1', 'src\Registration.psm1', 'tools\winrar-keygen\winrar-keygen-x86.exe', 'LICENSE', 'NOTICE', 'tools\winrar-keygen\LICENSE')) {
            if (-not (Test-Path -LiteralPath (Join-Path $packageRoot $requiredFile) -PathType Leaf)) {
                throw "Required package file is missing: $requiredFile"
            }
        }
        $generatorPath = Join-Path $packageRoot 'tools\winrar-keygen\winrar-keygen-x86.exe'
        if ((Get-FileHash -LiteralPath $generatorPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $generatorSha256) {
            throw 'Bundled generator checksum mismatch. The package will not be run.'
        }

        $launcherPath = Join-Path $packageRoot 'WRA.ps1'
        & $launcherPath @LauncherArguments
        if ($LASTEXITCODE -ne 0) { throw "WinRAR Activator ended with exit code $LASTEXITCODE." }
    } finally {
        [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol
        if ($ownsWorkingDirectory -and (Test-Path -LiteralPath $workingPath)) {
            # Resolve and verify the exact temporary directory before recursive deletion.
            $resolvedWorkingPath = (Resolve-Path -LiteralPath $workingPath).ProviderPath
            $resolvedParent = [System.IO.Path]::GetDirectoryName($resolvedWorkingPath).TrimEnd('\')
            $expectedParent = (Resolve-Path -LiteralPath $temporaryParent).ProviderPath.TrimEnd('\')
            if ($resolvedParent -ne $expectedParent -or
                [System.IO.Path]::GetFileName($resolvedWorkingPath) -notmatch '^WinRAR-Activator-[0-9a-f]{32}$') {
                throw "Refusing cleanup outside the temporary package directory: $resolvedWorkingPath"
            }
            Remove-Item -LiteralPath $resolvedWorkingPath -Recurse -Force -ErrorAction Stop
        }
    }
} -LauncherArguments $Arguments
