# Focused review guide

Use only the sections relevant to the reviewed feature. These are investigation prompts, not automatic findings.

## Change-set review

When given a diff or before/after versions, review the changed paths first, then trace only the callers, callees, configuration, or data flow needed to establish impact. Compare the base and proposed behavior before labeling a finding as introduced by the change. If the base version is unavailable, mark introduction status as unknown. Keep pre-existing risks separate and include them only when they affect the changed feature or release decision. Do not treat unchanged lines shown as context as newly introduced defects.

## Client-server boundary

Trace remote input through server helpers. Check types, finite numeric values, bounds, instance ancestry, ownership, current gameplay state, and permission to perform the action. Treat prices, reward amounts, and damage supplied by the client as claims to verify against server rules. Check rate limits on the server where repeated requests could cause harm; a UI cooldown is insufficient evidence of server protection. Account for legitimate bursts before proposing a limit.

Source: [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary).

Bind authority to the player supplied by the engine to the server callback, not a caller-supplied user ID. A target ID is not automatically wrong: trades, combat, and gifts need explicit permission rules. Test forged targets against those rules. Validate integer quantities separately from finite numbers; range rejection alone can let NaN through. Bound strings and table structure before expensive processing where payload size drives work.

For actions intended to happen once, test replay with the same action ID and overlapping requests. Distinct legitimate repeat purchases should remain possible when the game allows them. Scope deduplication and rate state appropriately to the player/action, bound retained state, and inspect cleanup. Do not turn a test-only lifetime request budget into a production limiter; test recovery after the intended cooldown/refill.

### Client-triggered instances

Include `ProximityPrompt`, `ClickDetector`, and `DragDetector` server handlers in the client/server trace; they can trigger gameplay code without a RemoteEvent. For every consequential handler, verify server-owned player state, permission, current character, meaningful distance, and server-side rate limits. Do not treat client-visible `Enabled`, `MaxActivationDistance`, `RequiresLineOfSight`, or hold duration as authorization. Roblox documents that only `ProximityPrompt.Triggered` has an engine-side server distance check; other prompt hold/end events do not. ClickDetector events have no server-side distance checks. For DragDetector, distinguish the server-checked dragging permissions from inherited ClickDetector events and other unchecked properties. If an unanchored assembly can be moved by its network owner, account for that when trusting distance. Validate actual event connections and their effects before reporting a vulnerability; a decorative prompt with no consequential handler is not itself a security finding.

Sources: [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary), [Network ownership, movement validation, and physics](https://create.roblox.com/docs/scripting/security/network-ownership).

## Third-party models and packages

When a project contains Creator Store/Toolbox models or packages, inspect the scripts they add and trace any dynamic code loading or powerful capabilities to their reachable effects. Treat obfuscation, an unfamiliar creator, or an asset ID passed to `require` as a reason to inspect provenance and behavior, not proof of a backdoor. Report confirmed impact only when the code path can affect server state, data, networking, or other project code; otherwise list the asset/source as an unverified review question. If Studio exposes script sandboxing/capabilities, compare granted permissions with what the asset needs and verify current behavior in official documentation.

Sources: [Vulnerabilities from third-party assets](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities), [Toolbox](https://create.roblox.com/docs/projects/assets/toolbox), [Script Capabilities](https://create.roblox.com/docs/scripting/capabilities).

## Game passes

Trace a pass from purchase prompt and server-side ownership lookup to the benefit grant and every later use of that benefit. Do not grant permanent value solely because a client reports purchase success; `PromptGamePassPurchaseFinished` can also report success when a free trial starts. Treat a failed ownership lookup as unknown: do not grant from it, and allow a later check to retry. If free trials are enabled, use `UserOwnsGamePassAsync` or the `Active` field for temporary access, but require `GetPassOwnershipAsync(...).Owned` before saving permanent items, currency, or unlocks. Recheck ownership when access matters instead of caching it for the full session, because trial access can end. Verify the current Creator Hub guidance before applying these APIs, as pass and trial behavior can change. This is a manual review scenario; the package does not include an automated Game Pass fixture.

Sources: [Passes](https://create.roblox.com/docs/production/monetization/passes), [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).

Check the contract for reusing an action ID with a different payload: reject the conflict or return the original outcome consistently, rather than execute a different action under the same identity. Test that rejected requests do not consume IDs unless the protocol intentionally specifies that behavior. Include exact-balance purchases and legitimate purchases with distinct IDs as positive controls.

Trace yields and asynchronous helper calls between validation and mutation. Determine whether overlapping requests can both pass a balance, ownership, or availability check before either commits. Recommend serialization or revalidation only when this interleaving is reachable; do not assume every handler overlaps at every statement.

## Persistence

Establish what the stored data means before applying profile durability requirements. Disposable diagnostics and intentionally session-only state do not automatically need profile locking, autosave, or progress recovery. Trace actual consumers and writes; comments describe intent but are not proof of behavior.

Distinguish a successful missing-key load from a failed load; investigate whether fallback defaults could overwrite existing data. Trace error handling and ordered, bounded retries. Check whether stale sessions can overwrite newer progress and whether the project already handles session ownership.

Use UpdateAsync when an update depends on the stored value. Its callback can run more than once and cannot yield: investigate rewards or other side effects inside it. UpdateAsync alone does not make a stale full-profile replacement safe. Do not flag every SetAsync call: replacing a value independent of its previous state can be intentional. Look for autosave, departure, and shutdown behavior without assuming any one hook guarantees durability.

Sources: [Data stores](https://create.roblox.com/docs/cloud-services/data-stores), [Best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices), [GlobalDataStore](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore).

## Developer product receipts

When developer products are in scope, trace the actual `MarketplaceService.ProcessReceipt` and any `BindReceiptHandler` routing through each server-owned grant rule. Filtered bound handlers can take precedence while unmatched receipts fall through to `ProcessReceipt`; don't report missing coverage until routing is followed. Do not treat `PromptProductPurchaseFinished` as proof of purchase. Roblox documents receipt callbacks can be retried, arrive out of order, or overlap across servers; check duplicate `PurchaseId` handling against the project's persistence/session design. Avoid external balance or inventory side effects inside an `UpdateAsync` transform because Roblox may call the transform more than once. Confirm a receipt is acknowledged only after the benefit is safely recorded, and transient failures remain retryable. Trace handler ownership before reporting multiple callbacks or missing coverage.

Use isolated mocks for duplicate and reordered receipts: a repeat must not grant twice, a failed write must not acknowledge an unrecorded grant, and recovery should allow one successful grant. Exercise callback re-invocation to catch side effects in an `UpdateAsync` transform, and verify absent-player handling remains retryable. A mock verifies local decisions, not cross-server atomicity or real DataStore guarantees. Never issue real Robux purchases as a code test.

In a persistence mock, pass a copy of the stored profile into the transform so a failed write cannot mutate the mock's stored value by reference. Compare the complete receipt ledger as well as the balance across callback retries, and inject a side-effect counter to ensure retrying the transform does not repeat analytics or grants outside the returned data.

Sources: [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService), [Implement player data and purchasing systems](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing).

## Movement and physics

For experiences where movement, combat, touch events, or movable physics assemblies affect rewards or other shared state, trace network ownership to the affected server handlers. Check whether clients can drive unanchored assembly position/velocity or trigger `Touched` outcomes that are trusted without server plausibility checks. Review the game's actual teleports, vehicles, knockback, and latency tolerance before recommending movement thresholds; simple distance-over-time rules can reject legitimate gameplay or lag. For critical interactions, validate server-observed position/state and ownership appropriate to the design, and test valid movement alongside teleport/fly/through-wall or forged-touch cases.

Sources: [Network ownership, movement validation, and physics](https://create.roblox.com/docs/scripting/security/network-ownership), [Security tactics](https://create.roblox.com/docs/scripting/security/security-tactics).

## Lifecycle and performance

Trace event connections, tasks, and player-keyed tables through their actual ownership and cleanup. Determine whether repeated setup or respawn accumulates active work. Check references after characters or instances are replaced. Distinguish the signal-emitting instance from objects captured by its callback: destroying a character does not disconnect a callback attached to a long-lived service such as RunService. Conversely, do not flag a connection solely because it lacks an explicit Disconnect call when destruction of its signal-emitting instance handles cleanup. Check separately for retained references and tasks.

For repeated hierarchy scans, per-frame work, and replicated updates, establish frequency and scale. Describe unprofiled performance concerns as hypotheses, with a measurement plan. Avoid asserting FPS gains or memory savings without before/after data from comparable runs. Do not propose a broad rewrite for a small hotspot.

If teardown callers or lifecycle wiring are outside the available code, ask a verification question rather than treating missing context as a confirmed leak.

## Useful verification scenarios

| Feature | Scenario | Expected property |
| --- | --- | --- |
| Shop remote | Client submits a cheaper price or an item it cannot buy | Server derives the authoritative price and rejects unauthorized purchases |
| Numeric input | Wrong type, NaN, infinity, negative or excessive value | Request is rejected before mutation or expensive work |
| Inventory | Same request repeats rapidly or overlaps | No unintended duplicate grant or negative balance |
| ProximityPrompt | Trigger hold/end callbacks remotely or too quickly | Server does not grant action based on client-only distance, enabled, or hold state |
| ClickDetector | Trigger far away or repeatedly | Consequential action checks server distance, permission, and rate |
| Profile load | Storage read fails | Existing progress cannot be overwritten by fallback defaults |
| Profile save | Older save retries after a newer save | Older state does not silently replace newer progress |
| Character setup | Several respawns followed by teardown | Only the intended active handlers/tasks remain |

Adapt these to the actual game. They are not proof of complete security or durability.

For a broad review, summarize coverage by area without assigning a combined score. For example, if only shop scripts were supplied, mark the shop as reviewed statically with those paths and add a separate `Needs Studio` note naming the runtime check; mark persistence as not assessed because its files were not supplied. Do not infer that an uninspected system does not exist. Omit areas that are irrelevant to the requested scope.

| Monetization | Scenario | Expected property |
| --- | --- | --- |
| Developer product | Same `PurchaseId` is delivered twice or callback transform is retried | Benefit is recorded once; transform has no repeated external side effect |
| Developer product | Profile write fails, player is absent, then processing retries | Receipt remains unacknowledged until grant is safely recorded |
| Receipt routing | Filtered `BindReceiptHandler` and fallback `ProcessReceipt` coexist | Each product reaches its intended handler; no unhandled product or duplicate grant |
| Game pass | Client reports purchase success, or ownership lookup fails | The server does not grant from the client signal alone; failed lookup remains unknown and does not create permanent value |
| Game pass trial | A trial provides access while the game also grants saved currency, items, or unlocks | Use `Active` for temporary access and `Owned` for permanent saved benefits; a trial alone must not create a permanent grant |
| Third-party model | Inserted model contains scripts or powerful capabilities | Trace reachable behavior and permissions; suspicious appearance alone is not labeled a confirmed backdoor |
