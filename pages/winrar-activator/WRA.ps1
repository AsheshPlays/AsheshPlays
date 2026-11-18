# GPL-3.0-only. See LICENSE and NOTICE for upstream attribution.
# Modified 2026-11-18: interactive registration names and fixed UTF-8 organization.
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments = @()
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $options = @{ Mode = 'Install'; Name = $null; NameSpecified = $false; ExportPath = $null; Elevated = $false }
    $modeSpecified = $false
    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $argument = $Arguments[$index].ToLowerInvariant()
        switch ($argument) {
            { $_ -in @('-name', '--name') } {
                if ($options.NameSpecified -or $index + 1 -ge $Arguments.Count -or $Arguments[$index + 1].StartsWith('-')) {
                    throw 'Specify one registration name after -Name or --name.'
                }
                $options.Name = $Arguments[++$index]
                $options.NameSpecified = $true
            }
            { $_ -in @('-preview', '--preview', '-help', '--help', '-h', '-export', '--export', '-exportpath') } {
                if ($modeSpecified) { throw 'Choose one mode: installation, preview, export, or help.' }
                $modeSpecified = $true
                if ($_ -in @('-preview', '--preview')) {
                    $options.Mode = 'Preview'
                } elseif ($_ -in @('-help', '--help', '-h')) {
                    $options.Mode = 'Help'
                } else {
                    $options.Mode = 'Export'
                    if ($index + 1 -ge $Arguments.Count -or $Arguments[$index + 1].StartsWith('-')) {
                        throw 'Specify an unused output filename after --export or -ExportPath.'
                    }
                    $options.ExportPath = $Arguments[++$index]
                }
            }
            '-elevated' { $options.Elevated = $true }
            default { throw "Unknown argument: $($Arguments[$index]). Use --help for options." }
        }
    }

    if ($options.Mode -eq 'Help') {
        Write-Output 'Usage: WRA.cmd [--name "Registration Name"] [--preview | --export "output-file" | --help]'
        Write-Output 'PowerShell: .\WRA.ps1 [-Name "Registration Name"] [-Preview | -ExportPath "output-file" | -Help]'
        Write-Output 'Installation prompts for a name if --name/-Name is omitted; Enter keeps the default.'
        Write-Output 'Preview and export use the default name when omitted and do not request elevation.'
        Write-Output 'The organization is fixed; use a Unicode-capable console font to display its symbol.'
        exit 0
    }

    Import-Module (Join-Path $PSScriptRoot 'src\Registration.psm1') -Force -DisableNameChecking
    $nameOptions = @{}
    if ($options.NameSpecified) { $nameOptions.Name = $options.Name }
    if ($options.Mode -eq 'Install' -and -not $options.NameSpecified -and -not $options.Elevated) { $nameOptions.Prompt = $true }
    $registrationName = Resolve-RegistrationName @nameOptions
    $organization = Get-RegistrationOrganization
    $title = "WinRAR Activator v0.02 - $organization"
    $Host.UI.RawUI.WindowTitle = $title
    Write-Output $title
    Write-Output "Registration name: $registrationName"
    Write-Output $organization
    Write-Output ''

    if ($options.Mode -eq 'Install') {
        $installationDirectory = Find-WinRARDirectory
        if (-not (Test-IsAdministrator)) {
            if ($options.Elevated) { throw 'The elevated process does not have administrator privileges.' }
            exit (Start-ElevatedRegistration -ScriptPath $PSCommandPath -Name $registrationName)
        }
    }

    $data = New-RegistrationData -Name $registrationName
    if ($options.Mode -eq 'Preview') {
        Write-Output 'Preview only. No files will be written.'
        Write-Output ([System.Text.Encoding]::UTF8.GetString($data))
    } elseif ($options.Mode -eq 'Export') {
        $outputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($options.ExportPath)
        Export-RegistrationData -Data $data -Path $outputPath
        Write-Output "Registration data exported to `"$outputPath`"."
    } else {
        $result = Install-RegistrationData -Data $data -Directory $installationDirectory
        if ($result.BackupPath) { Write-Output "Existing registration saved to `"$($result.BackupPath)`"." }
        Write-Output "Registration file installed for $registrationName / $organization."
        Write-Output 'Restart WinRAR and check Help, About WinRAR to verify recognition.'
        $null = Read-Host 'Press Enter to finish'
    }
    exit 0
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 1
}
