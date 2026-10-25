# Window Screenshot Action

Launch a native GUI application and save its window as a PNG on Linux, Windows, or macOS.

## Use

Replace the marked comment with a step that builds or unpacks `./my-app`:

```yaml
name: Screenshot
on: workflow_dispatch

jobs:
  screenshot:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: sudo apt-get update && sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
      # Build or unpack ./my-app here.
      - uses: kojix2/window-screenshot-action@main
        with:
          os: ubuntu
          app-names: my-app
          output-files: screenshot.png
      - uses: actions/upload-artifact@v7
        with:
          name: screenshot
          path: screenshot.png
```

Download the `screenshot` artifact from the workflow run.

For Windows, use `windows-latest`, `os: windows`, and an `.exe` executable. For macOS, use `macos-latest` and `os: macos`. Only Linux needs the install step above.

`app-names` and `output-files` accept matching space-separated lists for capturing several applications. Paths are relative to the workspace and cannot contain spaces. Do not include command-line arguments. Each application must create a visible window in its own process. Linux applications must support X11 and set `_NET_WM_PID`. Windows capture uses `PrintWindow`, which may leave incompatible apps blank. The action fails if it cannot find a window.

## Screenshots

These images come from the [three-platform test workflow](.github/workflows/test.yml) and update after successful runs on `main`.

| Linux | Windows | macOS |
| --- | --- | --- |
| ![Linux window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/ubuntu.png) | ![Windows window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/windows.png) | ![macOS window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/macos.png) |

## License

MIT. The screenshot implementation originated in [UIng](https://github.com/kojix2/uing).
