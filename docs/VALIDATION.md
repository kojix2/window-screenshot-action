# Validation of the v1.0.0 candidate

The implementation was integrated from the supplied reference project on
2026-10-25. These checks ran in the current Linux workspace:

| Check | Result |
| --- | --- |
| Python regression suite | 19 tests passed, including input validation, process cleanup, and simulated Linux/macOS captures. |
| Bash syntax | All `scripts/*.sh` passed `bash -n`. |
| YAML parsing | `action.yml` and all `.github/*.yml` files parsed with PyYAML. |
| Action metadata | Composite runtime, declared outputs, and step shells checked. |
| Documentation | Local Markdown links resolved. |
| Git whitespace | `git diff --check` passed. |

The capture tests substitute window discovery and image capture commands. They
verify orchestration and failure behavior, but do not verify native PNG rendering.
PowerShell, ShellCheck, actionlint, Xvfb, and wmctrl were unavailable in this
workspace. Windows desktop capture and macOS CoreGraphics capture could not be
run locally.

Before release, run the included **Test** and **Lint** workflows on the exact
release commit. The Test workflow builds and captures real GTK, WinForms, and
AppKit windows on their respective runners. Inspect all three screenshot
artifacts as well as the workflow results. Do not tag or publish the release
until those checks pass.

No commit, push, tag, GitHub release, or Marketplace listing was created by this
integration.
