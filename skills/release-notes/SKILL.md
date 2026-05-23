---
name: release-notes
description: Generate user-facing release notes spanning one or more version bumps. Triggers on "release note", "release notes", "changelog", "/release-notes", or any request to summarize what changed between two versions for end users.
user-invocable: true
---

# Release Notes Skill

Generate a single short consolidated list of user-facing highlights — not a per-version commit breakdown.

## Why

End users receive a multi-version range as one release. Long per-version lists with refactors and internal changes don't get read.

## Procedure

1. Identify the commit range. If the project uses `version:` in `pubspec.yaml` or similar, walk `git log` on that file to find the SHA at each version. Range is `<from_version_prev_bump>..<to_version_bump>`.
2. Run `git log --oneline <range>` to see all commits in the range.
3. Filter and group:
   - Drop pure refactors, chores, version bumps, internal-only changes.
   - Group related commits into a single bullet (e.g. multiple badge additions → one bullet).
   - Keep `feat:` commits and user-visible `fix:` commits.
4. Write ~5 bullets max, in the app's UI language (check `CLAUDE.md` or recent strings — Traditional Chinese for zh-TW apps, English for English apps, etc.).
5. Lead with a single header line naming the final version only (e.g. `**3.8.25 更新**`), not each sub-version.
6. Don't say which sub-version shipped which feature.

## Output Format

```
**<final-version> 更新**
- <highlight 1>
- <highlight 2>
- <highlight 3>
- <highlight 4>
- <highlight 5>
```

## What NOT to Do

- Don't list every commit.
- Don't split by sub-version.
- Don't include refactors, dependency bumps, or internal-only changes.
- Don't write more than ~5 bullets unless the user explicitly asks for more detail.
- Don't translate commit messages literally — rewrite from the user's perspective.
