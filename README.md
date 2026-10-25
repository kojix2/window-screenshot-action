# Window Screenshot Action

Launch a native GUI application and save its window as a PNG on Linux, Windows, or macOS. Replace the build comments below with steps that create the named executable in the workspace.

## Ubuntu

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
          if-no-files-found: error
```

Download the `screenshot` artifact from the workflow run.

## Linux, Windows, and macOS

```yaml
name: Screenshots
on: workflow_dispatch

jobs:
  screenshot:
    strategy:
      matrix:
        include:
          - { runner: ubuntu-latest, os: ubuntu, app: my-app }
          - { runner: windows-latest, os: windows, app: my-app.exe }
          - { runner: macos-latest, os: macos, app: my-app }
    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v7
      - if: matrix.os == 'ubuntu'
        run: sudo apt-get update && sudo apt-get install -y xvfb xauth openbox wmctrl imagemagick
      # Build or unpack the executable for this runner here.
      - uses: kojix2/window-screenshot-action@main
        with:
          os: ${{ matrix.os }}
          app-names: ${{ matrix.app }}
          output-files: screenshot-${{ matrix.os }}.png
      - uses: actions/upload-artifact@v7
        with:
          name: screenshot-${{ matrix.os }}
          path: screenshot-${{ matrix.os }}.png
          if-no-files-found: error
```

Download the three `screenshot-*` artifacts from the workflow run.

`app-names` and `output-files` also accept matching space-separated lists for capturing several applications. Paths are relative to the workspace and cannot contain spaces. `app-names` accepts executable paths without command-line arguments. Each application must create a visible window in its own process. Linux applications must support X11 and set `_NET_WM_PID`; Windows capture uses `PrintWindow`, which may leave incompatible apps blank.

## Put screenshots in your README

To update images on each push to `main`, replace the trigger in the three-platform workflow with:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

Add this job under `jobs`, alongside `screenshot`:

```yaml
  publish-screenshots:
    needs: screenshot
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v7
      - uses: actions/download-artifact@v8
        with:
          pattern: screenshot-*
          path: screenshots
      - uses: JamesIves/github-pages-deploy-action@v4
        with:
          branch: screenshots
          folder: screenshots
```

After the first successful push, put these links in your README and replace `OWNER/REPO`. GitHub Pages does not need to be enabled.

```markdown
![Ubuntu](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-ubuntu/screenshot-ubuntu.png)
![Windows](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-windows/screenshot-windows.png)
![macOS](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-macos/screenshot-macos.png)
```

This action's own [test workflow](.github/workflows/test.yml) produces these images:

| Linux | Windows | macOS |
| --- | --- | --- |
| ![Linux window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-ubuntu/first.png) | ![Windows window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-windows/first.png) | ![macOS window](https://raw.githubusercontent.com/kojix2/window-screenshot-action/screenshots/screenshot-macos/first.png) |

## License

MIT. The screenshot implementation originated in [UIng](https://github.com/kojix2/uing).
