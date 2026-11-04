---
name: "service-finder"
description: "Finds the best-fit tool, service, or self-hosted project for an idea or problem: short interview, deep verified search, ranked shortlist. Use for \"I want X\", \"what should I use for Z\", \"alternatives to...\"."
---

# Service Finder

Turn a vague idea ("I want an always-on AI agent harness") into a verified, ranked shortlist of existing services, tools, or projects that fit, or an honest statement that nothing fits.

The failure to avoid: naming whatever comes to mind first. Training knowledge is stale for fast-moving categories, and a plausible-sounding suggestion that fails one stated constraint wastes the user's time. Everything recommended must be found and checked in this session.

## Phase 1: Intake (before any searching)

Run short multiple-choice rounds with AskUserQuestion: 2-4 questions per round, 2-4 options each. Repeat rounds until you could write the requirements without guessing. The user can always type a custom answer, so options only need to cover the likely cases.

Pin down:
- **The job**: what should this do for them, in one sentence? What would "it works" look like?
- **Hard vs nice-to-have**: which requirements are dealbreakers and which are preferences?
- **Where it runs**: which machine, OS, how it's reached (local only, over Tailscale, public)?
- **Integrations**: what it must talk to (local LLM servers, n8n, Home Assistant, databases, messaging apps)?
- **Scale and effort**: one user or many? How much setup/maintenance is acceptable?
- **Already tried or ruled out**: so you don't re-recommend those.

Skip any question the original request already answers. Don't ask about things you can decide sensibly yourself.

### Default constraints

Assume these unless the user overrides them, and say so in the spec so they can correct you:
1. **Self-hosted / local-first**: runs on the user's own hardware; cloud-only SaaS is out unless asked for.
2. **Free or open-source**: no paid-only products. A free tier counts only if it's genuinely usable.
3. **Runs on NixOS/Linux**: look for a nixpkgs package or NixOS module, a flake, or a Docker/OCI image that runs cleanly on Linux. Only Linux install paths matter; don't mention Windows/macOS.
4. **Actively maintained**: meaningful commits or releases within roughly the last 6 months.

### Confirm the spec

Before searching, write a short spec: one-sentence job, hard requirements, nice-to-haves, defaults applied, depth. Get a quick confirmation (AskUserQuestion with "Looks right / Adjust"). A wrong spec makes the deep search worthless, so this check is cheap insurance.

Then tell the user a rough time estimate in chat ("about 15 min") and start. Keep that estimate out of the final report: it is a forecast, and a report line stating a search time would be a guess unless you measured it.

## Phase 2: Deep search

Default depth is deep. If the user asked for a quick look, scale down accordingly.

Cast a wide net first, then narrow:
- **Vary the vocabulary.** Search the category by several names, the problem in plain words, and "alternative to <known tool>" for the obvious incumbents. Naming differs across communities, and the best fit often uses different words than the user did.
- **Hit multiple source types.** GitHub (search, topics, trending), curated awesome-lists, Hugging Face (models/spaces, when relevant), r/selfhosted and r/LocalLLaMA, Hacker News, official docs and changelogs, search.nixos.org for packaging, Docker Hub/GHCR for images.
- **Parallelize.** If subagents are available, fan out one per angle (e.g., incumbents, newcomers, awesome-lists, community discussion) and merge. Otherwise run independent searches in the same turn.
- **Look for the new and obscure**, not just the famous. Ask of each result: what else does this page mention, and what do people say replaced it?

Build a longlist (aim for 10-20 raw candidates), then verify the survivors.

### Verify each finalist against primary sources

Open the repo or docs themselves, not just a blog post that mentions them. Record:
- Last commit / latest release date, and release cadence
- License
- What it actually does, per its README or docs (separate real features from marketing and roadmap promises)
- Install path on NixOS/Linux (nixpkgs attr, flake, container image, or manual build)
- Hardware or dependency needs that could be dealbreakers (GPU, RAM, required cloud API keys)
- Known problems: open issues that matter, abandonment signs, "looking for maintainers"

Label each claim as **verified** (seen in a primary source) or **unverified** (secondhand). Never present an unverified claim as fact.

## Phase 3: Score and rank

Check every finalist against each hard requirement: pass, fail, or unknown. Anything failing a hard requirement is out of the ranking. Rank the rest by how many nice-to-haves they hit, then by maintenance health and install friction.

## Output

Lead with the answer. Format:

1. **Top pick**: name, link, and one sentence on why it fits this user's job.
2. **Ranked shortlist** (max 5, best first). For each:
   - Name and link
   - Why it fits (one or two lines)
   - Constraint check: each hard requirement with a pass/fail/unknown mark
   - Maintenance evidence: last commit/release date
   - How to install on NixOS/Linux
   - Main caveat
3. **Near misses** (only if useful, 1-2 lines each): what they'd do well and the exact constraint they fail.
4. **Sources**: links used.
5. **Next action**: one concrete step (e.g., "try X via `nix run`", "read its quickstart", "I can draft the NixOS module").

If more than five candidates genuinely fit, show the top five and offer the rest as a "later" list on request.

### When nothing fits

Say so plainly in the first line. Don't stretch a partial match to fill the slot. Then list the closest near misses with the specific requirement each fails, and offer options: relax a named constraint, combine two tools, or build a thin custom layer. The user values an honest "no good match" over a suggestion that only half fits.

## Style

Be direct and efficient. No preamble, no filler closers. Report problems matter-of-factly (what failed, why, what to do). When the user's requirements are in tension (e.g., "fully local" and "no setup"), point out the tension once, briefly.