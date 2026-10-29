# Plugin update notices come from a daily startup hook

- Status: ACCEPTED
- Date: 2026-10-28
- Deciders: repository maintainer (explicit implementation request)

## Context

Users had no way to learn that a new plugin version existed unless they checked themselves. Claude Code auto-updates plugins and shows `Plugin updated: <name> · Run /reload-plugins to apply`, but only for marketplaces with auto-update turned on. For third-party marketplaces such as this one it is off by default, and `marketplace.json` has no field to turn it on; only each user, under `/plugin` → Marketplaces, or an administrator's managed settings can. The maintainer's own machine had it off. Codex has no plugin auto-update; Git marketplace installs update with `codex plugin marketplace upgrade` and `codex plugin add`, while local/checkout installs, including `npx`, rerun their original install command.

The plugin manifest pins `version`, and only release Pull Requests bump it, so the manifest on `main` names exactly the version an update installs. Claude Code shows a synchronous hook's `systemMessage` to the user, adds plain `SessionStart` stdout and `additionalContext` to the model's context, delivers a background (`async`) hook's `systemMessage` to the model instead of the user, and makes the session's first response wait for `SessionStart` hooks. Codex supports `SessionStart` with the same `startup` matcher and shows `systemMessage` as a warning.

## Decision

Ship an `update-check` hook on `SessionStart` with the `startup` matcher. At most once a day it fetches the manifest from `main` with a two-second `curl` limit and, when the release is newer than the installed copy, shows a one-line `systemMessage` with the host's update commands. The first session on a newer installed version also names the previous and new versions once, with the count of changelog entries marked breaking between them, without using the network. Its only output is a JSON `systemMessage`. It keeps its state in the XDG state directory, uses a nonblocking Python file lock across each read/check/write so concurrent startups cannot duplicate checks or regress the seen version, supports the hook toggle, skips the fetch when `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` is set, and fails open.

`/kramme:setup` stays read-only and never fetches: it reports the local-file `/plugin` auto-update policy, resolving the managed settings file, session-directory shared settings, main-checkout local settings (where the host uses them), and user settings before falling back to the `known_marketplaces.json` record. Unreadable files or managed drop-in fragments report unknown, and the result directs users to `/plugin` to confirm session policy because session flags, remote or OS-managed policy, and workspace trust are not inspected. It also reports the hook's last recorded release. The README tells Claude Code users to turn on auto-update when they install.

## Alternatives and consequences

- **Documentation only.** Asking users to turn on auto-update, or to watch GitHub releases, costs nothing but reaches only people who read the docs, and does nothing on Codex. It is kept as the first recommendation, not the only one.
- **Background hook or detached refresh.** An `async` hook would never block, but its message would reach the model rather than the user. A fully detached process that refreshes a cache for the next session avoids the wait, but it delays every notice by a session and must release the hook's output pipe, or the host keeps waiting for it; a bounded daily fetch is simpler.
- **Model-context notice.** Printing the notice as plain stdout or `additionalContext` would spend context on every session and invite the model to act on it.
- **GitHub Releases API or `git ls-remote`.** The Releases API is rate-limited for unauthenticated clients and returns a larger payload; `ls-remote` is slower and needs Git network access. Neither knows more than the manifest that updates actually read.
- **Fetching from `/kramme:setup`.** It would break the checker's no-fetch contract and runs too rarely to inform anyone.
- **Updating from the hook.** Both hosts own their plugin caches and install records, so the hook only reports.

This is the first hook that uses the network: GitHub receives one request a day per machine, carrying no identifiers beyond the IP address and curl's user agent. The notice appears only in the session that ran that day's check, so a check that runs in a non-interactive session can go unseen until the next day. Agent SDK clients can receive the message as an informational event and may not display it. Codex users must review and trust the new hook before it runs. The hook reaches users only from the release that ships it; earlier installs learn about it the next time they update by hand.
