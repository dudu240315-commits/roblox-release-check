# Validation record

Initial validation date: 2026-11-12. Later validation runs are appended below in chronological order; a run is recorded only when its date is known.

Three independent assistant passes reviewed synthetic defective code, synthetic correct code, and package usability. These were static evaluations, not Roblox engine tests or a statistical accuracy benchmark.

## Observed results

- Defective shop: identified client-controlled price allowing free purchases or balance increases; grouped variants under one root cause.
- Defective profiles: identified failed loads becoming saveable defaults and failed departure saves discarding pending state.
- Correct helper-based shop: no confirmed finding after tracing validation helpers.
- Optional diagnostic snapshots: no incorrect requirement to replace intentional SetAsync with profile persistence machinery.
- Button lifecycle: no false leak finding solely from absence of Disconnect when the signal-emitting button is destroyed.
- Package review: local reference resolves; metadata and invocation agree; review/fix boundaries and runtime limitations are explicit.

## Improvements from the evaluations

- Distinguished destruction of an event emitter from destruction of objects captured by callbacks.
- Added inspection of yields between validation and mutation.
- Separated severity from static versus runtime evidence.
- Clarified merging variants of the same defect.
- Scoped persistence expectations to the data's purpose.
- Treated unavailable teardown callers as missing evidence rather than proven leaks.
- Added usable external validator commands and prerequisites to README.

## Limits

The initial three passes above were static only. Subsequent Studio execution is recorded below. Structural validation checks package format, not review accuracy. Synthetic examples do not establish real-world precision or recall.

## Studio runtime follow-up

A new unpublished Place1 was opened separately from the existing airport experience. The skill was read and applied manually through Studio MCP; automatic skill discovery/installation was not tested.

- Client-to-server RemoteFunction exploit reproduced: a negative price changed balance from 150 to 250.
- Server-authoritative replacement: six invalid inputs rejected with balance unchanged; legitimate Sword purchase charged 100; ten overlapping repeated requests after ownership were rejected with balance 50.
- Lifecycle runtime: destroying a captured Model did not disconnect a Heartbeat listener; explicit Disconnect did. Destroying a BindableEvent disconnected its own listener.
- Injected in-memory storage read failure reproduced a default overwrite (5000 to 100); a successful-load guard preserved 5000. This was not a DataStoreService test.
- Play was stopped after testing. Existing airport experience was not modified. No game was published.

These small fixtures show the workflow can detect and verify selected defects, not that all games will be reviewed accurately.

## Second regression round

Three additional agents evaluated concurrency/persistence, clean archive extraction, and missing-context/lifecycle cases. Archive extraction, file hashes, metadata, reference resolution, and structural validation passed. Partial cleanup context produced a question, complete accumulating handlers produced a finding, and explicit cleanup produced no confirmed accumulation.

The maintainer ran `tests/studio-regression.luau` in the isolated Place1 server Play context:

- Two first purchases forced to overlap: defective result -50 coins/two grants; corrected result 50 coins/one grant.
- Mock stale snapshot replacement reproduced lost progress; revision check preserved the newer state. This is not a complete persistence protocol.
- Three simulated character lifecycles retained three service listeners; explicit teardown disconnected all three.

All suite assertions passed and Play was stopped. These are synthetic server functions, not actual respawns or concurrent client transport. The suite is included for reproduction. Skill guidance now tests fresh-state overlap and lock failure recovery; README clarifies ZIP folder nesting. Lock-helper failure was reviewed statically, not run in this suite.

Remaining: real persistence integration, actual respawn/rejoin behavior, live Codex discovery after installation, and independent review of an unfamiliar full game. No game was published or existing airport code modified.

## Security regression round

Executed in the same isolated Place1, with actual client/server RemoteFunction transport for the security fixture:

- 16 malformed/unauthorized payloads rejected with balance 500 and no grants: wrong request types, missing fields, forged target ID, unknown item, zero/negative/fractional/excessive quantities, NaN, both infinities, numeric string, oversized ID, unexpected price field, and wrong ID type.
- Normal purchase succeeded; exact replay and insufficient funds were rejected.
- Eight overlapping requests with one shared action ID produced exactly one additional grant.
- A bounded sequence of 70 repeat requests preserved balance 300 and total grants 2; 33 requests reached the fixture's explicit lifetime budget and were rejected as rate-limited.
- Server-only failure regression reproduced a NaN bypass in a range-only check, then passed explicit numeric/integer validation.
- Server-only regression reproduced a stranded lock following a helper exception; corrected cleanup released it and allowed a subsequent valid action without charging the failed action.

All assertions passed. Studio was returned to Edit mode. The security fixtures and reproduction instructions are included. Guidance was strengthened for actor binding, payload shape/size, integer quantities, replay scope, and production-versus-test limiter distinctions, consistent with the linked official client-server-boundary documentation.

These are newly authored security fixtures, not newly discovered vulnerabilities in the user's airport game. Lock failure was injected before mutation; ambiguous external side effects remain untested. The bounded burst does not establish denial-of-service resistance. The forged-target test used a different numeric ID, not a second connected player. No real data store, paid purchase, or public service was attacked or modified.


## Hardening correction after full-package reinspection

Confirmed limitations corrected: executable fixtures lacked a Studio-only guard, and the security fixture's lifetime request counter never recovered. All four Luau test files now enforce Studio Play context. The server remote uses a per-player token bucket (capacity 32, refill 16/second), checks for duplicate fixture registration, and the superseded ReviewShop Script in Place1 is disabled. Negative-test functions are explicitly labeled and remain isolated from remote handlers.

One intermediate test failed: 70 sequential calls did not exhaust the refilling budget. The test was corrected to generate bounded concurrent calls, rather than weakening the limiter to satisfy a serial test. On the fresh final Play run: 16 invalid inputs rejected, 8 concurrent identical actions produced one grant, 49 of 70 burst calls were rate-limited, and a valid purchase succeeded after 1.1 seconds. Both other regression suites passed again. Play was stopped.

No specific external scanner report was supplied, and no critical exploit in the revised fixture was demonstrated. This is not an assertion that every possible issue is resolved. Real persistence, cross-player sessions, production inventory, and external side effects remain outside the tested scope.


## Existing-feature refinement

Improved replay validation to distinguish an identical retry from an action ID reused with different purchase data. Added positive controls: an ID from an insufficient-funds rejection remains usable for a valid adjusted request; spending the exact remaining balance succeeds; later insufficient-funds requests preserve zero balance and the existing grants. Concurrent workers now capture response-state assertions inside their error aggregation rather than counting success booleans alone. All scripts enforce the intended client/server execution context.

Fresh Studio Play result: 16 invalid payloads rejected, 8 identical concurrent requests produced 1 grant, 50 of 70 bounded burst requests rate-limited, cooldown recovery passed, changed-payload conflict rejected, failed-ID reuse passed, exact-balance purchase passed. Both other regression suites passed again. Play was stopped. These checks still cover isolated fixtures, not a production economy or real persistence.

## Profile migration review guidance (2026-11-26)

Three agent reviews identified that persistence guidance did not explicitly cover profile schema migrations. A dry-run with a backward-compatible legacy profile and a migration interrupted before persistence confirmed the revised guidance distinguishes safe repeatable conversion from data loss, and does not treat a missing schema-version field alone as a defect. This was a documentation-level evaluation only; no DataStoreService or Roblox Studio migration test was run, and the package contains no migration fixture.

## Multi-agent harness reliability review

Three agents reviewed the server, test harness, and documentation independently. They confirmed a concrete harness defect: burst response inspection could fail outside protection, losing the error behind a timeout. Serial remote calls were also unbounded, and the concurrency fixture could skip cleanup on a readiness failure. No new critical server vulnerability was established; replay storage is naturally bounded to five successful purchases by this fixture's fixed balance and price.

Changes: shared protected batch execution with strict response validation; five-second remote wait deadlines; cancellation and gate destruction before concurrency failures; per-case rejection reasons; actual limiter logic tested with controlled timestamps for capacity, exhaustion, fractional refill, backward time, refill cap, and independent buckets. Network rate counts are now observations, not a timing-dependent pass condition. README links this historical record.

Runtime verification in isolated Place1:

- Normal remote suite passed, including 16 invalid inputs, exactly one grant across 8 duplicate concurrent requests, replay/conflict checks, valid purchases, and cooldown recovery. 50 of 70 burst requests were rate-rejected in this run.
- All synthetic regression suites passed; an injected pre-ready worker error was surfaced after every worker was canceled and its gate destroyed.
- Temporarily returning nil from the actual test remote produced the expected explicit malformed-response diagnostic.
- Temporarily delaying the actual test remote by ten seconds produced the expected request timeout after approximately 5.05 seconds.
- Play was stopped, discarding injected runtime faults. Two agents reread the final code and found no new concrete regression.

The timeout cancels only the client wait; stopping Play terminates the isolated server work. Real persistence, multiple connected players, production inventory, and unfamiliar-project review remain untested. All fixture code remains restricted to the appropriate Studio Play context.

## Boundary coverage and nested cleanup review

Three agents reviewed harness cleanup, missing boundary cases, and package usability. No new blocking defect in the existing normal paths was found. They identified a conditional ownership gap: an outer batch with a shorter deadline than its child call could cancel the worker while leaving its child running. The batch now registers and cancels its child tasks; a targeted shorter-outer-deadline test asserts the child is dead.

The full remote suite now uses 22 named invalid cases, including nil input, individually missing required fields, and empty IDs. Expected rejection reasons stay with the payload rather than in a separate parallel list. A refill pause separates validation traffic from purchase testing. A separate fresh-state maximum-quantity scenario verifies both accepted upper boundaries: quantity 5 and a 32-byte ID. Test reports are printed to Studio Output as JSON as well as returned to tools.

Runtime results in Place1:

- Full scenario passed all 22 invalid cases, replay/conflict/valid-purchase checks, nested timeout cleanup, and cooldown recovery; 8 duplicate concurrent actions produced 1 grant. This run observed 47 rate rejections among 70 burst calls.
- Synthetic regression passed additional injected readiness and completion timeout cleanup tests, plus all previous cases.
- NaN/lock-failure regression passed again.
- In a new Play session, the maximum-quantity scenario successfully granted 5 units for the full 500 balance with a 32-byte ID, then rejected its duplicate without mutation.

Both sessions were stopped. These are bounded fixture tests; no new claims of production security, real persistence, or multi-player coverage are made.

## Mutation sensitivity and handler enforcement

Three agents reviewed mutation candidates, harness coverage, and reproducibility. A predicted gap was reproduced in Studio: disabling only the handler's rate-limit gate left the old full suite passing with zero observed rate rejections. Helper selfchecks could not prove that the handler invoked the limiter.

Refactored the existing handler body into `handle(state, actorId, request, now)`. The remote wrapper still supplies the engine player's UserId and per-player state. Before exposing the remote, controlled-clock checks run through this same handler to prove capacity exhaustion, rejection without state mutation, refill recovery, and independent state. This test surface is internal, with no client-accessible clock or bypass. Added descriptive purchase/replay/funds diagnostics.

Five separately injected mutations were detected by their intended diagnostics in fresh Studio sessions:

1. Disconnected limiter: startup assertion `handler limiter enforcement missing`; no test remote created.
2. Forged owner accepted: `forged owner: expected owner, got purchased`.
3. Fractional quantity accepted: `fractional: expected quantity, got purchased`.
4. Replay lookup removed: `duplicate purchase must not grant twice`.
5. Valid maximum ID rejected: `valid maximum boundaries rejected`.

The canonical packaged server was restored after every experiment. Both full and maximum-quantity baselines passed again afterward; the final full run observed 46 rate rejections and rejected all 22 invalid cases. Exact Studio-to-package source equality was verified, and Studio was returned to Edit mode. An agent reread the refactor and found no concrete regression.

Reproduction recipes are in `tests/MUTATIONS.md`; no mutated server is shipped. These five detections demonstrate sensitivity to those five faults, not exhaustive security coverage or independent measurement of skill-review quality.

## Persistence positive control and distinct purchases

Three agents reviewed persistence coverage, purchase concurrency, and reproducibility. They identified two test gaps: stale-only persistence assertions would pass if every save were rejected, and concurrent purchases reused one ID, testing replay protection rather than legitimate purchase competition.

The in-memory revision test now confirms that a matching revision accepts a save, increments the revision, and preserves the input snapshot. It rejects stale and replayed revisions without changing stored state, then accepts the next correct revision. A mutation making the transform always return nil failed with `matching revision must save`.

Added a fresh-state `distinct-purchases` client scenario. Eight simultaneous valid purchases with unique IDs against 500 coins produced five purchases, three insufficient-funds rejections, and final state of zero coins and five grants. Assertions validate returned snapshots without assuming completion order. This models one player making concurrent requests; it does not simulate multiple players or a real economy.

Studio results: the new scenario passed; the persistence suite passed normally and detected the always-reject mutation. The `full` (22 invalid inputs) and `maximum-quantity` scenarios passed afterward in fresh sessions. Studio was stopped. These remain isolated synthetic tests, not DataStoreService integration tests.

## Developer product receipt review feature

Three agents reviewed security focus, code, and creator workflow. No additional confirmed bug was found in the existing fixtures. Added focused checks for `ProcessReceipt` and `BindReceiptHandler`: server-owned grants, `PurchaseId` idempotency, duplicate/retry behavior, safe acknowledgement after recording a grant, and failure recovery. The guide distinguishes receipt processing from the purchase-prompt-finished signal and mock checks from cross-server guarantees, following Roblox Creator Hub documentation.

This adds a review path, not a live purchase flow. Real receipt processing against a game's persistence/session architecture remains project-specific.

## Client-triggered interaction review feature

Added a distinct audit path for consequential ProximityPrompt, ClickDetector, and DragDetector handlers. The guide distinguishes event-specific engine checks, client-controlled prompt properties, distance and player-state validation, rate limits, and network-owned movable assemblies. This follows Roblox Creator Hub's current client-server security and network ownership guidance. It explicitly prevents reporting a decorative prompt without a consequential server handler as a vulnerability.

This is a review capability addition. No Studio runtime test was run because there was no isolated Studio place connected during this turn; the only previous connected Studio target was the existing cloud experience. Structural validation covers package syntax and metadata only, not runtime behavior.

## Receipt mock hardening and movement review feature

Three agents reviewed security scope, receipt mock semantics, and package consistency. The receipt reviewer found a real flaw in the mock: it passed the stored profile table by reference into the callback, so a failed write could mutate stored data. The mock now passes defensive copies, compares full receipt/balance results across callback retries, preserves stored state on write failure, and injects an external-side-effect counter to ensure retry checks catch repeated side effects. Its mocked status strings are not Roblox enums, and it still cannot establish cross-server behavior.

Added a movement/physics review path for network-owned assemblies and consequential `Touched` events, with guidance to account for game mechanics and latency before proposing thresholds. README now accurately describes which test runners print a report. These documentation/mock changes were structurally validated; no Studio place was connected, so the modified receipt fixture has not been run in Studio this turn.

Added `tests/receipt-regression.luau`, an in-memory model for duplicate and reordered receipts, absent players, unknown products, failed writes, successful retry, and repeated transform invocation. It uses mock result strings, does not call MarketplaceService or DataStoreService, and cannot prove cross-server guarantees. Runtime execution was not performed in this pass because the only connected Studio session was the existing cloud experience in Play mode; the receipt fixture was not run against it. Structural package validation passed instead.
