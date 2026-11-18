# Repository Guidelines

## Project Structure & Module Organization

This repository is an initial scaffold. `README.md` contains the project title; no source code, tests, assets, dependency manifests, or CI configuration are checked in. Keep the project overview and setup instructions in `README.md`. Introduce directories such as `src/`, `tests/`, and `assets/` only when needed, and document their roles when adding them.

## Build, Test, and Development Commands

No build, installation, test, or local application commands are configured yet. Useful repository checks are:

- `git status --short`: inspect modified and untracked files.
- `git ls-files`: list tracked repository contents.
- `git diff --check`: detect whitespace errors in tracked changes.

When introducing executable code, document the required runtime, dependency installation, and exact build and run commands in `README.md` alongside the implementation.

## Coding Style & Naming Conventions

Use clear Markdown headings, fenced code blocks for commands, and repository-relative paths in documentation. Prefer descriptive filenames and focused changes. Use spaces for indentation; once a programming language is introduced, follow its standard formatter and document the chosen indentation width. No formatter or linter is currently configured, and no language-specific naming convention has been established.

## Testing Guidelines

No testing framework, automated tests, or coverage threshold exists. For documentation changes, check command accuracy, links, paths, and Markdown rendering. For new behavior, add appropriate tests and document how to run them in the same contribution. Choose test filenames that identify the behavior under test and follow the selected framework's conventions. Report the checks actually performed and any validation still pending.

## Commit & Pull Request Guidelines

Git history contains only `Initial commit`, so it establishes no recurring commit convention. Use short, imperative subjects, such as `Document local setup`, and keep each commit focused. Pull requests should explain the change, its purpose, and validation performed. Link relevant issues when available; include screenshots when a change introduces or modifies visible UI.
