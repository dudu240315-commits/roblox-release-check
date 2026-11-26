-- Execute in Client context after security-server is running in a fresh Play session.
local RunService = game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsClient(), 'Studio Play only')
local TEST_SCENARIO = "full" -- Also "maximum-quantity" or "distinct-purchases"; each needs fresh Play.
assert(TEST_SCENARIO == "full" or TEST_SCENARIO == "maximum-quantity" or TEST_SCENARIO == "distinct-purchases", "unknown scenario")
local function finish(report)
    print("[Roblox Release Check] "..game:GetService("HttpService"):JSONEncode(report))
    return report
end
local remote = game.ReplicatedStorage:WaitForChild('ReleaseSecurityProbe',10)
assert(remote and remote:IsA('RemoteFunction'), 'missing test RemoteFunction')

local function cancelPending(threads)
    for _, thread in threads do
        if coroutine.status(thread) ~= 'dead' then task.cancel(thread) end
    end
end
local function boundedCall(callback, seconds, ownedChildren)
    local complete, ok, value = false, false, nil
    local thread = task.spawn(function()
        ok, value = pcall(callback)
        complete = true
    end)
    if ownedChildren then ownedChildren[#ownedChildren + 1] = thread end
    local deadline = os.clock() + seconds
    while not complete and os.clock() < deadline do task.wait() end
    if not complete then
        cancelPending({thread})
        -- Canceling the client waiter does not cancel server work already in progress.
        error('request timeout; stop Play and restart before rerunning', 0)
    end
    assert(ok, tostring(value))
    return value
end
local function batch(count, callback, seconds)
    local done, values, failures, threads, children = 0, {}, {}, {}, {}
    for index = 1, count do
        threads[index] = task.spawn(function()
            local ok, value = pcall(callback, index, children)
            if ok then values[index] = value
            else failures[#failures + 1] = 'worker '..index..': '..tostring(value) end
            done += 1
        end)
    end
    local deadline = os.clock() + seconds
    while done < count and os.clock() < deadline do task.wait() end
    cancelPending(threads)
    cancelPending(children)
    for _, child in children do assert(coroutine.status(child) == 'dead', 'child survived cleanup') end
    if done < count then failures[#failures + 1] = 'batch timeout; restart Play' end
    assert(#failures == 0, table.concat(failures, '\n'))
    return values
end
local function validateReply(value)
    assert(typeof(value) == 'table', 'malformed response: expected table')
    assert(typeof(value.ok) == 'boolean' and typeof(value.reason) == 'string', 'malformed response status')
    assert(value.ok == (value.reason == 'purchased'), 'response success/reason mismatch')
    assert(typeof(value.balance) == 'number' and typeof(value.grants) == 'number', 'malformed response state')
    return value
end
-- Check the failure paths of the harness itself without touching game state.
local caught, message = pcall(function()
    batch(2, function() return validateReply(nil) end, 1)
end)
assert(not caught and string.find(tostring(message), 'malformed response', 1, true))
caught, message = pcall(function()
    boundedCall(function() task.wait(1) end, 0.03)
end)
assert(not caught and string.find(tostring(message), 'request timeout', 1, true))
local ownedChildren
caught, message = pcall(function()
    batch(1, function(_, children)
        ownedChildren = children
        boundedCall(function() task.wait(1) end, 2, children)
    end, 0.03)
end)
assert(not caught and string.find(tostring(message), 'batch timeout', 1, true))
assert(ownedChildren and #ownedChildren == 1 and coroutine.status(ownedChildren[1]) == 'dead', 'nested timeout left a child')
local function invoke(payload, children)
    return validateReply(boundedCall(function() return remote:InvokeServer(payload) end, 5, children))
end

local uid = game.Players.LocalPlayer.UserId
local function request(overrides)
    local value = {target=uid, item='Sword', quantity=1, id='first'}
    for key, data in pairs(overrides or {}) do value[key] = data end
    return value
end
if TEST_SCENARIO == 'distinct-purchases' then
    local replies = batch(8, function(index, children)
        return invoke(request({id='distinct-'..index}), children)
    end, 10)
    local purchased, rejected, snapshots = 0, 0, {}
    for _, reply in replies do
        if reply.ok then
            assert(reply.reason == 'purchased' and reply.grants >= 1 and reply.grants <= 5
                and reply.grants % 1 == 0 and reply.balance == 500-100*reply.grants,
                'distinct purchase snapshot must match one authoritative charge')
            assert(not snapshots[reply.grants], 'distinct purchase snapshots must not duplicate')
            snapshots[reply.grants] = true
            purchased += 1
        else
            assert(reply.reason == 'funds' and reply.balance == 0 and reply.grants == 5,
                'distinct purchase may fail only for exhausted balance')
            rejected += 1
        end
    end
    assert(purchased == 5 and rejected == 3, 'distinct purchases must consume exactly available balance')
    for grant=1,5 do assert(snapshots[grant], 'missing committed purchase snapshot') end
    local final = invoke(request({id='after-distinct'}))
    assert(not final.ok and final.reason == 'funds' and final.balance == 0 and final.grants == 5,
        'concurrent purchases must leave a consistent final balance')
    return finish({scenario=TEST_SCENARIO, concurrentRequests=8, purchases=purchased,
        insufficientFunds=rejected, finalBalance=0, finalGrants=5})
end
if TEST_SCENARIO == 'maximum-quantity' then
    local payload = request({quantity=5, id=string.rep('x',32)})
    local maximum = invoke(payload)
    assert(maximum.ok and maximum.balance==0 and maximum.grants==5, 'valid maximum boundaries rejected')
    local duplicate = invoke(payload)
    assert(not duplicate.ok and duplicate.reason=='replay' and duplicate.balance==0 and duplicate.grants==5)
    return finish({scenario=TEST_SCENARIO, maximumQuantity=5, maximumIdBytes=32, exactBalance=true, replayRejected=true})
end
local function missing(field)
    local value = request()
    value[field] = nil
    return value
end
local invalid = {
    {name='boolean', payload=false, reason='schema'},
    {name='string', payload='not a request', reason='schema'},
    {name='empty table', payload={}, reason='owner'},
    {name='forged owner', payload=request({target=uid+1}), reason='owner'},
    {name='unknown item', payload=request({item='AdminSword'}), reason='item'},
    {name='zero', payload=request({quantity=0}), reason='quantity'},
    {name='negative', payload=request({quantity=-1}), reason='quantity'},
    {name='NaN', payload=request({quantity=0/0}), reason='quantity'},
    {name='infinity', payload=request({quantity=math.huge}), reason='quantity'},
    {name='negative infinity', payload=request({quantity=-math.huge}), reason='quantity'},
    {name='fractional', payload=request({quantity=1.5}), reason='quantity'},
    {name='over maximum', payload=request({quantity=6}), reason='quantity'},
    {name='numeric string', payload=request({quantity='1'}), reason='quantity'},
    {name='long ID', payload=request({id=string.rep('x',33)}), reason='id'},
    {name='extra price', payload=request({price=0}), reason='schema'},
    {name='table ID', payload=request({id={}}), reason='id'},
    {name='nil request', reason='schema'},
    {name='missing owner', payload=missing('target'), reason='owner'},
    {name='missing item', payload=missing('item'), reason='item'},
    {name='missing quantity', payload=missing('quantity'), reason='quantity'},
    {name='missing ID', payload=missing('id'), reason='id'},
    {name='empty ID', payload=request({id=''}), reason='id'},
}
for _, case in ipairs(invalid) do
    local result = invoke(case.payload)
    assert(not result.ok and result.reason==case.reason and result.balance==500 and result.grants==0,
        case.name..': expected '..case.reason..', got '..result.reason)
end
-- Separate input validation coverage from limiter coverage and refill the bucket.
task.wait(2.1)
local first = invoke(request())
assert(first.ok and first.balance==400 and first.grants==1, 'valid purchase must charge authoritative price')
local replay = invoke(request())
assert(not replay.ok and replay.reason=='replay' and replay.balance==400 and replay.grants==1, 'duplicate purchase must not grant twice')
local conflict=invoke(request({quantity=2}))
assert(not conflict.ok and conflict.reason=='conflict' and conflict.balance==400 and conflict.grants==1, 'changed payload must not reuse an action ID')
local insufficient = invoke(request({quantity=5,id='expensive'}))
assert(not insufficient.ok and insufficient.reason=='funds' and insufficient.balance==400, 'insufficient funds must preserve balance')
local values = batch(8, function(_, children)
    local result = invoke(request({id='parallel'}), children)
    assert(result.balance == 300 and result.grants == 2, 'invalid concurrent state')
    assert(result.reason == 'purchased' or result.reason == 'replay', 'unexpected concurrent rejection')
    return result.ok
end, 10)
local successes = 0
for _, success in values do if success then successes += 1 end end
assert(successes == 1, 'overlapping replay protection')
values = batch(70, function(_, children)
    local result = invoke(request({id='parallel'}), children)
    assert(not result.ok and result.balance == 300 and result.grants == 2, 'burst mutated state')
    assert(result.reason == 'replay' or result.reason == 'rate', 'unexpected burst rejection')
    return result.reason
end, 10)
local limited = 0
for _, reason in values do if reason == 'rate' then limited += 1 end end
-- Arrival timing can allow refill; report the observed count. The server also
-- tests the same limiter using a controlled clock before exposing the remote.
task.wait(1.1)
local recovered=invoke(request({id='after-refill'}))
assert(recovered.ok and recovered.balance==200 and recovered.grants==3, 'limiter must recover')
local finalPurchase=invoke(request({quantity=2,id='expensive'}))
assert(finalPurchase.ok and finalPurchase.balance==0 and finalPurchase.grants==5, 'failed request must not consume ID; distinct valid purchase must succeed')
local empty=invoke(request({id='empty'}))
assert(not empty.ok and empty.reason=='funds' and empty.balance==0 and empty.grants==5, 'empty balance must not grant items')
return finish({nestedTimeoutCleanup=true, scenario=TEST_SCENARIO, harnessFailureCapture=true, harnessTimeout=true, rateRejectionObserved=limited>0, changedPayloadRejected=true, failedIdReusable=true, exactBalancePurchase=true, invalidInputs=#invalid, legitimatePurchase=true, replayRejected=true,
    concurrentRequests=8, concurrentGrants=successes, boundedBurst=70, rateRejected=limited, cooldownRecovery=true})
