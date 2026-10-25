# Changelog

## Unreleased — v1.0.0 candidate

Initial Marketplace release candidate. The release date and version tag are set
only when the maintainer publishes the release.

### Features

- Capture native application windows as PNGs on Linux, Windows, and macOS.
- Launch multiple executables sequentially with explicit filenames or a pattern.
- Support space-, tab-, and newline-separated path lists consistently across OSes.
- Configure window discovery timeout and capture delay.
- Expose `files` and `count` outputs for artifact upload steps.
- Include Marketplace author and branding metadata, examples, and release guidance.

### Reliability

- Validate inputs and executable existence before launching applications.
- Reject duplicate output paths, common path aliases, and executable overwrites.
- Write captures to temporary files before replacing destination images.
- Stop and reap directly launched Unix processes, escalating if they ignore TERM.
- Preserve Windows DPI restoration and graphics-resource cleanup on errors.
- Check window-manager readiness instead of relying on a fixed startup delay.
- Forward Xvfb startup errors to the job log instead of discarding them.
- Add input/lifecycle regression tests and extend native three-platform CI.

Existing `os`, `app-names`, `output-files`, and `output-pattern` inputs remain.
Validation now rejects absolute paths, parent traversal, unknown placeholders,
and non-PNG filenames; callers relying on these previously unchecked inputs must
use workspace-relative PNG paths.
