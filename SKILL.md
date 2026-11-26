---
name: roblox-release-check
description: Review Roblox Luau projects before release for exploitable client-server boundaries, data-loss risks, lifecycle bugs, and measurable performance problems. Use for Roblox release checks or focused script audits, with optional fixes when requested.
---

# Roblox Release Check

Help creators find actionable release risks. Explain findings in the user's language, using concrete gameplay consequences and small fixes that preserve the game's design.

## Establish the evidence

Work from supplied Luau files, a local project, or available Roblox Studio tools. No particular MCP server is required. Discover available tools before using them; never invent tool names. If no project is accessible, ask for the relevant scripts or project location and offer a clearly labeled checklist meanwhile.

Identify the requested feature and scope. For a broad review, map server/client scripts, shared modules, remote handlers, and persistence entry points first. Use Rojo mappings, instance ancestry, RunContext, and require callers to establish execution context; filename alone is not proof. Trace relevant helpers before declaring a validation check absent.

If the user supplies a Git diff, pull request, or before/after versions, use a change-set review: focus on changed code and the callers/callees needed to understand its impact. Separate regressions introduced by this change from relevant pre-existing risks. Only call an issue newly introduced when the supplied base version supports that conclusion; without a base, say introduction status is unknown.

For a review request, report findings without changing the project. For an explicit fix request, make targeted changes and validate them. Do not publish the experience, install dependencies, or modify live player data as an implied part of a review.

## Review the relevant paths

Read [references/review-guide.md](references/review-guide.md) for the relevant checks and official sources. Prioritize reachable bugs over style preferences:

- Follow client-controlled input to authoritative rewards, purchases, damage, inventory changes, and shared state.
- When projects include Creator Store/Toolbox models or third-party packages, inspect their scripts, dynamic code loading, and granted capabilities; report a concrete reachable risk or mark an unverified source for review, not as a confirmed backdoor by itself.
- For game passes, trace server-side ownership checks through benefit grants and later use; distinguish temporary access from permanent rewards when trials are enabled.
- Trace consequential `ProximityPrompt`, `ClickDetector`, and `DragDetector` handlers as client-triggerable entry points; use the reference guidance for their event-specific server checks.
- For games where physics or movement changes rewards/combat/shared state, trace network ownership and `Touched` paths; account for legitimate teleports, vehicles, and latency before suggesting movement thresholds.
- Follow player data from load through mutation to save, including failures, retries, overlapping sessions, departure, and shutdown.
- When developer products are in scope, trace receipt callbacks through durable grants and duplicate/retry handling; read the relevant receipt guidance in the reference.
- Inspect lifecycle and performance only where the code shows a concrete failure path or there is profiling evidence.

Distinguish confirmed findings from questions and unmeasured hypotheses. Do not claim a game is secure or release-ready because no issues were found in a subset. Do not invent a numerical health score. If API behavior or limits affect a conclusion, verify current official documentation when access is available; otherwise state the uncertainty.

## Report for a creator

Start with the most consequential finding. Each finding should include:

1. Severity: critical for a demonstrated major exploit or broad data-loss path; high for a reachable serious gameplay/data defect; medium for a bounded functional or performance problem; low for a minor actionable issue. Explain impact rather than relying on the label.
2. Evidence: actual file and line when available, or exact Studio instance path and function. Never fabricate line numbers.
3. Trigger and player impact: what action or failure reaches the problem, and what happens.
4. Smallest practical fix, plus a test that would distinguish broken from corrected behavior.

State evidence mode separately from severity: a statically established code path is not a runtime reproduction. Severity follows impact and reachability, not whether Studio was available. Merge duplicate findings with the same root cause, such as zero and negative prices accepted by one unchecked parameter. Keep speculative concerns in a separate short verification list. If there are no confirmed findings, say so and describe coverage limits.

For change-set reviews, label each finding's introduction status `Introduced`, `Pre-existing`, or `Unknown`, separately from severity and evidence mode. Do not infer introduction status if the base version is unavailable.

For broad reviews, end with a concise coverage summary, without a total score. Include only relevant areas and mark each as `Reviewed` (with paths and static/runtime evidence) or `Not assessed` (with the reason, such as missing files or out-of-scope work). Add `Needs Studio` as a separate next-check note when runtime verification remains; an area can be reviewed statically and still need a Studio test. Missing files are not evidence that a feature is absent or safe. Focused single-feature reviews can use a short scope note instead of the table. End with what was inspected, what was tested, and what still requires Studio or runtime verification. Prefer a few strong findings over filling a quota.

## Fix and verify when requested

Preserve remote contracts, data schemas, and project conventions unless the fix requires changing them; explain required migrations. Use existing persistence/session-management abstractions rather than replacing them blindly.

Run available static checks and focused tests. For remote fixes, test a valid request, invalid types/values, unauthorized state, and repeated requests. For persistence fixes, cover failed loads and saves, retry ordering, and concurrent updates when relevant. Use isolated test data for persistence tests. For lifecycle fixes, exercise respawn, rejoin, and teardown as applicable.

When Studio execution is unavailable, label patches as statically reviewed and give concrete manual steps with expected outcomes. Never report tests as passed unless they actually ran.

For overlapping requests, test two valid first actions against fresh state and force overlap at the suspected yield; requests after ownership is already established do not exercise this race. If the fix adds a lock or reservation, inject a helper failure and verify release, recoverability, and consistent charging/granting. A caught exception alone does not prove an external grant had no effect.

In concurrent test workers, capture assertion failures and aggregate them before reporting success; counting completed calls alone is insufficient. Verify returned state as well as the number of successes, and include legitimate boundary cases so a fix that rejects everything cannot pass.

Bound test waits and clean up tasks/connections before raising failures. Canceling a client waiter does not cancel server work: end the isolated Play session after a remote timeout. Separate deterministic rate-limit checks from network observations; a slowly delivered burst need not exhaust a correctly refilling limiter. When testing malformed inputs, assert the intended rejection reason so an unrelated rate rejection cannot falsely prove validation works.

Cover both sides of a relevant boundary: missing/empty values and the maximum valid size or quantity, not just values beyond it. Separate validation and rate-limit phases so earlier test traffic does not mask the behavior being checked. When test workers create child tasks, register those children for cleanup as well; canceling a worker alone does not prove its children stopped.

For security-critical fixes, verify enforcement through the actual handler, not only isolated validation or limiter helpers. When test sensitivity is uncertain, a targeted mutation in a disposable fixture can show whether the intended assertion fails; unrelated errors do not count. Restore the original code and rerun the baseline afterward. Mutation results demonstrate test sensitivity, not independent AI-review accuracy.
