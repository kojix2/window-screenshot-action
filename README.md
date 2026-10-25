# Window Screenshot Action

[![Test](https://github.com/kojix2/window-screenshot-action/actions/workflows/test.yml/badge.svg)](https://github.com/kojix2/window-screenshot-action/actions/workflows/test.yml)
[![MIT license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Launch native desktop applications and save their windows as PNGs on Linux,
Windows, and macOS. Useful for documenting GUI libraries, collecting CI artifacts,
and checking how an application renders on each platform.

The action captures one window per executable, in order, then stops the process it
started. It does not build applications or upload images. It is a composite action
with no npm dependencies and requires no GitHub token or repository write access.

## Quick start: Ubuntu

Build or unpack your executable before the capture step. Replace `my-app` with its
path relative to the repository workspace.

```yaml
name: Screenshot
on: workflow_dispatch

permissions:
  contents: read

jobs:
  screenshot:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v7
      - name: Install capture dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
      # Add your build steps here to create ./my-app.
      - name: Capture window
        id: capture
        uses: kojix2/window-screenshot-action@v1
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

Download the `screenshot` artifact from the workflow run. The `v1` tag is the stable
major-version entry point created at the first release; before that release, use
`@main` to evaluate the action. Pin a full reviewed commit SHA for reproducible use.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `os` | Yes | — | `ubuntu`, `windows`, or `macos`; must match the runner OS. |
| `app-names` | Yes | — | Whitespace-separated executable paths relative to `github.workspace`. |
| `output-files` | No | Empty | Whitespace-separated PNG paths, one per executable. Takes precedence over `output-pattern`. |
| `output-pattern` | No | `{name}.png` | PNG path template. `{name}` is the executable basename without `.exe` (case-insensitive); `{os}` is the `os` input. |
| `window-timeout` | No | `15` | Integer seconds to wait for each application's window, from 1 to 300. |
| `capture-delay` | No | `1` | Integer seconds to wait after finding the window, from 0 to 60, allowing it to finish rendering. |

Space, tab, newline, and CRLF separators are accepted in the two path lists. Paths
inside a list cannot contain whitespace; shell quotes are not interpreted. No
wildcard expansion or shell evaluation is performed. Command-line arguments are
not supported. Set environment variables with the calling step's `env` when needed.

Use workspace-relative paths without `..`, preferably with forward slashes on all
platforms. The action runs applications with `github.workspace` as their working
directory, independently of the caller's `defaults.run.working-directory`. On Unix,
executables must have execute permission. On Windows, `.exe` may be omitted if
the matching executable exists. On macOS, supply the executable inside
an `.app` bundle, such as `MyApp.app/Contents/MacOS/MyApp`, not the bundle directory.

Output paths must end in `.png`, be unique, and not name an input executable.
`./file.png` and `file.png` are treated as the same path. Output comparisons are
case-insensitive on Windows and macOS. Parent directories are created as needed.
A completed capture replaces an existing PNG; a failed capture leaves that file
unchanged. Earlier successful captures remain if a later application fails.
Use distinct, ordinary output directories; symlinked directory aliases are not
fully canonicalized by the input validation.

The timeout covers **window discovery**, not compilation, rendering, or a blocked
native capture API. Set a job-level `timeout-minutes`, as in the examples, to bound
the whole job.

## Outputs

| Output | Description |
| --- | --- |
| `files` | Newline-separated workspace-relative PNG paths, in application order. Suitable for `actions/upload-artifact`'s `path`. |
| `count` | Number of captured PNGs, as a string. |

Both outputs are set only after all applications have been captured successfully.
Images are written locally; uploading or publishing them is a separate step.

## Multiple applications

```yaml
- uses: kojix2/window-screenshot-action@v1
  id: capture
  with:
    os: ubuntu
    app-names: |
      build/basic_window
      build/basic_button
      build/basic_slider
    output-pattern: screenshots/{name}-{os}.png
    window-timeout: '30'
    capture-delay: '2'
```

This produces `screenshots/basic_window-ubuntu.png`,
`screenshots/basic_button-ubuntu.png`, and `screenshots/basic_slider-ubuntu.png`.
Executables with the same basename need explicit, distinct `output-files`.

## Linux, Windows, and macOS

```yaml
name: Screenshots
on: workflow_dispatch

permissions:
  contents: read

jobs:
  screenshot:
    timeout-minutes: 15
    strategy:
      fail-fast: false
      matrix:
        include:
          - { runner: ubuntu-latest, os: ubuntu, app: my-app }
          - { runner: windows-latest, os: windows, app: my-app.exe }
          - { runner: macos-latest, os: macos, app: my-app }
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v7
      - if: matrix.os == 'ubuntu'
        run: |
          sudo apt-get update
          sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
      # Build or unpack the appropriate executable for this runner here.
      - uses: kojix2/window-screenshot-action@v1
        id: capture
        with:
          os: ${{ matrix.os }}
          app-names: ${{ matrix.app }}
          output-files: screenshot-${{ matrix.os }}.png
      - uses: actions/upload-artifact@v7
        with:
          name: screenshot-${{ matrix.os }}
          path: ${{ steps.capture.outputs.files }}
          if-no-files-found: error
```

## Platform requirements and limits

| Platform | Requirements | Capture behavior |
| --- | --- | --- |
| Linux (`os: ubuntu`) | Bash, Xvfb, xauth, Openbox, wmctrl, ImageMagick's `import`; application GUI libraries. | Starts a private 1280×800 X11 display and Openbox. Captures the first window associated with the application's PID, including its frame. |
| Windows | PowerShell 7 (`pwsh`), Git Bash for runner validation, an interactive desktop, Win32 and System.Drawing support. | Uses `PrintWindow` with physical-pixel bounds, then trims invisible DWM resize borders. Another window overlapping it is excluded for compatible applications. |
| macOS | Bash 3.2+, Xcode command-line tools (`swiftc`), `screencapture`, an interactive GUI session with screen-recording access. | Compiles a small CoreGraphics helper, selects a visible window by PID (lower layer, then larger area), and captures it without its shadow. |

- Each executable must own its visible window. Launchers that spawn another process,
  single-instance forwarding, background daemons, and command-line wrappers that do
  not `exec` the GUI program are unsupported. Only the directly launched process
  is stopped; this is not a process-tree supervisor.
- Linux applications must support X11 and expose `_NET_WM_PID`. GTK and Qt are asked
  to use X11; Wayland-only applications are unsupported.
- Windows applications using some GPU or custom rendering paths can produce blank
  or incomplete images with `PrintWindow`. The action does not detect visual
  correctness or fall back to a desktop screenshot. Locked/service-only desktops
  are unsupported.
- On a self-hosted Mac, grant Screen Recording access to the runner's host process
  in System Settings and restart that process. A headless SSH/service session may
  not have access to the GUI session. The action does not change privacy settings.
- Multi-window selection, UI interactions, pixel-identical cross-platform rendering,
  and automatic visual-diff assertions are outside this action's scope. Increase
  `capture-delay` if a splash screen or delayed layout appears in the image.
- Run only trusted executables. They run with the job's permissions, and screenshots
  may contain whatever those applications display.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `Required command not found` | Install the Linux dependencies above or the macOS command-line tools. |
| `Executable not found or not executable` | Build first, check the workspace-relative path, and use `chmod +x` on Unix if needed. |
| `No window found` / `CoreGraphics window not found` | Confirm the launched PID owns a visible window; check GUI access and increase `window-timeout`. |
| A splash screen or incomplete layout | Increase `capture-delay`; the action detects a window, not application readiness. |
| Black or incomplete Windows image | Check whether the application supports `PrintWindow`; test software rendering if available. |
| macOS capture fails or is empty | Check Screen Recording access and the runner's GUI session. |
| Duplicate output path | Use explicit unique filenames when basenames collide. |

## Examples and development

The [test workflow](.github/workflows/test.yml) builds native GTK, WinForms, and
AppKit fixtures, checks PNG dimensions, and tests Windows capture under an
obscuring window. The workflow publishes successful main-branch example images:

| Linux | Windows | macOS |
| --- | --- | --- |
| ![Linux window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-ubuntu/smoke-ubuntu.png) | ![Windows window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-windows/smoke-windows.png) | ![macOS window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-macos/smoke-macos.png) |

See [publishing screenshots](docs/SCREENSHOTS.md),
[development and test commands](CONTRIBUTING.md),
[release instructions](docs/PUBLISHING.md), and the [changelog](CHANGELOG.md).

## License

[MIT](LICENSE). The screenshot implementation originated in
[UIng](https://github.com/kojix2/uing).
