# Dependency Audit Report

**Date:** {date}
**Package Manager:** {manager}
**Project:** {project_name}

## Summary

| Metric | Count |
|---|---|
| Total dependencies | {total} ({direct} direct, {transitive} transitive) |
| Security vulnerabilities | {vuln_total} |
| Outdated packages | {outdated_total} |

## Security Vulnerabilities

| Severity | Package | Current | Fixed In | CVE | Description |
|---|---|---|---|---|---|
| {Critical/High/Medium/Low} | {name} | {current} | {fixed} | {CVE-ID} | {brief description} |

## Upgrade Plan

### Phase 1: Immediate — Security Fixes

| Package | Current → Target | Risk | Action |
|---|---|---|---|
| {name} | {current} → {target} | Critical | Update immediately |

### Phase 2: Quick Wins — Patches and Low-Risk Minors

| Package | Current → Target | Risk | Action |
|---|---|---|---|
| {name} | {current} → {target} | Low | Update and test |

### Phase 3: Planned — Grouped Minor Updates

| Group | Packages | Current → Target | Risk |
|---|---|---|---|
| {group name} | {package list} | {range} | Medium |

### Phase 4: Major Upgrades — Migration Campaigns

| Group | Packages | Current → Target | Risk | Notes |
|---|---|---|---|---|
| {group name} | {package list} | {range} | High | {breaking changes summary} |

## Risk Assessment

| Package Group | Risk Level | Breaking Likelihood | Codebase Impact | Test Coverage |
|---|---|---|---|---|
| {group} | {Low/Medium/High/Critical} | {score} | {score} | {score} |

## Staleness Report

| Package | Current Version | Latest | Versions Behind | Last Updated |
|---|---|---|---|---|
| {name} | {current} | {latest} | {count} | {date} |

## Recommendations

1. {Priority recommendation}
2. {Secondary recommendation}
3. {Long-term recommendation}
