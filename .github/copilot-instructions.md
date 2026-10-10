# Rook agent entry point

Read the root `AGENTS.md` and `PROJECT-BRIEF.md` before making changes.
They are authoritative; do not duplicate their policies here.

Use the narrowest relevant commands in `docs/ci.md`. Binding changes require
both Rust and native Swift validation. Keep generated bindings reproducible.

Agents may edit files but must use read-only Git operations. Repository
creation, pushes, merges, releases, and infrastructure applies are maintainer
actions with explicit manual gates.
