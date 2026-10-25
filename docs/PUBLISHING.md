# Publish to GitHub Marketplace

This repository contains a composite action at the root. No build output or
JavaScript bundle needs to be committed. Keep `action.yml`, `scripts/`, the license,
and documentation together in the release commit.

## Release gate

1. Review the prepared changes in `kojix2/window-screenshot-action`. Commit and
   push them on a branch, then merge after review.
2. Run **Test** and **Lint** for the exact candidate commit. All three capture jobs
   must pass, including Windows and macOS. Inspect the three screenshot artifacts;
   a valid PNG alone does not prove that the intended UI was captured.
3. Confirm `README.md` matches the input/output definitions in `action.yml` and
   retains the MIT license. Change the changelog heading from the candidate entry
   to `1.0.0 — YYYY-MM-DD` using the actual release date, then test that final commit.
4. Make sure the repository is public. GitHub requires a unique action `name`;
   the current name is **Capture native windows**. Search results cannot reserve
   that name; confirm acceptance in GitHub's release form. If GitHub rejects the
   name, change it in `action.yml` and validate the new commit before tagging it.

Local validation notes are in `docs/VALIDATION.md`.
Those checks are not a substitute for green native CI on the release commit.

## First release

From a clean checkout of the tested commit, create the immutable version tag and
the stable major-version alias. Do this only if these tags do not already exist:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git tag -a v1 -m "Stable v1" 'v1.0.0^{}'
git push origin refs/tags/v1.0.0 refs/tags/v1
```

Then open the repository on GitHub:

1. Go to `action.yml` and choose **Draft a release**, or open **Releases → Draft a
   new release**. Choose the existing `v1.0.0` tag.
2. Select **Publish this Action to the GitHub Marketplace**.
3. Accept the GitHub Marketplace Developer Agreement using the repository owner's
   account if GitHub requests it. Enable two-factor authentication if required.
4. Confirm the metadata validation shows **Everything looks good!**. Choose
   **Testing** as the primary category and optionally **Utilities** as a secondary
   category, if those categories are available in the form.
5. Set the title to **v1.0.0 — Window Screenshot Action** and paste the release notes
   below. Publish the release. Avoid marking the first stable version as a prerelease.
6. Open the resulting Marketplace page and verify its description, README, branding,
   and installation example. Try `kojix2/window-screenshot-action@v1` in a separate
   consumer repository.

The account agreement, name acceptance, and Marketplace publication are GitHub UI
steps; producing this source package does not perform them or reserve the name.

## Suggested v1.0.0 release notes

Launch native GUI applications and capture their windows as PNGs on Linux,
Windows, and macOS.

- Capture multiple executables using explicit output filenames or a path pattern.
- Configure the window discovery timeout and delay before capture.
- Pass captured paths directly to artifact upload steps using the `files` output.
- Validate inputs before launch and preserve existing PNGs when a capture fails.
- Clean up directly launched processes and native graphics resources.

Linux uses Xvfb and X11. Windows uses `PrintWindow`; some GPU-rendered applications
may not capture correctly. macOS requires an accessible GUI session and screen
recording permission. See the README for platform prerequisites and limitations.

## Subsequent releases

Create a new immutable tag such as `v1.0.1` only after its exact commit passes CI.
Update the `v1` alias to that reviewed release commit. Do not retarget immutable
version tags. Changes to input meanings, outputs, or supported behavior that break
existing workflows belong in a new major version. Repository rules may protect
tag updates; follow those rules instead of deleting protected tags.

## Official references

- [Publishing actions in GitHub Marketplace](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace)
- [Action metadata syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax)

Requirements checked against these pages on 2026-10-25. GitHub remains authoritative
for account eligibility, reserved names, categories, and publication-time validation.
