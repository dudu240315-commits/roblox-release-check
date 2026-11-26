-- NEGATIVE TESTS: deliberately defective local functions below. Not reusable game code.
local RunService = game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), 'Studio Play only')
-- Run on the server in an isolated Studio Play session.
-- Synthetic in-memory fixtures only; no DataStoreService access.
local results = {}
local cleanupRuns = 0
local function parallelBuy(fixed, injectFailure, timeoutSeconds)
    local balance, grants, done = 150, 0, 0
    local gate = Instance.new('BindableEvent')
    local ready, threads, failures = 0, {}, {}
    for index = 1, 2 do
        threads[index] = task.spawn(function()
            local ok, message = pcall(function()
                if injectFailure == true and index == 1 then error('injected pre-ready error') end
                if injectFailure == 'readiness-timeout' and index == 1 then task.wait(1) end
                local eligible = balance >= 100
                ready += 1
                gate.Event:Wait()
                if injectFailure == 'completion-timeout' and index == 1 then task.wait(1) end
                if fixed then eligible = balance >= 100 end
                if eligible then balance -= 100; grants += 1 end
            end)
            if not ok then failures[#failures+1] = tostring(message) end
            done += 1
        end)
    end
    local deadline = os.clock() + (timeoutSeconds or 5)
    while ready < 2 and #failures == 0 and os.clock() < deadline do task.wait() end
    if ready == 2 and #failures == 0 then
        gate:Fire()
        deadline = os.clock() + (timeoutSeconds or 5)
        while done < 2 and #failures == 0 and os.clock() < deadline do task.wait() end
    end
    -- Always release fixture resources before surfacing worker errors or timeouts.
    for _, thread in threads do
        if coroutine.status(thread) ~= 'dead' then task.cancel(thread) end
    end
    gate:Destroy()
    for _, thread in threads do assert(coroutine.status(thread) == 'dead', 'worker survived cleanup') end
    cleanupRuns += 1
    assert(#failures == 0, table.concat(failures, '\n'))
    assert(ready == 2 and done == 2, 'workers timed out')
    return balance, grants
end
local caught, message = pcall(function() parallelBuy(true, true) end)
assert(not caught and string.find(tostring(message), 'injected pre-ready error', 1, true))
assert(cleanupRuns == 1, 'failure path skipped cleanup')
for _, mode in {'readiness-timeout', 'completion-timeout'} do
    caught, message = pcall(function() parallelBuy(true, mode, 0.03) end)
    assert(not caught and string.find(tostring(message), 'workers timed out', 1, true))
end
assert(cleanupRuns == 3, 'timeout path skipped cleanup')
results.timeoutCleanup = 'readiness and completion timeouts cleaned all workers'
results.failureCleanup = 'injected worker error reported; all workers canceled and gate destroyed'
local b, g = parallelBuy(false)
assert(b == -50 and g == 2, 'expected stale-check defect')
b, g = parallelBuy(true)
assert(b == 50 and g == 1, 'revalidation must prevent double grant')
results.concurrentFirstPurchase = 'defect reproduced; correction passed'

-- In-memory compare-and-set exercise, not DataStoreService or session locking.
local stored = {coins = 5000, revision = 2}
local stale = {coins = 100, revision = 1}
local function update(transform)
    local nextValue = transform(stored)
    if nextValue ~= nil then stored = nextValue end
    return nextValue ~= nil
end
update(function(_) return stale end)
assert(stored.coins == 100, 'unguarded stale snapshot must reproduce overwrite')
stored = {coins = 5000, revision = 2}
local function guardedTransform(current, snapshot)
    if current.revision ~= snapshot.revision then return nil end
    return {coins = snapshot.coins, revision = current.revision + 1}
end
local function saveSnapshot(snapshot)
    return update(function(current) return guardedTransform(current, snapshot) end)
end
assert(not saveSnapshot(stale), 'stale snapshot must be rejected')
assert(stored.coins == 5000 and stored.revision == 2, 'stale rejection must preserve stored state')
local fresh = {coins = 5200, revision = 2}
assert(saveSnapshot(fresh), 'matching revision must save')
assert(stored.coins == 5200 and stored.revision == 3, 'accepted save must advance revision')
assert(fresh.revision == 2, 'save must not mutate input snapshot')
assert(not saveSnapshot(fresh), 'replayed old revision must be rejected')
assert(stored.coins == 5200 and stored.revision == 3, 'replay must preserve accepted state')
assert(saveSnapshot({coins = 5300, revision = 3}), 'next matching revision must save')
assert(stored.coins == 5300 and stored.revision == 4, 'next save must advance revision again')
results.staleSnapshot = 'mock overwrite reproduced; stale and replayed revisions rejected'
results.validSnapshot = 'matching revisions saved, advanced version, and preserved input snapshots'

local connections = {}
for _ = 1, 3 do
    local character = Instance.new('Model')
    connections[#connections + 1] = RunService.Heartbeat:Connect(function()
        local _name = character.Name
    end)
    character:Destroy()
end
local active = 0
for _, connection in connections do
    if connection.Connected then active += 1 end
    connection:Disconnect()
end
assert(active == 3, 'captured model destruction should not clean service listener')
for _, connection in connections do assert(not connection.Connected) end
results.repeatedLifecycle = '3 stale listeners reproduced; explicit teardown passed'
results.limitations = 'Synthetic functions; no remote transport, real respawn, or real persistence in this suite'
print("[Roblox Release Check] "..game:GetService("HttpService"):JSONEncode(results))
return results
