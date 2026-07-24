---
description: Perform a routine upgrade.
disable-model-invocation: true
user-invocable: true
---

## Steps

1. Note the set of current toplevel store paths for hosts. You'll need this for the changelog.
2. Run `just update` to update flake inputs.
3. Perform a colmena build (all targets).
4. Run NixOS tests (`nix flake check`).
5. Fix build/test failures and deprecation warnings.
6. Run a test deploy on all targets.
7. Validate the deployment by checking for failed systemd units.
8. Once everything passes, commit with a changelog.

## Curating a Changelog

- Use `dix <old-store-path> <new-store-path>` to diff the system's Nix store paths before and after the update.
- Summarize meaningful package version changes and deprecations from the diff.
- Do not search the web or dive into source code to identify changes. The `dix` output is your source of truth.
