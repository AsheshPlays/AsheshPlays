# WinRAR Activator - Ashesh Development

This package contains the local runtime for Windows 10/11 and Windows
PowerShell 5.1 or later. Extract the whole folder and keep its files together.

Run `WRA.cmd` to choose a registration name. Press Enter at the prompt to keep
`Erich Alfred Bossert`. The organization is fixed as `🄯 Ashesh Development`.

From PowerShell, preview or install with a specific name:

```powershell
.\WRA.cmd --preview --name "Your Registration Name"
.\WRA.cmd --name "Your Registration Name"
```

For export, choose an unused output filename in an existing folder:

```powershell
.\WRA.cmd --name "Your Registration Name" --export "$env:TEMP\Ashesh-rarreg.key"
```

Installation requests administrator privileges and backs up an existing key as
`rarreg.key.<guid>.bak`. Restart WinRAR and inspect **Help > About WinRAR**;
application recognition requires manual verification.

Inspired by and adapted from the original project by
[@NaeemBolchhi](https://github.com/NaeemBolchhi/WinRAR-Activator).
The scripts use GPL-3.0; the bundled bitcookies generator retains its MIT
license. Full terms and attribution are in `LICENSE`, `NOTICE`, and
`tools/winrar-keygen/LICENSE`. These licenses do not grant a WinRAR license.

Project page: <https://asheshplays.github.io/AsheshPlays/winrar-activator/>

Development sources and tests:
<https://github.com/AsheshPlays/AsheshPlays/tree/main/pages/winrar-activator>
