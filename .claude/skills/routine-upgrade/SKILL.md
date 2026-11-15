---
description: Perform a routine upgrade.
disable-model-invocation: true
user-invocable: true
---

## Steps

1. Note the set of current toplevel store paths for hosts (`readlink /run/current-system` over SSH). You'll need this for the changelog.
2. Run `just update` to update flake inputs.
3. Perform a colmena build (all targets): `colmena build`.
4. Run NixOS tests: `nix flake check`.
5. Fix build/test failures and deprecation warnings.
6. Run a test deploy on all targets: `colmena apply test`.
7. Validate the deployment by checking for failed systemd units.
8. Once everything passes, commit with a changelog.

## Running Heavy Commands

Never run builds, checks, deploys, or `nix copy` directly (steps 1, 3, 4, 6). Wrap them with the launcher instead:

```sh
.claude/skills/routine-upgrade/launch-in-tmux colmena build
```

- It runs the command in a new window of the `lab@builds` tmux session and prints the log file path.
- Wait for the log to end with an `exit status: <code>` line. Use Monitor with an until-loop; don't poll in a tight loop.
- Read results from the log (`tail`/`grep`, not the whole thing). Expect ANSI color codes.
- The window stays open until the user closes it. Don't wait for that.

Cheap commands (`readlink` over SSH, `systemctl --failed`, `dix`) can run directly.

## Known Breakage

- **Caddy plugin hash**: Caddy is built with plugins pinned by hash. Caddy upgrades usually invalidate it.

## Curating a Changelog

- Old store paths usually aren't in the local store. Fetch them with `nix copy --no-check-sigs --from ssh-ng://<host> <path>` (via the launcher).
- Use `dix <old-store-path> <new-store-path>` to diff the system's Nix store paths before and after the update.
- Summarize meaningful package version changes and deprecations from the diff.
- Do not search the web or dive into source code to identify changes. The `dix` output is your source of truth.
