# kramme-cc-workflow

Claude Code plugins providing workflow automation for daily development tasks. Developed for personal use and shared for inspiration.

## Plugins

| Plugin | Description |
|--------|-------------|
| [kramme-cc-workflow](kramme-cc-workflow/) | General workflow tooling — PR management, code review, commit hygiene, structured implementation, and more |
| [kramme-connect-workflow](kramme-connect-workflow/) | Skills for [Consensus ApS](https://consensus.dk)'s Connect product — Angular modernization, Nx library extraction, NgRx migration, and Rive documentation |

## Installation

```bash
# Install the main workflow plugin
claude /plugin install /path/to/kramme-cc-workflow/kramme-cc-workflow

# Install the Connect plugin (if working on Connect monorepo)
claude /plugin install /path/to/kramme-cc-workflow/kramme-connect-workflow
```

Marketplace install:

```bash
claude /plugin marketplace add Abildtoft/kramme-cc-workflow
claude /plugin install kramme-cc-workflow@kramme-cc-workflow
claude /plugin install kramme-cc-workflow@kramme-connect-workflow
```

## License

MIT
