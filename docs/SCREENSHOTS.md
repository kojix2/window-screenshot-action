# Publish screenshots for a README

Use the three-platform workflow from the README. To update images on every push
to `main`, change its trigger to:

```yaml
on:
  push:
    branches: [main]
  workflow_dispatch:
```

Add this job alongside `screenshot`. It publishes the captured images to a
`screenshots` branch; the capture action itself does not write to your repository.

```yaml
  publish-screenshots:
    needs: screenshot
    if: github.ref == 'refs/heads/main' && github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    concurrency: screenshots
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

After the first successful publication, replace `OWNER/REPO` in these links:

```markdown
![Ubuntu](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-ubuntu/screenshot-ubuntu.png)
![Windows](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-windows/screenshot-windows.png)
![macOS](https://raw.githubusercontent.com/OWNER/REPO/screenshots/screenshot-macos/screenshot-macos.png)
```

Use a public repository if the images must be publicly viewable. GitHub Pages does
not need to be enabled. The publishing job updates the contents of the
`screenshots` branch, so do not use that branch for unrelated work.
