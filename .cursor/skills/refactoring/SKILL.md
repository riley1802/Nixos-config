---
name: refactoring
description: Apply Refactoring principles for behavior-preserving structural improvements in small steps. Use for refactoring passes, cleanup, or when the user mentions refactoring or Fowler.
disable-model-invocation: true
---

# Refactoring by Martin Fowler

Rules from [agent-rules-books](https://github.com/ciembor/agent-rules-books) (MIT). Follow [rules.md](rules.md) for this task.

- Full reference: [reference.md](reference.md)
- Compact fallback: [rules.nano.md](rules.nano.md) (if present)
- Book compatibility: [COMPATIBILITY.md](../agent-rules-books/COMPATIBILITY.md)

## Precedence

When editing this NixOS flake (`/etc/nixos`), **@edit-nixos** and [bestpracticesnixos.md](../../bestpracticesnixos.md) override general coding rules. Use this skill for code quality within those constraints.

## Usage

1. Load **one primary** book skill per task (see compatibility matrix for overlaps).
2. Read and apply [rules.md](rules.md) before implementing or reviewing.
3. Consult [reference.md](reference.md) only when the mini rules are insufficient.
