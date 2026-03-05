# Package Manager Commands Reference

Per-ecosystem detection, outdated check, and security audit commands.

---

## npm

**Detection:** `package-lock.json`, `package.json`
**Outdated:** `npm outdated --json`
**Audit:** `npm audit --json`
**JSON parsing:** Both output valid JSON. `npm outdated` returns object keyed by package name with `current`, `wanted`, `latest`. `npm audit` returns `vulnerabilities` object.
**Monorepo:** npm workspaces — add `--workspaces` flag. Check `package.json` for `workspaces` field.

## yarn (Classic v1)

**Detection:** `yarn.lock` (check for `__metadata` — absent means v1)
**Outdated:** `yarn outdated --json` (outputs NDJSON, one JSON object per line)
**Audit:** `yarn audit --json`
**Monorepo:** `yarn workspaces info --json`

## yarn (Berry v2+)

**Detection:** `yarn.lock` with `__metadata`, `.yarnrc.yml`
**Outdated:** `yarn outdated` (no `--json` in Berry, parse table output)
**Audit:** `yarn npm audit --json`
**Monorepo:** Check `.yarnrc.yml` for workspace configuration.

## pnpm

**Detection:** `pnpm-lock.yaml`
**Outdated:** `pnpm outdated --json`
**Audit:** `pnpm audit --json`
**Monorepo:** `pnpm-workspace.yaml` defines workspace packages. Add `--recursive` or `-r` for workspace-wide commands.

## pip / pipenv / poetry

**Detection:** `requirements.txt` / `Pipfile` / `pyproject.toml` with `[tool.poetry]`
**Outdated:** `pip list --outdated --format=json`
**Audit:** `pip-audit --json` (install: `pip install pip-audit`)
**Note:** `pip-audit` may not be installed. Check with `pip-audit --version`. If missing, suggest: `pip install pip-audit`.
**Poetry:** `poetry show --outdated` (no JSON flag, parse table)

## cargo (Rust)

**Detection:** `Cargo.toml`, `Cargo.lock`
**Outdated:** `cargo outdated` (install: `cargo install cargo-outdated`)
**Audit:** `cargo audit` (install: `cargo install cargo-audit`)
**Note:** Neither may be installed. Check with `which cargo-outdated` and `which cargo-audit`.

## go

**Detection:** `go.mod`, `go.sum`
**Outdated:** `go list -m -u all` (shows `[v1.2.3]` after modules with updates)
**Audit:** `govulncheck ./...` (install: `go install golang.org/x/vuln/cmd/govulncheck@latest`)
**Note:** `govulncheck` may not be installed. Suggest install if missing.

## dotnet

**Detection:** `*.csproj`, `*.sln`, `global.json`
**Outdated:** `dotnet list package --outdated`
**Audit:** `dotnet list package --vulnerable`
**Note:** Both commands output formatted text, not JSON. Parse table rows.
**Monorepo:** Run from solution directory or specify `--project`.
