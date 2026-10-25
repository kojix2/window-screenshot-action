# Development

The runtime is a composite action using Bash, PowerShell, and a small Swift helper.
There is no package installation or bundle-generation step for releasing the
source. Keep the behavior of `scripts/inputs.sh` and `scripts/inputs.ps1` aligned.
Preserve Bash 3.2 compatibility for the system shell on macOS.

From the repository root:

```bash
python3 -m unittest discover -s tests -v
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck -x scripts/*.sh
actionlint
```

On Windows, using PowerShell 7:

```powershell
./tests/test_windows.ps1
```

The Python tests use only the standard library. They test parsing and process
cleanup with fake window/capture commands; they do not prove that GUI capture
works. The native integration tests run in `.github/workflows/test.yml` on the
three OS runners. Review the resulting images before a release. The Linux test
requires GTK development files in addition to the runtime dependencies.

To run the Linux fixture locally:

```bash
sudo apt-get update
sudo apt-get install -y libgtk-3-dev xvfb xauth openbox wmctrl imagemagick
read -r -a gtk_flags <<< "$(pkg-config --cflags --libs gtk+-3.0)"
cc tests/fixtures/window.c -o smoke "${gtk_flags[@]}"
ACTION_PATH="$PWD" APP_NAMES=smoke OUTPUT_FILES=smoke.png \
  OUTPUT_PATTERN='{name}.png' REQUESTED_OS=ubuntu \
  bash scripts/run-unix.sh
```

Issue reports should include the runner OS, hosted or self-hosted status, action
commit/version, relevant inputs, and capture logs. Do not include private
application data or credentials in screenshots.
