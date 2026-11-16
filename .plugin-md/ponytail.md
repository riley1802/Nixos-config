# Ponytail in Cursor

Ponytail is installed for this user as the Cursor plugin `ponytail@ponytail` (version 5.3.3) from <https://github.com/DietrichGebert/ponytail>. This guide follows the cached checkout `96608e078b2d5ea607c5c3b8b5a54d1c1fba6846`. That commit is also the GitHub repo HEAD, and the skill files, `commands/*.toml`, `INSTALL.md`, `docs/cursor-hooks.md`, and `.cursor/rules/ponytail.mdc` match.

## What it does

Ponytail makes the agent write the smallest change that fully solves the task. Before it adds code it stops at the first rung that works: skip what nobody asked for, reuse something already in the repo, use the standard library or a platform feature, use a dependency that is already installed, or do it in one line. Only then does it write the minimum that works.

It still finishes every part the task needs, including callers and tests the change breaks. It keeps validation at trust boundaries, error handling that prevents data loss, security, accessibility, hardware calibration, and anything you asked for. New non-trivial logic gets one small test. A deliberate shortcut is marked `shortcut: <the limit>, <when to upgrade>`. The reply ends with what was skipped and any risk you should know.

## How a chat picks it up

Open a new chat after the plugin is installed. A chat that was already open does not load a plugin that arrived mid-conversation.

The checkout has three ways Cursor can carry Ponytail. On this machine the marketplace plugin is the one that is active. There is no `~/.cursor/hooks.json`. This workspace has no `.cursor/rules/ponytail.mdc`. `/etc/nixos/.cursor/hooks.json` has no Ponytail entries.

### Skills

The plugin exposes six skills from `skills/`. Cursor attaches a skill when you send its slash command. The `ponytail` skill also asks the agent to read it on any coding task, and when you say "ponytail", "be lazy", "simplest solution", "yagni", or complain about over-engineering. Once read, that level lasts until you change it or the chat ends.

`/ponytail lite`, `/ponytail full`, and `/ponytail ultra` set the level. `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, and `/ponytail-help` are one-shot. They report and leave the level alone.

### Always-on rule

`.cursor/rules/ponytail.mdc` in the plugin has `alwaysApply: true`. Copy that file into a workspace's `.cursor/rules/` to put the compact ruleset on every prompt. The copy has no lite, ultra, or off switch. It is the fixed smallest-change behavior.

While `<workspace>/.cursor/rules/ponytail.mdc` exists, the hooks inject a notice instead of the ruleset and leave the mode flag alone. `/ponytail`, `stop ponytail`, and `normal mode` answer with that notice and change nothing. Delete the rule to let the hooks manage the level. The notice starts with `PONYTAIL: the always-on Cursor rule`.

### Hooks

Hooks are a separate install from the marketplace plugin. From the checkout:

```bash
node scripts/cursor-hooks.js install
```

That merges two hooks into `~/.cursor/hooks.json` and keeps any other hooks. Add `--project` to write `<project>/.cursor/hooks.json` for one project. The commands run `node` against that checkout, so leave the checkout where it is. `node` has to be on the PATH that Cursor's hooks see, including the non-interactive shell. Cursor reloads `hooks.json` on save. Open a new chat afterward.

`sessionStart` sets the live mode to the default level and stores `PONYTAIL MODE ACTIVE — level: <level>` plus that level's ruleset on the conversation. A new chat starts at the default. `beforeSubmitPrompt` watches later messages. Send the level as a plain message. `/ponytail` with no level reports the current level. A level change arrives as `PONYTAIL MODE CHANGED — level: <level>` plus that level's ruleset.

With the skills installed, Cursor can also attach the skill text when you send `/ponytail lite` (and the same for `full`, `ultra`, and `off`). The hook still receives the literal message and is what records the level. A copy of the skills under `~/.cursor/skills` behaves the same way.

`@ponytail` opens Cursor's context picker. Send `/ponytail`.

## Levels

Default is **full**.

| Level | Send this | What you get |
| --- | --- | --- |
| Lite | `/ponytail lite` | Builds what you asked. Names the smaller option in one line and lets you pick. |
| Full | `/ponytail` or `/ponytail full` | The smallest complete change, a check where the logic needs one, and a reply that names skipped work and any risk. Default. |
| Ultra | `/ponytail ultra` | Same as full, and it questions the request and pushes back before building. |
| Off | `/ponytail off` | Turns Ponytail off. `stop ponytail` or `normal mode`, as the whole message, does the same. |

`/ponytail` with no level turns it on at the default when it was off. When the default itself is `off`, the hook turns it on at `full`. When it is already on, `/ponytail` reports the current level.

With only the skills, the level lasts until you change it or the chat ends. With hooks, each new chat starts at the default again. A switch lasts for that conversation. Chats in the same project share the mode flag in `~/.cursor/ponytail-modes/`. A new chat's `sessionStart` sets that flag back to the default. Compaction of the same chat keeps the live level.

### Change the default

Resolution order: `PONYTAIL_DEFAULT_MODE`, then `~/.config/ponytail/config.json`, then `full`.

```bash
export PONYTAIL_DEFAULT_MODE=ultra
```

```json
{ "defaultMode": "lite" }
```

`defaultMode` may be `off`, `lite`, `full`, or `ultra`. `off` means a new hook session does not auto-activate. Send `/ponytail` when you want it. With hooks installed, `/ponytail default lite` (or `full`, `ultra`, `off`) writes that value into `config.json` and leaves the current chat's level as it is. The hook replies `PONYTAIL DEFAULT SET — new sessions start in <level>`.

## Commands and skills

| Command | When to use it | What it changes |
| --- | --- | --- |
| `/ponytail` | You want lazy mode, or a different intensity. Optional argument: `lite`, `full`, `ultra`, `off`. | Sets or reports the level for the rest of the session. Hooks also update the project mode flag. It does not edit the repo. |
| `/ponytail-help` | You want the short reference card. | Nothing. One-shot. It does not switch mode or write a flag. |
| `/ponytail-review` | You want a quality review of a change. Name uncommitted or staged changes, a branch, a PR link, or files. With nothing named, it reviews uncommitted changes, or the last commit if the tree is clean. | Nothing in the repo. A report: what the change does, then numbered findings (Must fix, Should fix, Nice to have), then a verdict. It reads the callers and the surrounding code, not only the diff. |
| `/ponytail-audit` | You want that same review for a whole repo, or for a folder you name. | Nothing in the repo. A ranked report, at most 20 findings, plus the parts it did not read. |
| `/ponytail-debt` | You want every `shortcut:` comment, and older `ponytail:` comments, listed. Add a marker word to search for that instead, for example `/ponytail-debt TODO`. | Nothing unless you ask it to save the ledger. Then it can write a file such as `PONYTAIL-DEBT.md`. |
| `/ponytail-gain` | You want the published benchmark scoreboard. | Nothing. The figures are Ponytail 5 on 39 tasks (lines of code 47% of baseline, output tokens 55%, cost 74%, time 59%), not savings in the repo you have open. For this repo, use `/ponytail-debt` and `/ponytail-audit`. |

`/ponytail band` belongs to Claude Code. In Cursor the hook treats `band` as an unknown argument and does not show a band.

## Cursor limits

Subagents do not receive the ruleset. Cursor's `subagentStart` hook can only allow or deny, and `PONYTAIL_SUBAGENT_MATCHER` has no effect here. Put any Ponytail instructions in the subagent's task when that work should follow them.

Cloud agents do not run `sessionStart`, so there is no startup injection. A project-level `beforeSubmitPrompt` hook still runs, so `/ponytail lite` (or `full`, `ultra`, `off`) sets the level for the rest of that cloud conversation.

While `.cursor/rules/ponytail.mdc` is in the workspace, that rule replaces hook injection. The hooks send the notice and do not apply lite, ultra, or off.

`sessionStart` is fire-and-forget. A message sent in the first fraction of a second of a new chat can leave before the hook context is attached.

On Linux the hook is a short `node` process. When `node` is missing from the hook PATH, the skills still work and each hook call reports `node: command not found`.

## Turn it off

Send one of these as the whole message:

- `/ponytail off`
- `stop ponytail`
- `normal mode`

Resume with `/ponytail`.

With hooks, that turn receives `PONYTAIL MODE OFF` and the mode flag is removed. The ruleset from `sessionStart` stays in that conversation. The off notice tells the model to stop applying it. A new chat follows the default again.

The always-on rule ignores these messages. Delete `.cursor/rules/ponytail.mdc` from the workspace.

To keep new hook sessions from turning Ponytail on, set `PONYTAIL_DEFAULT_MODE=off` or `"defaultMode": "off"` in `~/.config/ponytail/config.json`.

## Uninstall the Cursor hooks

From the checkout:

```bash
node scripts/cursor-hooks.js uninstall
```

On this machine the checkout is:

`/home/rileyt/.cursor/plugins/cache/ponytail/ponytail/96608e078b2d5ea607c5c3b8b5a54d1c1fba6846`

Add `--project` when the install wrote `<project>/.cursor/hooks.json`. Uninstall removes only Ponytail's entries (commands that run `hooks/ponytail-*.js`). It deletes `hooks.json` when nothing else was in it. A malformed `hooks.json` is left untouched.

`node scripts/uninstall.js` from the same checkout also removes leftover state: `~/.cursor/.ponytail-active`, `~/.cursor/ponytail-modes/`, `~/.config/ponytail/config.json`, and Ponytail's entries in `~/.cursor/hooks.json`. Run it while the checkout is still on disk. It only edits the user hooks file. A project install still needs `uninstall --project`.

The checkout does not document a Cursor marketplace remove command. Removing the plugin in Cursor is separate from the hook commands above. Deleting a copied `.cursor/rules/ponytail.mdc` removes the always-on rule.
