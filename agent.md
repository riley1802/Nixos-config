# Agent

For changes to this NixOS computer, follow `nix-agent.md`.

When the user states a rule in chat, ask whether it is a permanent rule before writing it here. Add it to this file only after they say yes.

When something goes wrong, record it in `lessons.md`: what went wrong, and what resolved it.

If a task needs root, use `pkexec`. Do not use `sudo`. NixOS config changes still go through `nixctl`.

Update documentation very frequently. After each meaningful change, bring the matching docs up to date in the same step: `README.md`, `soul.md`, `nix-agent.md`, module comments, and `lessons.md` when the change taught something. Do not leave docs for a later pass.
