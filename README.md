# Window Screenshot Action

Launch native applications and save **their windows**, not the whole desktop, as PNG files on Ubuntu, Windows, and macOS. The action fails if it cannot find the application's window. It does not upload images; use `actions/upload-artifact` for that.

## Usage

Create and push a `v1` tag after publishing this repository to use the example below.

```yaml
steps:
  - uses: actions/checkout@v7
  - name: Install Linux screenshot tools
    if: runner.os == 'Linux'
    run: sudo apt-get update && sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
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

`app-names` and `output-files` are nonempty, space-separated lists of equal length. Paths are relative to the workspace and must contain no whitespace. Output paths may include directories. The action starts each executable directly, waits for a visible window owned by that process, captures one window, then stops the process. Applications should not require command-line arguments or launch their GUI in another process.

On Linux, capture uses a private Xvfb display, Openbox, `wmctrl`, and ImageMagick. Applications must support X11 and expose `_NET_WM_PID` (GTK applications do). On macOS, it uses CoreGraphics and `screencapture`; the hosted runner provides Swift. On Windows, it uses Win32 `PrintWindow` and PowerShell, so overlapping windows are excluded; applications whose rendering is incompatible with `PrintWindow` may produce incomplete images. Build the application for the runner's OS before invoking this action.

The tests launch small GTK, WinForms, and AppKit applications and capture each twice. Windows also checks that an overlapping window does not appear in the image. Real capture on all three GitHub-hosted runners should pass before creating the `v1` tag.

## License

MIT. The original screenshot implementation was part of [UIng](https://github.com/kojix2/uing).
