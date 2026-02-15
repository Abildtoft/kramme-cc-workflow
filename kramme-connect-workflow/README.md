# kramme-connect-workflow

A Claude Code plugin for [Consensus ApS](https://consensus.dk)'s **Connect** product monorepo. Provides skills for Angular modernization, Nx library extraction, NgRx migration, Rive integration, and feature documentation.

## Skills

### User-Invocable Skills

| Skill | Description |
|-------|-------------|
| `/kramme:connect-existing-feature-documentation-writer` | Create or update documentation for Connect features |
| `/kramme:connect-extract-to-nx-libraries` | Extract app code from `apps/connect/` into proper Nx libraries |
| `/kramme:connect-migrate-legacy-store-to-ngrx-component-store` | Migrate legacy CustomStore/FeatureStore to NgRx ComponentStore in Connect monorepo |
| `/kramme:connect-modernize-legacy-angular-component` | Modernize legacy Angular components in Connect monorepo |

### Background Skills

Auto-triggered by Claude based on context. These don't appear in the `/` menu.

| Skill | Trigger Condition |
|-------|-------------------|
| `kramme:connect:rive` | Official Rive documentation covering editor, scripting, runtimes, data binding, and feature support (iOS/mobile focus) |

## Installation

```bash
claude /plugin install /path/to/kramme-connect-workflow
```

## Attribution

- `kramme:connect:rive`: Inspired by [Lonka-Pardhu/rive-agent-skill](https://github.com/Lonka-Pardhu/rive-agent-skill).

## License

MIT
