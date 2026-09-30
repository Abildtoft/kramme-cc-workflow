"""Static path and content patterns for risk-signals.py.

Kept apart from the signal logic so the tables can grow without crowding it. Every
pattern is matched against changed paths or added lines; nothing here reads files.
"""

from __future__ import annotations

import re

LOCKFILES = frozenset(
    "Cargo.lock Gemfile.lock Package.resolved Pipfile.lock Podfile.lock bun.lock bun.lockb composer.lock deno.lock "
    "flake.lock go.sum gradle.lockfile mix.lock npm-shrinkwrap.json package-lock.json packages.lock.json pdm.lock "
    "pnpm-lock.yaml poetry.lock pubspec.lock uv.lock yarn.lock".split()
)
MANIFESTS = frozenset(
    "Cargo.toml Directory.Packages.props Gemfile Package.swift Pipfile Podfile build.gradle build.gradle.kts "
    "composer.json deno.json go.mod mix.exs package.json packages.config pom.xml pubspec.yaml pyproject.toml "
    "settings.gradle settings.gradle.kts setup.cfg setup.py".split()
)
MANIFEST_SUFFIXES = frozenset(".csproj .fsproj .gemspec .vbproj".split())
REQUIREMENTS_RE = re.compile(r"^requirements[\w.-]*\.(?:txt|in)$")

DOCS_SUFFIXES = frozenset(".adoc .asciidoc .markdown .md .mdx .rst".split())
DOCS_NAMES = frozenset("AUTHORS CHANGELOG CODE_OF_CONDUCT LICENSE LICENSE.txt NOTICE".split())
TEST_DIRS = frozenset("__mocks__ __tests__ cypress e2e spec specs test testdata tests".split())
TEST_FILE_RE = re.compile(
    r"\.(?:test|spec|cy)\.[a-z0-9]+$|_(?:test|spec)\.[a-z0-9]+$|^test_.+\.py$|^conftest\.py$|\.bats$"
)
# Matched against the original-case name: the class suffix is only recognizable by its capital letter.
TEST_CLASS_FILE_RE = re.compile(r"[a-z0-9](?:Test|Tests|Spec|IT)\.(?:java|kt|scala|cs|swift|groovy)$")
SOURCE_SUFFIXES = frozenset(
    ".astro .bash .c .cc .cjs .clj .cpp .cs .cts .cxx .dart .erl .ex .exs .fs .go .h .hpp .java .js .jsx .kt .kts "
    ".lua .m .mjs .mm .mts .php .ps1 .py .rb .rs .scala .sh .svelte .swift .ts .tsx .vue .zsh".split()
)

AUTH_WORDS = frozenset(
    "abac acl acls auth authenticate authentication authenticator authn authorization authorize authorizer authz "
    "cors credential credentials crypto cryptography csrf decrypt encrypt encryption iam jwks jwt login logout oauth "
    "oauth2 oidc passwd password passwords permission permissions rbac saml secret secrets security session sessions "
    "signin signup sso".split()
)
DATABASE_WORDS = frozenset("alembic flyway liquibase migrate migration migrations".split())
DATABASE_NAMES = frozenset("schema.prisma schema.rb structure.sql".split())
CI_PREFIXES = (".buildkite/", ".circleci/", ".github/actions/", ".github/workflows/", ".gitlab/")
CI_NAMES = frozenset(
    ".gitlab-ci.yml .travis.yml CODEOWNERS Jenkinsfile action.yaml action.yml azure-pipelines.yml "
    "bitbucket-pipelines.yml".split()
)
INFRA_WORDS = frozenset(
    "ansible cloudformation deploy deployment deployments helm infra infrastructure k8s kubernetes pulumi terraform".split()
)
INFRA_SUFFIXES = frozenset(".hcl .tf .tfvars".split())
INFRA_NAMES = frozenset(
    "compose.yaml compose.yml docker-compose.yaml docker-compose.yml fly.toml netlify.toml nginx.conf procfile "
    "serverless.yaml serverless.yml vercel.json".split()
)
SECRET_FILE_NAMES = frozenset(".htpasswd .netrc .npmrc .pypirc id_dsa id_ecdsa id_ed25519 id_rsa".split())
SECRET_FILE_SUFFIXES = frozenset(".jks .kdbx .key .keystore .p12 .pem .pfx".split())
ENV_EXAMPLE_SUFFIXES = (".dist", ".example", ".sample", ".template")
API_CONTRACT_SUFFIXES = frozenset(".avsc .gql .graphql .graphqls .proto .thrift .wsdl".split())

SECRET_PATTERNS = (
    ("private-key", re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----")),
    ("aws-access-key-id", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("github-token", re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{50,})")),
    ("slack-token", re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}")),
    ("stripe-live-key", re.compile(r"\b[rs]k_live_[A-Za-z0-9]{16,}")),
    ("google-api-key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}")),
    ("provider-api-key", re.compile(r"\bsk-(?:ant-|proj-)?[A-Za-z0-9_-]{32,}")),
)
SINK_PATTERNS = (
    ("eval", re.compile(r"(?<![.\w])eval\s*\(|\bnew\s+Function\s*\(")),
    ("exec", re.compile(r"(?<![.\w])exec\s*\(|\bos\.system\s*\(|\bchild_process\b|\bRuntime\.getRuntime\(\)\.exec\b")),
    ("shell", re.compile(r"\bshell\s*=\s*True\b")),
    ("raw-html", re.compile(r"dangerouslySetInnerHTML|\.(?:inner|outer)HTML\s*=(?!=)|\binsertAdjacentHTML\s*\(")),
    ("raw-html", re.compile(r"\bdocument\.write(?:ln)?\s*\(|\bv-html\s*=|\bbypassSecurityTrust\w*\s*\(")),
    ("deserialization", re.compile(r"\bpickle\.loads?\s*\(|\bunserialize\s*\(|\bMarshal\.load\b")),
)
DISABLED_TEST_PATTERNS = (
    (
        "skip",
        re.compile(r"\b(?:it|test|describe|context)\.(?:skip|todo)\s*\(|(?<![.\w])x(?:it|test|describe|context)\s*\("),
    ),
    (
        "skip",
        re.compile(r"@pytest\.mark\.skip(?:if)?\b|\bpytest\.skip\s*\(|@unittest\.skip\w*\b|\bself\.skipTest\s*\("),
    ),
    ("skip", re.compile(r"\bt\.Skip(?:Now|f)?\s*\(|@(?:Disabled|Ignore)\b|\btest\.fixme\s*\(|^\s*skip(?:\s|$)")),
    ("focus", re.compile(r"\b(?:it|test|describe|context)\.only\s*\(|(?<![.\w])f(?:it|describe)\s*\(")),
    ("expected-failure", re.compile(r"@pytest\.mark\.xfail\b|@unittest\.expectedFailure\b")),
)
