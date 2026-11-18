# Ashesh Development Pages

This directory is the GitHub Pages publishing root. Existing profile files at
the repository root and the contribution-snake workflow remain independent.

- `index.html`, `a.css`, and `side-animation.js` reuse the supplied asheshdev.com
  terminal design. Homepage links lead to the nested activator project.
- `assets/` contains shared page styling and the existing profile favicon.
- `winrar-activator/` contains the project page, scripts, licenses, tests, and
  downloadable runtime package.

Public routes:

- Home: <https://asheshplays.github.io/AsheshPlays/>
- Activator: <https://asheshplays.github.io/AsheshPlays/winrar-activator/>
- Online launcher: <https://asheshplays.github.io/AsheshPlays/winrar-activator/Install.ps1>

The new `.github/workflows/pages.yml` workflow deploys only this directory.
The existing `.github/workflows/main.yml` is preserved.

For local preview, run `python -m http.server 8765 --directory pages` from the
repository root. Open <http://localhost:8765/> or its `/winrar-activator/` route.
Rebuild the runtime ZIP using `winrar-activator/build-package.ps1` whenever its
runtime sources or included documentation change, then run the project checks.
