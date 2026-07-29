                                                                                                                 GitHub - nicobailon/visual-explainer: Agent skill that generates rich HTML pages or slide decks for diagrams, diff reviews, plan audits, data tables, and project recaps · GitHub

 [Sign in](/login?return_to=https%3A%2F%2Fgithub.com%2Fnicobailon%2Fvisual-explainer)  [Sign up](/signup?ref_cta=Sign+up&ref_loc=header+logged+out&ref_page=%2F%3Cuser-name%3E%2F%3Crepo-name%3E&source=header-repo&source_repo=nicobailon%2Fvisual-explainer)

  Appearance settings

  You signed in with another tab or window. Reload to refresh your session. You signed out in another tab or window. Reload to refresh your session. You switched accounts on another tab or window. Reload to refresh your session. Dismiss alert

{{ message }}

  [/nicobailon/visual-explainer](/nicobailon/visual-explainer)

[Branches](/nicobailon/visual-explainer/branches)[Tags](/nicobailon/visual-explainer/tags)

[/nicobailon/visual-explainer/branches](/nicobailon/visual-explainer/branches)[/nicobailon/visual-explainer/tags](/nicobailon/visual-explainer/tags)

Open more actions menu

## Folders and files

| Name | Name |

Last commit message |

Last commit date  |

|

## Latest commit

## History
[43 Commits](/nicobailon/visual-explainer/commits/main/)

[/nicobailon/visual-explainer/commits/main/](/nicobailon/visual-explainer/commits/main/)43 Commits  |

|

[.claude-plugin](/nicobailon/visual-explainer/tree/main/.claude-plugin) |

[.claude-plugin](/nicobailon/visual-explainer/tree/main/.claude-plugin) |

  |

   |

|

[configs](/nicobailon/visual-explainer/tree/main/configs) |

[configs](/nicobailon/visual-explainer/tree/main/configs) |

  |

   |

|

[plugins/visual-explainer](/nicobailon/visual-explainer/tree/main/plugins/visual-explainer) |

[plugins/visual-explainer](/nicobailon/visual-explainer/tree/main/plugins/visual-explainer) |

  |

   |

|

[.gitignore](/nicobailon/visual-explainer/blob/main/.gitignore) |

[.gitignore](/nicobailon/visual-explainer/blob/main/.gitignore) |

  |

   |

|

[CHANGELOG.md](/nicobailon/visual-explainer/blob/main/CHANGELOG.md) |

[CHANGELOG.md](/nicobailon/visual-explainer/blob/main/CHANGELOG.md) |

  |

   |

|

[LICENSE](/nicobailon/visual-explainer/blob/main/LICENSE) |

[LICENSE](/nicobailon/visual-explainer/blob/main/LICENSE) |

  |

   |

|

[README.md](/nicobailon/visual-explainer/blob/main/README.md) |

[README.md](/nicobailon/visual-explainer/blob/main/README.md) |

  |

   |

|

[banner.png](/nicobailon/visual-explainer/blob/main/banner.png) |

[banner.png](/nicobailon/visual-explainer/blob/main/banner.png) |

  |

   |

|

[install-pi.sh](/nicobailon/visual-explainer/blob/main/install-pi.sh) |

[install-pi.sh](/nicobailon/visual-explainer/blob/main/install-pi.sh) |

  |

   |

|

[package.json](/nicobailon/visual-explainer/blob/main/package.json) |

[package.json](/nicobailon/visual-explainer/blob/main/package.json) |

  |

   |

|

  |

## Repository files navigation

 [[image: visual-explainer]](/nicobailon/visual-explainer/blob/main/banner.png)

# visual-explainer
[#visual-explainer](#visual-explainer)

An agent skill that turns complex terminal output into styled HTML pages you actually want to read.

[[image: License: MIT]](/nicobailon/visual-explainer/blob/main/LICENSE)

Ask your agent to explain a system architecture, review a diff, or compare requirements against a plan. Instead of ASCII art and box-drawing tables, it generates a self-contained HTML page and opens it in your browser.

```
> draw a diagram of our authentication flow
> /diff-review
> /plan-review ~/docs/refactor-plan.md

```
    visual-explainer.mp4

## Why
[#why](#why)

Every coding agent defaults to ASCII art when you ask for a diagram. Box-drawing characters, monospace alignment hacks, text arrows. It works for trivial cases, but anything beyond a 3-box flowchart turns into an unreadable mess.

Tables are worse. Ask the agent to compare 15 requirements against a plan and you get a wall of pipes and dashes that wraps and breaks in the terminal. The data is there but it's painful to read.

This skill fixes that. Real typography, dark/light themes, interactive Mermaid diagrams with zoom and pan. No build step, no dependencies beyond a browser.

## Install
[#install](#install)

 | Harness  | Support  | Install path / behavior   |

 | Claude Code  | Marketplace plugin  | Preserved marketplace shape with source at `plugins/visual-explainer/`   |

 | Pi  | Package metadata plus installer  | `package.json` advertises the skill, prompts, and native `visual_explainer` tool with `prepare` and `render` actions; `install-pi.sh` installs copied skill/prompt resources for legacy manual installs   |

 | Codex CLI  | Native skill path plus optional prompts  | Copy to `~/.codex/skills/visual-explainer`; optional prompts go in `~/.codex/prompts/` if your Codex build supports them   |

 | OpenCode/opencode  | Observed skill/command paths  | Copy to `~/.config/opencode/skill/visual-explainer`; optional commands go in `~/.config/opencode/command/`   |

 | Cursor  | Rules-based guidance  | Add the supplied `.mdc` rule; Cursor is not treated as native Agent Skills support   |

 | OpenClaw  | Lightweight AGENTS/rules guidance  | Use the supplied AGENTS guidance with the canonical skill directory   |

Claude Code (marketplace):

```
/plugin marketplace add nicobailon/visual-explainer
/plugin install visual-explainer@visual-explainer-marketplace
```

Note: Claude Code plugins namespace commands as `/visual-explainer:command-name`.

Pi:

```
pi install git:github.com/nicobailon/visual-explainer
```

Or from a local checkout:

```
git clone --depth 1 https://github.com/nicobailon/visual-explainer.git
pi install ./visual-explainer
```

The package manifest advertises the canonical skill, command templates, and Pi tool:

```
"pi": {
  "extensions": ["./plugins/visual-explainer/extension.ts"],
  "skills": ["./plugins/visual-explainer"],
  "prompts": ["./plugins/visual-explainer/commands"]
}
```

The Pi extension registers one native `visual_explainer` tool. Use `action: "prepare"` to plan a visual explanation after generating or reviewing a substantial plan, architecture, diff, or implementation, and `action: "render"` to write complete HTML pages to `~/.agent/diagrams/`. `/generate-web-diagram` remains the bundled prompt template command.

If you previously used the old curl/manual installer, remove those copied files before using `pi install`; otherwise Pi will report skill and prompt conflicts because the user-level copies shadow the package resources:

```
rm -rf ~/.pi/agent/skills/visual-explainer
rm -f ~/.pi/agent/prompts/{diff-review,fact-check,generate-slides,generate-visual-plan,generate-web-diagram,plan-review,project-recap}.md
rm -f ~/.pi/agent/prompts/s[h]are*.md
```

The legacy installer still works if you prefer copied skill and prompt files over package management, but it does not install the native Pi tool:

```
curl -fsSL https://raw.githubusercontent.com/nicobailon/visual-explainer/main/install-pi.sh | bash
```

Codex CLI:

```
git clone --depth 1 https://github.com/nicobailon/visual-explainer.git /tmp/visual-explainer

mkdir -p ~/.codex/skills ~/.codex/prompts
cp -R /tmp/visual-explainer/plugins/visual-explainer ~/.codex/skills/visual-explainer

# Optional, only if your Codex build supports prompt templates:
cp /tmp/visual-explainer/plugins/visual-explainer/commands/*.md ~/.codex/prompts/

rm -rf /tmp/visual-explainer
```

Invoke with `$visual-explainer` or ask Codex to use the `visual-explainer` skill. If prompts are installed and supported, use `/prompts:diff-review`, `/prompts:plan-review`, etc.

OpenCode/opencode:

```
git clone --depth 1 https://github.com/nicobailon/visual-explainer.git /tmp/visual-explainer

mkdir -p ~/.config/opencode/skill ~/.config/opencode/command
cp -R /tmp/visual-explainer/plugins/visual-explainer ~/.config/opencode/skill/visual-explainer

# Optional command templates:
cp /tmp/visual-explainer/plugins/visual-explainer/commands/*.md ~/.config/opencode/command/

rm -rf /tmp/visual-explainer
```

Activate it by asking OpenCode to use the `visual-explainer` skill. Command-template behavior depends on the installed OpenCode/opencode build.

Cursor:

Add `configs/cursor/visual-explainer.mdc` to your Cursor rules, or copy its contents into the project rules UI. This is rules-based guidance that points Cursor at the canonical skill; it does not claim native Agent Skills support.

OpenClaw:

Use `configs/openclaw/AGENTS.md` as lightweight project guidance and copy or reference `plugins/visual-explainer/` as the canonical skill source. No native OpenClaw plugin adapter is included.

## Commands
[#commands](#commands)

 | Command  | What it does   |

 | `/generate-web-diagram`  | Generate an HTML diagram for any topic   |

 | `/generate-visual-plan`  | Generate a visual implementation plan for a feature or extension   |

 | `/generate-slides`  | Generate a magazine-quality slide deck   |

 | `/diff-review`  | Visual diff review with architecture comparison and code review   |

 | `/plan-review`  | Compare a plan against the codebase with risk assessment   |

 | `/project-recap`  | Mental model snapshot for context-switching back to a project   |

 | `/fact-check`  | Verify accuracy of a document against actual code   |

The agent also kicks in automatically when it's about to dump a complex table in the terminal (4+ rows or 3+ columns) — it renders HTML instead.

## Slide Deck Mode
[#slide-deck-mode](#slide-deck-mode)

Any command that produces a scrollable page supports `--slides` to generate a slide deck instead:

```
/diff-review --slides
/project-recap --slides 2w

```
    visual-explainer-slides.mp4

## How It Works
[#how-it-works](#how-it-works)

```
.claude-plugin/
├── plugin.json           ← marketplace identity
└── marketplace.json      ← plugin catalog
plugins/
└── visual-explainer/
    ├── .claude-plugin/
    │   └── plugin.json   ← plugin manifest
    ├── SKILL.md           ← workflow + design principles
    ├── extension.ts       ← Pi native tool
    ├── commands/          ← slash commands
    ├── references/        ← agent reads before generating
    │   ├── css-patterns.md   (layouts, animations, theming)
    │   ├── libraries.md      (Mermaid, Chart.js, fonts)
    │   ├── responsive-nav.md (sticky TOC for multi-section pages)
    │   └── slide-patterns.md (slide engine, transitions, presets)
    └── templates/         ← reference templates with different palettes
        ├── architecture.html
        ├── mermaid-flowchart.html
        ├── data-table.html
        └── slide-deck.html

```

Output: `~/.agent/diagrams/filename.html` → opens in browser. In Pi package installs, agents can offer `visual_explainer` with `action: "prepare"` after generating or reviewing a substantial plan, architecture, diff, or implementation when a visual explanation would help, then call it with `action: "render"` as the final write/open step.

The skill routes to the right approach automatically: Mermaid for flowcharts and diagrams, CSS Grid for architecture overviews, HTML tables for data, Chart.js for dashboards.

## Limitations
[#limitations](#limitations)

- Generated HTML is portable and self-contained, but auto-opening depends on the harness, browser access, and sandbox rules.
- All harnesses write visual output to `~/.agent/diagrams/` unless the user asks for a different path.
- Switching OS theme requires a page refresh for Mermaid SVGs.
- Results vary by model capability.

## Credits
[#credits](#credits)

Borrows ideas from [Anthropic's frontend-design skill](https://github.com/anthropics/skills) and [interface-design](https://github.com/Dammyjay93/interface-design).

## License
[#license](#license)

MIT

## About

Agent skill that generates rich HTML pages or slide decks for diagrams, diff reviews, plan audits, data tables, and project recaps

### Resources

[Readme](#readme-ov-file)

[MIT license](#MIT-1-ov-file)

[Activity](/nicobailon/visual-explainer/activity)

### Stars

[9.4k stars](/nicobailon/visual-explainer/stargazers)

### Watchers

[42 watching](/nicobailon/visual-explainer/watchers)

### Forks

[630 forks](/nicobailon/visual-explainer/forks)

[Report repository](/contact/report-content?content_url=https%3A%2F%2Fgithub.com%2Fnicobailon%2Fvisual-explainer&report=nicobailon+%28user%29)

## Releases

## Packages

## Contributors

## Languages

   You can’t perform that action at this time.
