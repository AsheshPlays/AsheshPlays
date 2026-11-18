# GPL-3.0-only. See LICENSE and NOTICE.
# Build the Pages-hosted runtime archive without including the launcher itself.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$payloadFiles = @(
    'WRA.cmd', 'WRA.ps1', 'rarreg.key', 'README.md', 'LICENSE', 'NOTICE',
    'src/Registration.psm1', 'tools/winrar-keygen/winrar-keygen-x86.exe',
    'tools/winrar-keygen/LICENSE', 'tools/winrar-keygen/README.md'
)
$downloadsPath = Join-Path $PSScriptRoot 'downloads'
$temporaryArchive = Join-Path ([System.IO.Path]::GetTempPath()) ('WRA-Package-' + [guid]::NewGuid().ToString('N') + '.zip')
try {
    $stream = [System.IO.File]::Open($temporaryArchive, [System.IO.FileMode]::CreateNew)
    $archive = [System.IO.Compression.ZipArchive]::new($stream, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($relativePath in ($payloadFiles | Sort-Object)) {
            $sourceRelativePath = if ($relativePath -eq 'README.md') { 'RUNTIME.md' } else { $relativePath }
            $sourcePath = Join-Path $PSScriptRoot $sourceRelativePath
            if (-not [System.IO.File]::Exists($sourcePath)) { throw "Required package source is missing: $relativePath" }
            $entry = $archive.CreateEntry(('WinRAR-Activator/' + $relativePath), [System.IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2026, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
            $sourceStream = [System.IO.File]::OpenRead($sourcePath)
            try {
                $entryStream = $entry.Open()
                try { $sourceStream.CopyTo($entryStream) } finally { $entryStream.Dispose() }
            } finally { $sourceStream.Dispose() }
        }
    } finally {
        $archive.Dispose()
        $stream.Dispose()
    }
    $digest = (Get-FileHash -LiteralPath $temporaryArchive -Algorithm SHA256).Hash.ToLowerInvariant()
    $installerPath = Join-Path $PSScriptRoot 'Install.ps1'
    $installer = [System.IO.File]::ReadAllText($installerPath)
    $pattern = '(?m)^(\s*\$packageSha256 = '')[0-9a-f]{64}('')'
    if ([regex]::Matches($installer, $pattern).Count -ne 1) { throw 'Expected exactly one package digest in Install.ps1.' }
    $installer = [regex]::Replace($installer, $pattern, ('${1}' + $digest + '${2}'))
    if (-not [System.IO.Directory]::Exists($downloadsPath)) { $null = New-Item -ItemType Directory -Path $downloadsPath }
    [System.IO.File]::Copy($temporaryArchive, (Join-Path $downloadsPath 'winrar-activator.zip'), $true)
    [System.IO.File]::WriteAllText($installerPath, ($installer -replace '\r?\n', "`r`n"), [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $downloadsPath 'SHA256SUMS.txt'), "$digest  winrar-activator.zip`n", [System.Text.Encoding]::ASCII)
    Write-Output "Built downloads/winrar-activator.zip; SHA-256 $digest"
} finally {
    if ([System.IO.File]::Exists($temporaryArchive)) { [System.IO.File]::Delete($temporaryArchive) }
}
