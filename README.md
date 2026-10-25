# Window Screenshot Action

Capture a native application window as a PNG on Ubuntu, Windows, or macOS. The
application must already be built and must create a visible window in its own
process. The action captures one window per executable, then stops that process.

## Example

```yaml
name: Screenshot
on: workflow_dispatch

jobs:
  screenshot:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - run: sudo apt-get update && sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
      # Build ./my-app here.
      - uses: kojix2/window-screenshot-action@main
        id: capture
        with:
          os: ubuntu
          app-names: my-app
          output-files: screenshots/my-app.png
      - uses: actions/upload-artifact@v7
        with:
          name: screenshot
          path: ${{ steps.capture.outputs.files }}
          if-no-files-found: error
```

Use `os: windows` on a Windows runner and `os: macos` on a macOS runner.

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `os` | Required | `ubuntu`, `windows`, or `macos`; must match the runner. |
| `app-names` | Required | Whitespace-separated executable paths relative to the workspace. |
| `output-files` | — | Whitespace-separated PNG paths, one per executable. |
| `output-pattern` | `{name}.png` | Used when `output-files` is omitted. `{name}` is the executable basename without `.exe`; `{os}` is the `os` input. |
| `window-timeout` | `15` | Seconds to wait for a window (integer 1–300). |
| `capture-delay` | `1` | Seconds to wait after finding a window (integer 0–60). |

For multiple applications, use a space-separated or multiline `app-names` list.
Captures run in list order. For example:

```yaml
app-names: |
  build/window
  build/dialog
output-pattern: screenshots/{name}-{os}.png
```

Paths cannot contain whitespace or `..`; shell quoting and command-line arguments
are not supported. Use workspace-relative paths and forward slashes. Output paths
must end in `.png` and be unique. Parent directories are created automatically.
An existing PNG is replaced only after its new capture succeeds.

Unix executables need execute permission. On Windows, `.exe` may be omitted. On
macOS, specify the executable inside an `.app` bundle, such as
`MyApp.app/Contents/MacOS/MyApp`.

## Outputs

- `files`: Newline-separated workspace-relative PNG paths, suitable for an artifact upload step.
- `count`: Number of captured PNGs.

Outputs are set only when every capture succeeds.

## Platform requirements

| Runner | Requirements and limits |
| --- | --- |
| Ubuntu | Install `xvfb xauth openbox wmctrl imagemagick`. Applications must support X11 and expose `_NET_WM_PID`. |
| Windows | Requires an interactive desktop. `PrintWindow` may produce blank images for some GPU-rendered applications. |
| macOS | Requires `swiftc`, `screencapture`, a GUI session, and Screen Recording permission for the runner process. |

The window must belong to the launched process. Launchers that hand off to another
process are not supported. `window-timeout` covers window discovery; set a job
`timeout-minutes` to bound the whole job.

For development commands, see [CONTRIBUTING.md](CONTRIBUTING.md). For releases, see
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## License

[MIT](LICENSE). The capture implementation originated in
[UIng](https://github.com/kojix2/uing).
