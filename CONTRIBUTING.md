# Development

The action runs Bash on Ubuntu and macOS, PowerShell on Windows, and a small
Swift helper on macOS. Keep Unix and Windows input validation aligned and keep
Bash compatible with macOS Bash 3.2.

Run from the repository root:

```bash
python3 -m unittest discover -s tests -v
for script in scripts/*.sh; do bash -n "$script"; done
shellcheck -x scripts/*.sh
actionlint
```

On Windows, run `./tests/test_windows.ps1` with PowerShell 7. The Python tests use
fake capture commands; the [Test workflow](.github/workflows/test.yml) runs native
captures on all three platforms. Inspect its screenshots when changing capture
behavior.
