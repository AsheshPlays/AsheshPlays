# Bundled registration generator

Unmodified Windows x86 command-line release of
[bitcookies/winrar-keygen v4.3.0](https://github.com/bitcookies/winrar-keygen/releases/tag/v4.3.0).
The x86 executable runs on Windows x86 and x64. It is included so custom names
can be generated without a runtime download.

- Binary: `winrar-keygen-x86.exe` (599,040 bytes).
- Source: <https://github.com/bitcookies/winrar-keygen/tree/v4.3.0>.
- Download: <https://github.com/bitcookies/winrar-keygen/releases/download/v4.3.0/winrar-keygen-x86.exe>.
- SHA-256: `9b9be01389980dc3a22c995773671364f8823cc5ffab96f9b701a5e6220bbbb2`.
- License: [MIT](LICENSE), Copyright (c) 2021 Bitcookies.

`src/Registration.psm1` checks the executable's hash before every use and calls
it with the selected name, the fixed organization, `--text --encoding utf8`.
The generator only returns text to the parent process. The project handles
preview, file export, backup, and installation separately.

Update the pinned binary, its digest in the module, this metadata, and its
license together when intentionally changing the generator version.
