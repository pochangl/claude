## Optimization Rules

Before writing any implementation code, load the `optimize-*` skills relevant to the tech stack you are about to touch and follow their rules throughout the implementation.

Always also load `optimize-general` — it holds cross-cutting optimization concepts (not tied to any one tech stack) that apply to all implementation work, starting with Single Source of Truth: every reusable definition has exactly one canonical home that consumers import. Its stack-specific applications (canonical types, components, API-fetch helpers) live in the matching `optimize-<stack>` skill.

## Memory Rules

Never write to memory (memory files, MEMORY.md, or any auto-memory directory) without my explicit permission. If something seems worth remembering, ask first.
