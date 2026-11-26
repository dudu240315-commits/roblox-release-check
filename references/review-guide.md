# Focused review guide

Use only the sections relevant to the reviewed feature. These are investigation prompts, not automatic findings.

## Change-set review

When given a diff or before/after versions, review the changed paths first, then trace only the callers, callees, configuration, or data flow needed to establish impact. Compare the base and proposed behavior before labeling a finding as introduced by the change. If the base version is unavailable, mark introduction status as unknown. Keep pre-existing risks separate and include them only when they affect the changed feature or release decision. Do not treat unchanged lines shown as context as newly introduced defects.

## Information exposed to clients

For data with a real confidentiality requirement, trace where it is parented and sent, and which clients can receive it. Check `ReplicatedStorage`, `ReplicatedFirst`, `Workspace`, player/character instances, attributes, client-visible ModuleScripts, and `RemoteEvent`/`RemoteFunction` responses. Account for the actual recipient: `FireAllClients` exposes data more broadly than `FireClient`, while a client can inspect any content that has replicated to it. Server-only logic and values belong in server-only containers such as `ServerScriptService` or `ServerStorage`; a server check inside a replicated ModuleScript does not hide that module's source.

Do not report a value merely because it replicates. Names, scores, currency, loadouts, and other values intended for a leaderboard or UI are not confidentiality findings by themselves. Establish what information is meant to stay private, show the code path and recipient that exposes it, and explain the practical impact. A full profile sent for a small UI may expose unrelated flags or private fields; recommend returning only the fields the UI needs. An `admin` flag alone does not prove privilege escalation: if it only affects UI, assess confidentiality separately; if a client-side permission gate relies on it, trace whether the server independently enforces that permission. If ancestry or recipients cannot be established from the supplied files, mark exposure as unassessed and name the Studio check needed.

Sources: [Access control and confidentiality](https://create.roblox.com/docs/scripting/security/access-control), [Data model](https://create.roblox.com/docs/projects/data-model), [Remote events and callbacks](https://create.roblox.com/docs/scripting/events/remote).

## Client-server boundary

Trace remote input through server helpers. Check types, finite numeric values, bounds, instance ancestry, ownership, current gameplay state, and permission to perform the action. Treat prices, reward amounts, and damage supplied by the client as claims to verify against server rules. Check rate limits on the server where repeated requests could cause harm; a UI cooldown is insufficient evidence of server protection. Account for legitimate bursts before proposing a limit.

Source: [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary).

## Player-written text and chat surfaces

Trace text from a player input through remotes, storage, and every place another player can see it. For editable text that is not chat (for example signs, pet names, or a one-way bulletin board), verify the server calls `TextService:FilterStringAsync()` and only displays a filtered result. Use `TextFilterResult:GetNonChatStringForBroadcastAsync()` when all viewers should receive the same filtered text, or `GetNonChatStringForUserAsync()` when the text is intended for a specific viewer. If filtering fails, do not display the raw or partially filtered input. If player text is persisted, keep the original on the server only as needed and filter it again when loading/displaying it to the intended audience; a result filtered for one audience or at save time is not automatically suitable for every later viewer. Preserve the author identity needed to filter stored text correctly, and never send the unfiltered stored value to clients.

Enforce at least a 60-second per-player server-side submission interval for each editable non-chat surface visible to others. A client-only timer is not sufficient. If a feature allows players to exchange messages or replies in under 60 seconds, or otherwise acts as a conversation surface (such as direct messages, radios, phones, or chat-like admin tools), it must use `TextChatService`; filtering and a cooldown alone do not make an alternate chat system acceptable. Preset phrases from a fixed list and developer-controlled one-way text are distinct cases and do not need custom text filtering.

`TextService:FilterStringAsync()` yields. Check whether the rate-limit check and update can interleave with another submission from the same player. Reserve/serialize the submission before yielding, or otherwise revalidate before accepting it; two concurrent requests must not both pass using the same old cooldown state. Ensure filter failures clear any in-progress lock and never expose raw text.

Do not report a missing manual filter call for messages handled by `TextChatService`, which applies chat filtering automatically. Do not require filtering for static developer-authored text. Report a concrete path that exposes player-written text without successful server filtering, a client-only cooldown on a qualifying editable text surface, or an alternate system that permits conversation outside `TextChatService`. If the surface's interaction timing or audience is unclear, ask how players can use it before classifying it.

For verification, submit ordinary and disallowed/personal text through the actual server handler; confirm only returned filtered text reaches other players, filter errors fail closed, two simultaneous submissions from one player cannot both pass the same cooldown, sequential rapid repeats are rejected server-side, and an interval at or above 60 seconds works. For chat, verify communication goes through `TextChatService` and its delivery/permission behavior. Use mocks for local code-path checks where appropriate; mocks do not validate Roblox moderation outcomes.

Sources: [Chat system guidelines](https://create.roblox.com/docs/chat/guidelines), [Text filtering](https://create.roblox.com/docs/ui/text-filtering), [Text filtering and safety](https://create.roblox.com/docs/safety), [Text chat overview](https://create.roblox.com/docs/chat/in-experience-text-chat), [TextService:FilterStringAsync](https://create.roblox.com/docs/reference/engine/classes/TextService/FilterStringAsync), [TextFilterResult](https://create.roblox.com/docs/reference/engine/classes/TextFilterResult).

## Cross-server state and messaging

When servers coordinate through `MessagingService` or `MemoryStoreService`, trace the publisher/request through the topic, map, or queue to every subscriber/consumer and the resulting game-state change. Treat payload fields, player IDs, and message timing as input to validate; a message from another server is not by itself proof of a player's current permission, balance, or ownership. If the message triggers a consequential action, re-check the authoritative state or durable record at the point of mutation.

`MessagingService` delivery is best effort and not guaranteed. Use it for notifications or cache refreshes only when a missed message is safe; do not make a permanent purchase, trade, reward, or access decision depend solely on one message arriving. For data that must survive sessions or temporary-store expiry, use an appropriate durable source such as a DataStore and treat messaging as a signal to refresh/reconcile. Do not report best-effort delivery as a defect when the feature degrades safely or the message is only informational.

`MemoryStoreService` is temporary shared state, not durable player storage. Check that expiration matches the feature's lifetime and that consumers handle missing/expired data. For state-dependent concurrent writes, inspect whether an atomic update such as `UpdateAsync` is needed; do not require it for independent writes. For queues, trace the invisibility timeout and removal: if a worker performs an effect but fails before removing the item, the item can become available again after the timeout. Make consequential processing idempotent or verify a durable deduplication record before applying an irreversible effect. Clean up processed items when appropriate, but do not demand a short TTL for intentionally longer-lived temporary state.

For verification, test missing, delayed, malformed, and repeated notifications; confirm non-critical consumers recover without treating messages as durable. For queues, exercise failure before the effect, after the effect but before removal, and after removal; a repeated item must not duplicate a consequential grant/trade. For maps with competing updates, test simultaneous writes and expiration. Use mocks where possible, and label them as local logic checks rather than proof of Roblox delivery or cross-server guarantees.

Sources: [Cross-server messaging](https://create.roblox.com/docs/cloud-services/cross-server-messaging), [MessagingService](https://create.roblox.com/docs/reference/engine/classes/MessagingService), [Memory stores](https://create.roblox.com/docs/cloud-services/memory-stores), [Memory store queues](https://create.roblox.com/docs/cloud-services/memory-stores/queue), [Memory store best practices](https://create.roblox.com/docs/cloud-services/memory-stores/best-practices).

Bind authority to the player supplied by the engine to the server callback, not a caller-supplied user ID. A target ID is not automatically wrong: trades, combat, and gifts need explicit permission rules. Test forged targets against those rules. Validate integer quantities separately from finite numbers; range rejection alone can let NaN through. Bound strings and table structure before expensive processing where payload size drives work.

For actions intended to happen once, test replay with the same action ID and overlapping requests. Distinct legitimate repeat purchases should remain possible when the game allows them. Scope deduplication and rate state appropriately to the player/action, bound retained state, and inspect cleanup. Do not turn a test-only lifetime request budget into a production limiter; test recovery after the intended cooldown/refill.

### Client-triggered instances

Include `ProximityPrompt`, `ClickDetector`, and `DragDetector` server handlers in the client/server trace; they can trigger gameplay code without a RemoteEvent. For every consequential handler, verify server-owned player state, permission, current character, meaningful distance, and server-side rate limits. Do not treat client-visible `Enabled`, `MaxActivationDistance`, `RequiresLineOfSight`, or hold duration as authorization. Roblox documents that only `ProximityPrompt.Triggered` has an engine-side server distance check; other prompt hold/end events do not. ClickDetector events have no server-side distance checks. For DragDetector, distinguish the server-checked dragging permissions from inherited ClickDetector events and other unchecked properties. If an unanchored assembly can be moved by its network owner, account for that when trusting distance. Validate actual event connections and their effects before reporting a vulnerability; a decorative prompt with no consequential handler is not itself a security finding.

Sources: [Securing the client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary), [Network ownership, movement validation, and physics](https://create.roblox.com/docs/scripting/security/network-ownership).

## Third-party models and packages

When a project contains Creator Store/Toolbox models or packages, inspect the scripts they add and trace any dynamic code loading or powerful capabilities to their reachable effects. Treat obfuscation, an unfamiliar creator, or an asset ID passed to `require` as a reason to inspect provenance and behavior, not proof of a backdoor. Report confirmed impact only when the code path can affect server state, data, networking, or other project code; otherwise list the asset/source as an unverified review question. If Studio exposes script sandboxing/capabilities, compare granted permissions with what the asset needs and verify current behavior in official documentation.

Sources: [Vulnerabilities from third-party assets](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities), [Toolbox](https://create.roblox.com/docs/projects/assets/toolbox), [Script Capabilities](https://create.roblox.com/docs/scripting/capabilities).

## HTTP and external services

When a game server calls external services with `HttpService`, trace client input through the request URL, method, headers, body, and any response that changes game state. Check whether a client can choose or influence the destination or sensitive request fields; constrain destinations to the intended service and validate inputs before sending them. Keep API keys and tokens in Roblox Secrets, retrieve them from server scripts, and restrict each secret to the specific domain it needs. Never put credentials in LocalScripts, replicated modules, client-visible values, logs, or fixtures.

Treat external responses as untrusted input. Check the request result/status and validate the expected response shape, types, ranges, and authorization before using it to grant currency, items, or access. Handle transport errors and unsuccessful HTTP responses according to the feature's fallback behavior. Retries are not required for every request; where a retry is appropriate, bound attempts and delay, respect service rate limits, and make non-idempotent effects safe against duplicate processing. Avoid logging secrets or unnecessary player data.

Do not report merely because HTTP is enabled, an endpoint is public, a response is not JSON, `pcall` is absent, or a request has no retry. Report a concrete exposed credential/data flow, uncontrolled destination that enables unintended requests, unvalidated response that affects important server state, or failure/retry path with a demonstrated harmful effect. If the service contract or destination is unavailable, mark the concern unassessed or uncertain rather than assuming a vulnerability.

For verification, use a mock or stub service: cover a valid response, malformed response, unsuccessful status, timeout, and retry of a non-idempotent action. Confirm that invalid/failing responses do not grant benefits and retries do not duplicate them. Check that clients cannot read the secret. These checks do not require a live endpoint and do not prove the external service's behavior.

Sources: [In-game HTTP requests](https://create.roblox.com/docs/cloud-services/http-service), [Secrets stores](https://create.roblox.com/docs/cloud-services/secrets), [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService).

## Game passes

Trace a pass from purchase prompt and server-side ownership lookup to the benefit grant and every later use of that benefit. Do not grant permanent value solely because a client reports purchase success; `PromptGamePassPurchaseFinished` can also report success when a free trial starts. Treat a failed ownership lookup as unknown: do not grant from it, and allow a later check to retry. If free trials are enabled, use `UserOwnsGamePassAsync` or the `Active` field for temporary access, but require `GetPassOwnershipAsync(...).Owned` before saving permanent items, currency, or unlocks. Recheck ownership when access matters instead of caching it for the full session, because trial access can end. Verify the current Creator Hub guidance before applying these APIs, as pass and trial behavior can change. This is a manual review scenario; the package does not include an automated Game Pass fixture.

Sources: [Passes](https://create.roblox.com/docs/production/monetization/passes), [MarketplaceService](https://create.roblox.com/docs/reference/engine/classes/MarketplaceService).

## Paid random items and per-player monetization policy

When a game has a random reward generator, trace the cost source (Robux or currency purchasable with Robux), the random outcome, the displayed odds, the grant, and any later trade. Do not assume a chest, egg, or wheel is a paid random item until the currency path is established. If users can spend Robux or Robux-purchased currency for a random outcome, verify all possible final outcomes and their numerical percentage odds are available before spending; verify the displayed percentages sum to 100% subject to Roblox's documented rounding allowance. Check the actual odds for that player when luck boosts, pity, unique remaining outcomes, or other modifiers change them; disclose modified odds before purchase.

Check `PolicyService:GetPolicyInfoForPlayerAsync()` for the player whose action is being authorized. If `ArePaidRandomItemsRestricted` is true, the paid random generator must not be available to that player; review the chosen compliant alternative or block path. If `IsPaidItemTradingAllowed` is false, do not allow that player to access trading of paid items or paid-random-item outcomes. Treat client-supplied policy booleans as display hints, not authorization. Because the policy lookup is asynchronous and can fail, verify the server handles failure without assuming the player is unrestricted; do not enable the restricted purchase/trade until eligibility is known.

Do not report missing paid odds for random rewards earned without Robux or Robux-purchased currency. Do not treat every loot box as paid without tracing its currency source. Do not require fixed odds when the odds legitimately vary and the current numerical odds are accurately disclosed before each purchase. If the economy's currency provenance or the effective odds cannot be established from supplied code/UI, mark that part unassessed and request the missing configuration rather than asserting noncompliance.

For verification, test paid and earn-only currency paths separately; compare displayed outcomes and odds with the server's actual outcome weights, including active modifiers and remaining-item cases. Mock policy results for restricted/allowed/error states and test that generator/trade access follows the server result. No real purchase is needed.

Sources: [Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items), [PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService), [Monetization guidelines](https://create.roblox.com/docs/production/monetization).

## Teleports between places and servers

When an experience moves players between places or servers, trace the source `TeleportAsync` call through destination-side `Player:GetJoinData()` and any client use of `GetLocalPlayerTeleportData()` or `TeleportService` settings. `GetJoinData()` can provide server-verified `SourcePlaceId`/`SourceGameId` for allowlist checks, but an approved source proves only where the data came from, not that every field is valid or that a reward is deserved. `TeleportData` is visible to the client and may still be abused. Use it only for non-sensitive context such as a map choice or display preference. Do not use it alone to grant currency, inventory, paid benefits, or elevated access; confirm critical state through a server-owned data source and validate the player's eligibility in the destination. Review the experience's Access Control for Places setting when some subplaces are progression-gated or private; do not insist on a restrictive setting if open access is intentional. Protect reserved-server access material, validate destination IDs against the experience's intended places, and handle teleport failures without duplicating grants or leaving the player in an inconsistent state. If code or place mappings for either side are missing, report the cross-place flow as not fully assessed rather than assuming the payload is trusted.

For runtime verification, the current `TeleportAsync()` flow can be tested in Studio Test and Team Test without publishing. These modes do not support deprecated teleport methods; they also differ from production for `PrivateServerId`/`JobId`, and VIP teleports fail in testing. Keep those limitations in mind when interpreting results, and check the current Creator Hub guide before choosing a test mode.

Sources: [Teleport between places](https://create.roblox.com/docs/projects/teleport), [TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService), [Player:GetJoinData](https://create.roblox.com/docs/reference/engine/classes/Player#GetJoinData).

Check the contract for reusing an action ID with a different payload: reject the conflict or return the original outcome consistently, rather than execute a different action under the same identity. Test that rejected requests do not consume IDs unless the protocol intentionally specifies that behavior. Include exact-balance purchases and legitimate purchases with distinct IDs as positive controls.

Trace yields and asynchronous helper calls between validation and mutation. Determine whether overlapping requests can both pass a balance, ownership, or availability check before either commits. Recommend serialization or revalidation only when this interleaving is reachable; do not assume every handler overlaps at every statement.

## Persistence

Establish what the stored data means before applying profile durability requirements. Disposable diagnostics and intentionally session-only state do not automatically need profile locking, autosave, or progress recovery. Trace actual consumers and writes; comments describe intent but are not proof of behavior.

Distinguish a successful missing-key load from a failed load; investigate whether fallback defaults could overwrite existing data. Trace error handling and ordered, bounded retries. Check whether stale sessions can overwrite newer progress and whether the project already handles session ownership.

Use UpdateAsync when an update depends on the stored value. Its callback can run more than once and cannot yield: investigate rewards or other side effects inside it. UpdateAsync alone does not make a stale full-profile replacement safe. Do not flag every SetAsync call: replacing a value independent of its previous state can be intentional. Look for autosave, departure, and shutdown behavior without assuming any one hook guarantees durability.

Sources: [Data stores](https://create.roblox.com/docs/cloud-services/data-stores), [Best practices](https://create.roblox.com/docs/cloud-services/data-stores/best-practices), [GlobalDataStore](https://create.roblox.com/docs/reference/engine/classes/GlobalDataStore).

### Profile schema changes and migrations

When a release changes a saved profile shape, trace a real legacy profile from load through conversion to write. Check that conversion preserves unrelated progress, can safely run again after a failed or interrupted write, and does not mark a profile migrated before the converted value is successfully persisted. Do not replace an unexpected or failed-to-load profile with defaults unless the code has established it is genuinely new; fail safely or defer the write when the old shape is unknown. If older and newer server code can overlap, check whether an older save can overwrite the new shape. A schema-version field is useful but not mandatory; its absence alone is not a finding.

For a meaningful migration, use representative old/current profile fixtures and verify: old profile converts once; a second run leaves it unchanged; a failure before persistence can be retried without loss or duplicate transformation; and unknown/corrupt data is not silently reset. These are review/test suggestions, not automated fixtures in this package. Before a broad data-shape rollout, review the available backup/restore plan. Roblox DataStore version history is not a backup of every write: it keeps the first write to a key per UTC hour, later writes in that hour can replace that version, and overwritten versions expire after 30 days.

Sources: [Best practices for data stores](https://create.roblox.com/docs/cloud-services/data-stores/best-practices), [Data store versioning, listing, and caching](https://create.roblox.com/docs/cloud-services/data-stores/versioning-listing-and-caching), [Open Cloud data stores](https://create.roblox.com/docs/cloud/guides/data-stores).

## Developer product receipts

When developer products are in scope, trace the actual `MarketplaceService.ProcessReceipt` and any `BindReceiptHandler` routing through each server-owned grant rule. Filtered bound handlers can take precedence while unmatched receipts fall through to `ProcessReceipt`; don't report missing coverage until routing is followed. Do not treat `PromptProductPurchaseFinished` as proof of purchase. Roblox documents receipt callbacks can be delivered out of order or overlap across servers; check duplicate `PurchaseId` handling against the project's persistence/session design. For legacy `ProcessReceipt`, a `NotProcessedYet` result leaves a receipt unresolved but Roblox does not retry it on a time-based schedule: on the same server, it is called again only after the player successfully initiates another developer product purchase or rejoins any server in the experience. Do not promise an immediate retry after a failed write. Avoid external balance or inventory side effects inside an `UpdateAsync` transform because Roblox may call the transform more than once. Confirm a receipt is acknowledged only after the benefit is safely recorded. Trace handler ownership before reporting multiple callbacks or missing coverage.

Use isolated mocks for duplicate and reordered receipts: a repeat must not grant twice, a failed write must not acknowledge an unrecorded grant, and recovery on a later legitimate callback should allow one successful grant. Exercise callback re-invocation to catch side effects in an `UpdateAsync` transform, and verify absent-player handling returns a retryable result without assuming when Roblox will invoke it again. A mock verifies local decisions, not platform callback timing, cross-server atomicity, or real DataStore guarantees. Never issue real Robux purchases as a code test.

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
| Player-written text | Filter succeeds/fails; player submits twice rapidly to a public sign or pet-name surface | Only filtered text is shown; failure shows no raw input; server enforces at least 60 seconds per player |
| Player-written text concurrency | Same player submits twice while server filtering yields | At most one submission passes the server cooldown; failure clears in-progress state without showing raw text |
| Stored player text | Text is saved then later shown to a different or age-restricted viewer | Server filters on retrieval for the intended audience; raw stored input never reaches a client |
| Chat surface | Players can reply or exchange messages through a custom UI | Conversation uses `TextChatService`; non-chat filtering alone is not treated as sufficient |
| Inventory | Same request repeats rapidly or overlaps | No unintended duplicate grant or negative balance |
| ProximityPrompt | Trigger hold/end callbacks remotely or too quickly | Server does not grant action based on client-only distance, enabled, or hold state |
| ClickDetector | Trigger far away or repeatedly | Consequential action checks server distance, permission, and rate |
| Profile load | Storage read fails | Existing progress cannot be overwritten by fallback defaults |
| Profile save | Older save retries after a newer save | Older state does not silently replace newer progress |
| Profile migration | Legacy profile migrates; write fails; migration retries | Existing fields remain intact; retry is safe; unknown schema is not silently replaced by defaults |
| HTTP integration | Mock valid/malformed response, error status, timeout, and retry | Untrusted responses do not grant benefits; retry does not duplicate a non-idempotent effect; secret stays server-only |
| Cross-server state | Message is missed/duplicated; queue worker fails before or after an effect | Notifications can be reconciled; repeated consequential work is idempotent; temporary state isn't assumed durable |
| Paid random item | Purchase uses Robux or purchased currency, including an active odds modifier | All outcomes and current numerical odds are disclosed before spend; policy restriction is enforced by the server |
| Character setup | Several respawns followed by teardown | Only the intended active handlers/tasks remain |

Adapt these to the actual game. They are not proof of complete security or durability.

For a broad review, summarize coverage by area without assigning a combined score. For example, if only shop scripts were supplied, mark the shop as reviewed statically with those paths and add a separate `Needs Studio` note naming the runtime check; mark persistence as not assessed because its files were not supplied. Do not infer that an uninspected system does not exist. Omit areas that are irrelevant to the requested scope.

| Monetization | Scenario | Expected property |
| --- | --- | --- |
| Developer product | Same `PurchaseId` is delivered twice or callback transform is retried | Benefit is recorded once; transform has no repeated external side effect |
| Developer product | Write fails and handler returns `NotProcessedYet`; player later rejoins or successfully initiates another product purchase | Receipt remains unacknowledged until grant is safely recorded; no fixed-time retry is assumed |
| Receipt routing | Filtered `BindReceiptHandler` and fallback `ProcessReceipt` coexist | Each product reaches its intended handler; no unhandled product or duplicate grant |
| Game pass | Client reports purchase success, but server ownership lookup returns false or errors | No permanent grant from the client signal; false means not confirmed, error remains unknown and can be retried |
| Game pass trial | A trial provides access while the game also grants saved currency, items, or unlocks | Use `Active` for temporary access and `Owned` for permanent saved benefits; a trial alone must not create a permanent grant |
| Paid random item | Player is restricted by `ArePaidRandomItemsRestricted`, or trading is disallowed by `IsPaidItemTradingAllowed` | Server blocks the affected generator/trade or applies a compliant alternative |
| Third-party model | Inserted model contains scripts or powerful capabilities | Trace reachable behavior and permissions; suspicious appearance alone is not labeled a confirmed backdoor |
| Private profile data | Server shares a profile to render one UI field | Client receives only intended public fields; private flags or unrelated profile fields remain server-side |
| Teleport data | Source place sends currency or an access flag to the destination | Destination verifies critical state and permission server-side; plain teleport context is not accepted as authority |
| Restricted subplace | Client attempts to join a progression-gated place without following the intended game flow | Place access settings and destination server checks match the intended design; open access is not flagged when intentional |

