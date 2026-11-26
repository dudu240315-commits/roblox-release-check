# Contributing

Thanks for helping improve Roblox Release Check.

## Before opening a pull request

- Run `python tools/validate_package.py` from the repository root.
- For instruction or test changes, describe a realistic Roblox case and the expected result.
- Keep Studio-only tests clearly labeled. Do not describe static or mock tests as Roblox runtime coverage.
- Update `VALIDATION.md` when a check was actually run; include the environment and limitations.
- Do not include player data, credentials, private experience code, or purchase identifiers.

The GitHub Actions workflow checks package structure and local links. It does not run Roblox Studio or certify security findings.
