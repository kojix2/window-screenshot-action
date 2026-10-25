# Window Screenshot Action

Launch native applications and save **their windows**, not the whole desktop, as PNG files on Ubuntu, Windows, and macOS. The action fails if it cannot find the application's window. It does not upload images; use `actions/upload-artifact` for that.

## Usage

Create and push a `v1` tag after publishing this repository to use the example below.

```yaml
steps:
  - uses: actions/checkout@v7
  - name: Install Linux screenshot tools
    if: runner.os == 'Linux'
    run: sudo apt-get update && sudo apt-get install -y xvfb openbox wmctrl x11-utils imagemagick
  - uses: kojix2/window-screenshot-action@v1
    with:
      os: ubuntu # windows or macos on those runners
      app-names: my-app
      output-files: my-app.png
  - uses: actions/upload-artifact@v7
    with:
      name: screenshots
      path: my-app.png
```

`app-names` and `output-files` are space-separated lists of equal length. Each executable path is relative to the job's working directory and must contain no spaces. The action starts each executable, waits for a visible window, captures that window, then stops the process. Applications should not require command-line arguments. Output paths may include directories.

On Linux, capture uses Xvfb, Openbox, `wmctrl`, `xprop`, and ImageMagick. On macOS, it uses CoreGraphics and `screencapture`; the hosted runner provides Swift. On Windows, it uses Win32 and PowerShell. Build the application for the runner's OS before invoking this action.

## License

MIT. The original screenshot implementation was part of [UIng](https://github.com/kojix2/uing).
