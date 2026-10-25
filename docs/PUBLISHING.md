# Release

1. Update [CHANGELOG.md](../CHANGELOG.md) with the version and release date.
2. Verify that [README.md](../README.md) matches `action.yml`. Run the **Test**
   and **Lint** workflows on the release commit; inspect all three screenshot
   artifacts, not only their PNG signatures.
3. Confirm the repository is public and the Marketplace accepts the action name
   in `action.yml`. If metadata changes, repeat the CI checks on the new commit.
4. From the tested commit, create and push the first release tags:

   ```bash
   git tag -a v1.0.0 -m "v1.0.0"
   git tag -a v1 -m "Stable v1" 'v1.0.0^{}'
   git push origin refs/tags/v1.0.0 refs/tags/v1
   ```

5. Draft a GitHub release for `v1.0.0`, select **Publish this Action to the GitHub
   Marketplace**, and publish it. Verify the Marketplace page and test `@v1` from
   another repository.

For later releases, create a new version tag from a tested commit and move the
`v1` alias to that commit. Keep version tags immutable.

See GitHub's [Marketplace publishing instructions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace)
for current account and form requirements.
