# Changelog

## Unreleased

- Capture native windows on Ubuntu, Windows, and macOS.
- Capture multiple executables with explicit PNG paths or an output pattern.
- Add configurable window timeout and capture delay, plus `files` and `count` outputs.
- Validate paths and preserve existing PNGs when capture fails.

The original four inputs remain available. Absolute paths, parent traversal,
unknown placeholders, and non-PNG output paths are now rejected.
