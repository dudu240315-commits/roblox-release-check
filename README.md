# Roblox Release Check

A practical AI skill for Roblox creators: find risky code before players do, including client-triggered interactions, player-written text and chat surfaces, cross-server messaging and temporary state, replicated data exposure, cross-place teleports, movement/physics paths, third-party models, HTTP/API integrations, and monetization flows such as developer products and game passes.

It guides an assistant through exploitable remote handlers, potential data loss, lifecycle bugs, and performance concerns, then produces prioritized findings with evidence and focused fixes. Reports follow the user's language, including Hebrew.

For broad audits, it can also provide a short coverage summary showing what was reviewed, what could not be assessed from the supplied project, and what still needs a Studio check. This is part of the assistant's review guidance, not an automated scanner feature.

When given a Git diff or before/after versions, it can review the changed paths and relevant dependencies, separating newly introduced regressions from pre-existing risks.

Cross-place teleport, data-exposure, and profile-migration checks are guided code reviews. The included fixtures do not automate those scenarios; teleport runtime checks use Studio Test/Team Test where supported and have documented limitations.

HTTP/API integration checks are guided reviews too. The reference covers secret handling, request/response trust boundaries, failures, and duplicate side effects. It suggests mock-based verification; the package does not call a live external service or automatically scan HTTP code.

Player-written text checks are guided reviews: the skill distinguishes filtered non-chat text surfaces from conversations that must use `TextChatService`. It does not inspect live moderation outcomes.

Cross-server checks cover best-effort messages and temporary MemoryStore data, including missed notifications, expiration, queue retries, and duplicate effects. These are review prompts, not a distributed-systems simulator.

This is an instruction-based skill, not a Roblox Studio plugin or a standalone scanner. It needs an AI assistant and access to your project code. Studio tools are optional; runtime tests require an appropriate Roblox environment. It does not certify an experience as secure.

## Install in Codex

Download or clone this repository. Copy the folder containing `SKILL.md`, `agents/`, and `references/` into your Codex skills directory as `roblox-release-check`:

- Windows default: `%USERPROFILE%\.codex\skills\roblox-release-check`
- macOS/Linux default: `~/.codex/skills/roblox-release-check`
- If `CODEX_HOME` is customized, use its `skills/` directory.

Start a new Codex chat after installation. Open your project or provide the scripts, then invoke `$roblox-release-check`. Other assistants may be able to use `SKILL.md` as instructions; their installation and discovery mechanisms vary.

For ZIP downloads, copy the extracted inner `roblox-release-check` folder. Verify the final path ends in `skills/roblox-release-check/SKILL.md`, with no extra nested repository folder.

## Example prompts

```text
Use $roblox-release-check to review my Roblox project before release.
Report the highest-impact issues. Do not edit files yet.
```

```text
Use $roblox-release-check to inspect my shop RemoteEvents and fix
confirmed exploits. Keep the current inventory format and test the changes.
```

```text
השתמש ב-$roblox-release-check כדי לבדוק למה נתוני שחקנים נעלמים.
הסבר בעברית איפה הבעיה, איך לתקן אותה ואיך לבדוק שהתיקון עובד.
```

```text
Review this diff with $roblox-release-check. Identify regressions introduced by
the change separately from relevant pre-existing risks. Do not edit files.
```

## Example finding

Illustrative output, not a finding from a real project:

> **High — shop accepts a client-supplied price**  
> Location: `ServerScriptService.Shop`, purchase handler.  
> Trigger: a player requests a valid item with a price of zero; the server uses that price.  
> Impact: items can be acquired for free.  
> Fix: look up the item and price in a server-owned catalog and validate balance before granting it.  
> Verify: a normal purchase succeeds; a forged price cannot reduce the authoritative price; insufficient funds cause no inventory change.

## Repository contents

- `SKILL.md`: assistant workflow and reporting rules.
- `references/review-guide.md`: focused checks and official Roblox sources.
- `agents/openai.yaml`: Codex display metadata and suggested prompt.
- `VALIDATION.md`: historical test runs and limitations; read the latest section for current results.
- `tests/studio-regression.luau`: reproducible synthetic regression checks; run on the server in an isolated Studio Play session. It intentionally reproduces defects before checking corrected behavior and does not access live data stores.
- `tests/failure-regression.luau`: server-only NaN and lock-failure reproduction with corrected cases.
- `tests/receipt-regression.luau`: in-memory receipt retry, duplicate, ordering, absent-player, failed-write isolation, and repeated-callback side-effect checks. It never prompts or charges a purchase and does not model cross-server persistence.
- [tests/MUTATIONS.md](tests/MUTATIONS.md): five reproducible negative controls for test sensitivity, including exact edits, expected diagnostics, and restoration steps. Apply only to a disposable Studio copy.
- `tests/security-server.luau` and `tests/security-client.luau`: bounded remote-security exercise. In a separate empty place, copy the server source into a Script in ServerScriptService, start a fresh Play session, then execute the client source in Client context. It asserts rejected payloads do not mutate state, verifies purchases/replays, and sends 70 bounded repeat requests. Restart Play before repeating. All executable fixtures enforce Studio Play mode and the intended server/client context. The remote suite also checks conflicting payloads under the same action ID, retrying an ID after a rejected request, and a valid purchase spending the exact remaining balance. The security fixture uses a per-player refillable token bucket and session-only replay memory; it is not a production inventory or persistence implementation. The failure/regression suites deliberately contain broken local functions to verify detection, clearly marked as negative tests. Do not copy those functions into game code.
- The receipt fixture is synthetic and not wired to MarketplaceService. Run it in an isolated server Play context; it returns and prints a mock-only report.

The remote test waits up to five seconds for each response and reports malformed replies explicitly. If it times out, stop Play and start a fresh session before retrying: canceling a client wait does not cancel server work. Before exposing the remote, the server checks both limiter arithmetic and enforcement through the same handler used for remote requests, using a controlled clock and isolated state. The client reports the number of rate rejections observed over the network; this count is timing-dependent and can be zero without implying a limiter defect.

Client, regression, and receipt runners print JSON with the `[Roblox Release Check]` prefix in Studio Output and return the report table. The server fixture runs startup assertions and installs the test remote; it does not print a completion report. A failed assertion is a failed run. The remote client supports three scenarios, each requiring fresh server state: `full` (default), `maximum-quantity` (quantity 5 and a 32-byte ID), and `distinct-purchases` (eight simultaneous purchases with unique IDs compete for 500 coins; expect five purchases and three insufficient-funds replies). Change `TEST_SCENARIO` in the client source before running. The full scenario names malformed inputs and refills the limiter before purchase checks. See `tests/MUTATIONS.md` for negative controls. Developer product receipt reviews follow the project's receipt handlers and retry behavior; no real purchase tests are included.

## Publishing on GitHub

This skill is published at [github.com/dudu240315-commits/roblox-release-check](https://github.com/dudu240315-commits/roblox-release-check). Suggested topics: `roblox`, `luau`, `codex`, `ai-skills`, `code-review`.

No license is selected in this package. Before encouraging reuse or accepting contributions, choose a license that matches your intended permissions and add a `LICENSE` file with your chosen attribution. This project is independent and is not affiliated with Roblox.

## Validation and contributions

The GitHub Actions workflow runs a lightweight package check on pushes and pull requests. Run the same check locally from this folder:

```sh
python tools/validate_package.py
```

It checks required files, metadata, unfinished TODO placeholders, and local Markdown links. It does not run Luau or Roblox Studio tests and does not assess whether security findings are correct. See [PUBLISHING.md](PUBLISHING.md) for the release checklist, [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidance, and [SECURITY.md](SECURITY.md) for private vulnerability reporting guidance.

The skill package can be checked using Codex skill-creator's `quick_validate.py`, which is external to this repository. You need Python with PyYAML installed and a Codex installation containing that system skill. From this repository's root, the default Windows PowerShell command is:

```powershell
python "$env:USERPROFILE/.codex/skills/.system/skill-creator/scripts/quick_validate.py" .
```

On macOS/Linux:

```sh
python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/skill-creator/scripts/quick_validate.py" .
```

Adjust the path if your system skills are elsewhere. Structural validation does not prove review accuracy. For behavior changes, try the skill against a small project containing a known defect and a similar correct implementation; verify it reports the former without inventing a problem in the latter. Include the prompt, minimal example, observed output, and expected behavior with an issue or pull request. Do not include credentials or real player data.

