# Release Process

This document describes how to release a new version of kramme-cc-workflow.

## Version Numbering

- **Patch** (0.2.0 → 0.2.1): Bug fixes, documentation updates, minor improvements
- **Minor** (0.2.0 → 0.3.0): New commands, agents, skills, or hooks
- **Major** (0.2.0 → 1.0.0): Breaking changes

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
- Bump version in `.claude-plugin/plugin.json` and `package.json`
- Create a release branch and commit
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
- Run tests
- Prompt for confirmation
- Bump version in `.claude-plugin/plugin.json` and `package.json`
- Create a release branch and commit

After running, push the branch and create a PR:
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

### 2. Generate Changelog (Optional)

Use the changelog-generator skill:
```
Create a changelog for commits since the last release tag
```

### 3. Create Release Branch

```bash
git checkout -b release/vX.Y.Z
```

### 4. Bump Version

Update `.claude-plugin/plugin.json` and `package.json`:
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
