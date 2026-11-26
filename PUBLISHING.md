# GitHub release checklist

Repository: [github.com/dudu240315-commits/roblox-release-check](https://github.com/dudu240315-commits/roblox-release-check) (public).

## Prepared in this package

- Skill instructions, Codex metadata, creator-facing README, and official Roblox references.
- Studio-only regression fixtures with documented limits.
- `CONTRIBUTING.md`, `SECURITY.md`, and a GitHub Actions packaging check.

## Remaining maintainer decisions

1. **Choose a license.** No license is included because reuse permissions are your choice. Add the complete license text in a root `LICENSE` file and update the reminder in README. Without a license, GitHub users may view and fork the public repository under GitHub's platform terms, but you have not granted general permission to reuse, modify, or distribute the work.
2. Confirm the `Validate package` workflow passes on GitHub. It validates packaging only; it does not run Roblox Studio fixtures.
3. Add a release tag only after deciding the license and checking the published files.

## What CI covers

The workflow checks required files, skill metadata, unresolved TODO placeholders, and local Markdown links using Python's standard library. Luau fixtures require Roblox Studio and remain manual. Passing CI validates packaging consistency only; it does not verify runtime behavior or certify the AI skill's security findings.

Optional for a small first release: Code of Conduct, issue forms, badges, and a changelog. Add them when you have a contributor community or a release cadence.
