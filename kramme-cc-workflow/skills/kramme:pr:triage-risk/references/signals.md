# Risk Signals

`scripts/risk-signals.py` emits these signals. Each has a fixed level and says whether the model may discount it. The script reports paths, line numbers, and pattern names only; it never prints file content.

## File Kinds

Every changed file gets one kind, decided in this order:

1. `lockfile` — a known dependency lockfile such as `package-lock.json`, `yarn.lock`, `poetry.lock`, `uv.lock`, `go.sum`, or `Cargo.lock`.
2. `code` — a CI or repository-automation definition (see `path:ci`), whatever its name, so `ci_test.yml` cannot pass as a test.
3. `generated` — a policy `generated_paths` match. Generated-looking names such as `__generated__/`, `*.pb.go`, or `*.generated.*` do not count, because the branch author chooses them.
4. `code` — a dependency manifest such as `package.json`, `pyproject.toml`, `requirements*.txt`, or `go.mod`.
5. `docs` — Markdown, reStructuredText, AsciiDoc, or files such as `LICENSE` and `CHANGELOG`.
6. `test` — a path under a test directory (such as `test/`, `tests/`, `__tests__/`, `spec/`, `e2e/`, `cypress/`, `testdata/`, `__mocks__/`) or a test file name (such as `*.test.*`, `*.spec.*`, `*_test.*`, `test_*.py`, `conftest.py`, `*.bats`, `FooTest.java`).
7. `code` — everything else, including configuration.

The script diffs with `--text`, so a branch's `.gitattributes` cannot hide content as binary. Size signals count only `code` files that are not binary, except that a source file stays counted even when it contains a NUL byte. Renamed files are checked under both their old and new paths, each classified on its own, so moving a file out of a sensitive or policy-covered location, even into a test or docs directory, still raises the signal.

## Signals

| Signal | Level | Discountable | Raised when |
| --- | --- | --- | --- |
| `content:secret` | high | no | An added line in any file matches a high-confidence credential shape: a private-key block, an AWS access key ID, or a GitHub, Slack, Stripe live, Google, or provider API key. Evidence is `path:line (pattern)`. |
| `policy:changed` | high | no | The branch adds, edits, renames, or deletes `.github/pr-risk.json`. |
| `policy:invalid` | high | no | The policy file on the default branch is not a regular file, is not valid JSON, or fails the schema below. The script's `policy.error` says why. |
| `policy:high-path` | high | no | A changed path matches the policy's `high_risk_paths`. |
| `policy:medium-path` | medium | no | A changed path matches the policy's `medium_risk_paths`. |
| `path:auth` | high | yes | A `code` path contains a word such as `auth`, `login`, `session`, `permission`, `rbac`, `acl`, `oauth`, `jwt`, `password`, `credential`, `secret`, `crypto`, `csrf`, or `security`. CamelCase names are split, so `AuthService.ts` matches and `author.ts` does not. |
| `path:secrets-config` | high | yes | A `code` path is an environment file (`.env`, `.env.*` except `.example`, `.sample`, `.template`, or `.dist`), a key or keystore file (such as `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`), or a credential file such as `.npmrc`, `.pypirc`, `.netrc`, or `id_rsa`. |
| `path:database` | high | yes | A `code` path is a migration (`migration`, `migrations`, `migrate`, `alembic`, `flyway`, `liquibase`), a `*.sql` file, or a schema file such as `schema.prisma` or `schema.rb`. |
| `path:ci` | high | yes | A `code` path is a CI or repository-automation definition such as `.github/workflows/`, `.github/actions/`, `.circleci/`, `.buildkite/`, `.gitlab/`, `.gitlab-ci.yml`, `Jenkinsfile`, `action.yml`, or `CODEOWNERS`. |
| `path:infra` | high | yes | A `code` path is infrastructure or deployment: `terraform`, `infra`, `k8s`, `helm`, `ansible`, `pulumi`, `deploy`, `*.tf`, `Dockerfile`, `docker-compose.yml`, `fly.toml`, `vercel.json`, or similar. |
| `shape:very-large` | high | yes | More than 1000 code lines changed. |
| `path:dependencies` | medium | yes | Any dependency manifest, lockfile, or `.gitmodules` changed, or a submodule pointer moved, regardless of submodule ignore settings. |
| `path:api-contract` | medium | yes | A `code` path is an interface contract such as `*.proto`, `*.graphql`, `*.gql`, `*.avsc`, `*.thrift`, or an `openapi*` or `swagger*` JSON or YAML file. |
| `shape:large` | medium | yes | More than 400 code lines or more than 25 code files changed. |
| `shape:non-trivial` | medium | yes | More than 100 code lines or more than 10 code files changed. Only the largest `shape:` size signal is emitted. |
| `shape:deleted-source` | medium | yes | A source file (a `code` file with a programming-language extension) was deleted. |
| `shape:untested-source` | medium | yes | More than 20 lines changed across source files that still exist and the branch adds or edits no `test` file; deleting a test does not count. Evidence lists the source files. |
| `content:disabled-test` | medium | yes | An added line in a `test` file skips, focuses, or expects failure: `it.skip(`, `xit(`, `.only(`, `fit(`, `@pytest.mark.skip`, `@unittest.skip`, `t.Skip(`, `@Disabled`, a Bats `skip`, and similar. |
| `content:dangerous-sink` | medium | yes | An added line in a `code` file calls a dynamic-execution, shell, raw-HTML, or unsafe-deserialization sink: `eval(`, `new Function(`, `exec(`, `os.system(`, `child_process`, `shell=True`, `innerHTML =`, `dangerouslySetInnerHTML`, `v-html`, `bypassSecurityTrust*`, `pickle.load`, and similar. |

`floor` is the highest level among all signals. `hard_floor` is the highest level among non-discountable signals. Both are `low` when no signal applies.

## Repository Policy

A repository can declare its own risk paths in `.github/pr-risk.json`. The skill passes the repository's default branch as `--policy-rev`: `origin/HEAD`, or `origin/main` or `origin/master` when `origin/HEAD` is unset, so the policy is never read from the branch under triage or from its Pull Request base. The two risk-path lists only add signals; `generated_paths` is the only key that can remove a built-in signal, and only by reclassifying files the repository says are generated.

```json
{
  "version": 1,
  "high_risk_paths": ["src/billing/", "services/payments/*"],
  "medium_risk_paths": ["packages/shared/"],
  "generated_paths": ["src/api/client/*.ts"]
}
```

- `version` is required and must be `1`. Every other key is optional; an unknown key makes the policy invalid rather than silently ignored.
- Each list holds repository-relative patterns with `/` separators and without a leading `/`, `./`, or `../`; any of those forms, or a backslash, makes the policy invalid because it could never match. Patterns use shell-style matching in which `*` also matches `/`. A pattern ending in `/` matches everything below that directory.
- `high_risk_paths` and `medium_risk_paths` raise `policy:high-path` and `policy:medium-path` for any matching file of any kind.
- `generated_paths` marks matching files as `generated`, which removes them from size counts, built-in `code` path categories, and the dangerous-sink scan. It does not exempt them from content scans for secrets or from policy path matches, and it cannot reclassify CI definitions.
