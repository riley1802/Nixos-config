# NixOS config

Change this computer only with `nixctl` (run `nixctl help`). Start with `nixctl map`.
Use the nixos-managing skill. Every nixctl output ends with RESULT: and usually NEXT: lines; do what NEXT says.
Never run nixos-rebuild or sudo yourself. If a task needs root, use `pkexec`.
Machine rules are in `nix-agent.md`.

In Cursor, every implementation goes to the `implementation-subagent`. The parent does not edit those files itself. A one-line fix (one line, one file, no new file and no multi-step check) stays with the parent. The task must include the plan, the files, and these repo rules, because the subagent does not see the chat.
