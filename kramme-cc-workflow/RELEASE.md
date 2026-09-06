# Release Process

This document describes how to release a new version of kramme-cc-workflow.

Run the commands in this document from the plugin root (`kramme-cc-workflow/`). In this file, `.claude-plugin/plugin.json` is the plugin manifest and `package.json` is the plugin package. The repository-root `package.json` is the npm installer entrypoint and is not bumped by the plugin release flow.

## Version Numbering

- **Patch** (0.2.0 → 0.2.1): Bug fixes, documentation updates, minor improvements
- **Minor** (0.2.0 → 0.3.0): New commands, agents, skills, or hooks
- **Major** (0.2.0 → 1.0.0): Breaking changes

## Release Preflight

Both script-driven paths — the GitHub Actions workflow and `scripts/release.py` — run the same read-only preflight before editing any file, and refuse when:

- A local `release/vX.Y.Z` branch already exists.
- A `release/vX.Y.Z` branch already exists on `origin`.
- Git cannot be inspected. A failed lookup of `origin`, the local refs, or the index is a blocker rather than proof that the condition is absent, so an unreachable or unauthenticated remote refuses the release.
- Anything outside the release's own files is staged. Those are the plugin's `.claude-plugin/plugin.json`, `package.json`, and `CHANGELOG.md`, plus any sibling plugin manifest named by `.claude-plugin/marketplace.json`. The first three are plugin-root-relative: the repository-root `package.json` is not among them, so commit or unstage any change to it before starting a release.

The Manual Release steps at the end of this document bypass the preflight entirely; check for leftovers yourself before following them.

A refusal prints `Release preflight refused:` and never rewrites your index. The preflight that runs before any edit changes nothing at all.

The release re-checks the local conditions once more just before creating the branch, because `make check-deps`, `make verify`, and — interactively — the confirmation prompt all run in between. A refusal there ends one of two ways:

- `Aborting after restoring release files.` (exit 1) — the version and changelog edits were undone.
- `Aborting with incomplete rollback.` (exit 2) — some edits are still on disk. The run names those files; restore them yourself. Your index is left untouched either way.

The release never deletes, replaces, or force-pushes a branch. A run that fails after creating `release/vX.Y.Z` names the branch it left behind and prints the cleanup command. A successful rollback rewinds that branch to the pre-release commit but does not remove it, so clear it before retrying:

```bash
git branch -D release/vX.Y.Z
git push origin --delete release/vX.Y.Z
```

For a staged-content refusal, commit, `git restore --staged <path>`, or stash the unrelated paths.

Content in the release's own files is different: the release re-reads those files from disk and commits whatever it finds, so unstaging does not keep an edit out of the release. Revert it with `git restore --source=HEAD --staged --worktree <path>`, commit it separately, or stash it first. Plain `git restore <path>` restores the working tree _from the index_, so a staged edit survives it.

## Automated Release

### Option 1: GitHub Actions (Recommended)

Trigger a release from the GitHub UI:

1. Go to **Actions** → **Release**
2. Click **Run workflow**
3. Select version type (patch/minor/major)
4. Optionally enable dry run to preview changes
5. Click **Run workflow**

The workflow will:

- Run tests
- Bump version in the plugin manifest `.claude-plugin/plugin.json` and plugin package `package.json`
- Create a release branch and commit
- Push that branch to `origin` (the only automated push of the release branch)
- Create a Pull Request to main
- After PR merge, automatically create git tag and GitHub Release

### Option 2: Local Script

Run the release script locally:

```bash
# Patch release (0.2.0 → 0.2.1)
python scripts/release.py patch

# Minor release (0.2.0 → 0.3.0)
python scripts/release.py minor

# Major release (0.2.0 → 1.0.0)
python scripts/release.py major

# Explicit version
python scripts/release.py 1.0.0

# Preview without making changes
python scripts/release.py patch --dry-run
```

The script will:

- Run the release preflight and refuse before changing anything if it fails
- Check release verification dependencies
- Prompt for confirmation
- Bump version in the plugin manifest `.claude-plugin/plugin.json` and plugin package `package.json`
- Generate the changelog entry, then run `make verify` before creating any branch
- Create a release branch and commit locally

Local preparation writes nothing to the remote. It reads `origin` to detect an existing release branch — including under `--dry-run`, which otherwise reports only the local steps it would take. Pushing is yours to do:

```bash
git push origin release/vX.Y.Z
gh pr create --base main --head release/vX.Y.Z
```

After the PR is merged, the tag and GitHub Release will be created automatically.

## Manual Release

If you prefer manual control:

### 1. Prepare

```bash
git checkout main
git pull
make test
```

### 2. Update Changelog (Optional)

Add the release's user-facing changes to `CHANGELOG.md` in Keep a Changelog format.

### 3. Create Release Branch

```bash
git checkout -b release/vX.Y.Z
```

### 4. Bump Version

Update the plugin manifest `.claude-plugin/plugin.json` and plugin package `package.json`:

```json
{
  "version": "X.Y.Z"
}
```

### 5. Commit and Push

```bash
git add .claude-plugin/plugin.json package.json CHANGELOG.md
git commit -m "Release vX.Y.Z"
git push origin release/vX.Y.Z
```

### 6. Create Pull Request

```bash
gh pr create --base main --head release/vX.Y.Z --title "Release vX.Y.Z"
```

### 7. After PR Merge

The tag and GitHub Release will be created automatically by the `release-tag.yml` workflow.

To create manually:

```bash
git checkout main
git pull
git tag vX.Y.Z
git push origin vX.Y.Z
gh release create vX.Y.Z --title "vX.Y.Z" --generate-notes
```

## After Release

Users update via:

```bash
claude /plugin marketplace update kramme-cc-workflow
```

Or for git installs:

```bash
claude /plugin install git+https://github.com/Abildtoft/kramme-cc-workflow
```
