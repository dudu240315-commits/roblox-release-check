# Mutation controls

These controls test whether the regression suite notices specific defects. They do not measure whether the AI skill independently discovers unfamiliar bugs.

1. Run the `full`, `maximum-quantity`, and `distinct-purchases` client scenarios against the unchanged packaged server in separate fresh Studio Play sessions; all must pass.
2. Keep the packaged files unchanged. In a separate disposable Studio place, change only the indicated text in the server Script. The before-text must match exactly once. Apply one mutation per fresh Play session.
3. For the startup control, confirm the named assertion in server Output and confirm `ReleaseSecurityProbe` was not created. For other controls, execute the specified client scenario and match the named assertion. A syntax error, unrelated exception, or timeout is inconclusive, not detection.
4. Stop Play and restore the original server Script after every experiment, including failed experiments. After the last experiment, run all three baseline scenarios again, then stop Play.

| Control | Before | After | Scenario | Expected diagnostic |
| --- | --- | --- | --- | --- |
| limiter disconnected | `if not allow(state, now) then return reply(false, 'rate') end` | `if false then return reply(false, 'rate') end` | Server startup | `handler limiter enforcement missing` |
| forged owner allowed | `if request.target ~= actorId then return reply(false, 'owner') end` | `if request.target == nil then return reply(false, 'owner') end` | full | `forged owner: expected owner, got purchased` |
| fractional quantity allowed | ` or n % 1 ~= 0` | *(delete this exact substring)* | full | `fractional: expected quantity, got purchased` |
| replay lookup removed | `local previous = state.seen[id]` | `local previous = nil` | full | `duplicate purchase must not grant twice` |
| valid maximum ID rejected | `#id > 32` | `#id >= 32` | maximum-quantity | `valid maximum boundaries rejected` |

The limiter-disconnected control survived the older suite: helper arithmetic passed even though the handler did not enforce it. The current suite checks the same handler under a controlled clock before exposing the remote, and detects that mutation. No vulnerable variant is enabled in the packaged server.

