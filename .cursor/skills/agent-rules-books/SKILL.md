---
name: agent-rules-books
description: Index of programming book rule skills (Clean Code, Refactoring, DDD, Clean Architecture, DDIA, etc.) from ciembor/agent-rules-books. Use when the user asks which book rules to apply, wants coding standards from classic SE books, or references agent-rules-books.
disable-model-invocation: true
---

# Agent Rules from Programming Books

Vendored from [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) v0.5 (MIT) in [../agent-rules-books/](../agent-rules-books/).

## Available skills

| Skill | Book | Best for |
|-------|------|----------|
| @a-philosophy-of-software-design | A Philosophy of Software Design | API/module design, complexity |
| @clean-architecture | Clean Architecture | Boundaries, dependency rule |
| @clean-code | Clean Code | Readability, naming, review |
| @code-complete | Code Complete | Construction discipline |
| @designing-data-intensive-applications | DDIA | Data, consistency, streams |
| @domain-driven-design | DDD (Evans) | Domain modeling, contexts |
| @domain-driven-design-distilled | DDD Distilled | Lightweight DDD |
| @implementing-domain-driven-design | IDDD | DDD implementation |
| @patterns-of-enterprise-application-architecture | PoEAA | Enterprise patterns |
| @refactoring | Refactoring (Fowler) | Behavior-preserving cleanup |
| @refactoring-guru | Refactoring.Guru | Smell diagnosis |
| @release-it | Release It! | Production reliability |
| @the-pragmatic-programmer | The Pragmatic Programmer | General engineering |
| @working-effectively-with-legacy-code | Working with Legacy Code | Risky legacy changes |

## How to use

1. Pick **one primary** skill for the task.
2. Invoke it explicitly (e.g. `@refactoring`) or describe the work type.
3. Do not load overlapping pairs as equal guidance — see [COMPATIBILITY.md](../agent-rules-books/COMPATIBILITY.md).

## NixOS precedence

For `/etc/nixos` changes, use **@edit-nixos** first. Book rules apply to general code quality within Nix module constraints.

## Source files

Each book has `mini`, `nano`, and `full` versions under [../agent-rules-books/](../agent-rules-books/). Skills use `mini` as active rules; `full` is reference only.
