-- NEGATIVE/positive synthetic receipt tests. Never issues Robux purchases.
-- These local status strings model decisions; this does not bind real marketplace callbacks.
local RunService = game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), 'Studio Play only')
local function finish(report)
    print('[Roblox Release Check] '..game:GetService('HttpService'):JSONEncode(report))
    return report
end

local products = {[101]=100, [202]=250}
local profiles = {}
local externalEffects = 0
local function copyProfile(profile)
    local receipts = {}
    for purchaseId, value in pairs(profile.receipts) do receipts[purchaseId] = value end
    return {coins=profile.coins, receipts=receipts}
end
local function sameProfile(left, right)
    if left.coins ~= right.coins then return false end
    for purchaseId, value in pairs(left.receipts) do
        if right.receipts[purchaseId] ~= value then return false end
    end
    for purchaseId, value in pairs(right.receipts) do
        if left.receipts[purchaseId] ~= value then return false end
    end
    return true
end
local function updateProfile(userId, transform, failWrite, retryCallback)
    local stored = profiles[userId] or {coins=0, receipts={}}
    local beforeEffects = externalEffects
    local candidate = transform(copyProfile(stored))
    assert(externalEffects == beforeEffects, 'UpdateAsync transform performed external side effect')
    if retryCallback then
        local secondCandidate = transform(copyProfile(stored))
        assert(externalEffects == beforeEffects, 'retried transform repeated external side effect')
        assert(sameProfile(candidate, secondCandidate), 'UpdateAsync transform outputs must be repeatable')
        candidate = secondCandidate
    end
    assert(sameProfile(stored, profiles[userId] or stored), 'transform mutated stored profile')
    if failWrite then return false end
    profiles[userId] = candidate
    return true
end
local function process(receipt, playerAvailable, failWrite, retryCallback)
    if typeof(receipt) ~= 'table'
        or typeof(receipt.PurchaseId) ~= 'string' or #receipt.PurchaseId == 0
        or typeof(receipt.PlayerId) ~= 'number' or receipt.PlayerId % 1 ~= 0 or receipt.PlayerId < 1
        or typeof(receipt.ProductId) ~= 'number' or receipt.ProductId % 1 ~= 0 then
        return 'Retry'
    end
    local coins = products[receipt.ProductId]
    if not coins or not playerAvailable then return 'Retry' end
    local ok = updateProfile(receipt.PlayerId, function(old)
        if old.receipts[receipt.PurchaseId] then return copyProfile(old) end
        local nextProfile = copyProfile(old)
        nextProfile.coins += coins
        nextProfile.receipts[receipt.PurchaseId] = true
        return nextProfile
    end, failWrite, retryCallback)
    return if ok then 'Processed' else 'Retry'
end

local r1 = {PurchaseId='purchase-A', PlayerId=42, ProductId=101}
local r2 = {PurchaseId='purchase-B', PlayerId=42, ProductId=202}
assert(process(r1, true, false, true) == 'Processed', 'first receipt should process')
assert(profiles[42].coins == 100 and profiles[42].receipts['purchase-A'], 'receipt benefit and marker must save together')
assert(process(r1, true) == 'Processed', 'exact duplicate should be acknowledged')
assert(profiles[42].coins == 100, 'duplicate must not double grant')
assert(process(r2, true) == 'Processed' and profiles[42].coins == 350, 'out-of-order distinct receipt should process')

local r3 = {PurchaseId='purchase-C', PlayerId=42, ProductId=101}
local beforeFailedWrite = copyProfile(profiles[42])
assert(process(r3, true, true) == 'Retry', 'failed persistence must remain retryable')
assert(sameProfile(profiles[42], beforeFailedWrite), 'failed save must preserve full profile and receipt history')
assert(not profiles[42].receipts['purchase-C'], 'failed save must not mark receipt')
assert(process(r3, true) == 'Processed', 'receipt should process after storage recovers')
assert(profiles[42].coins == 450 and profiles[42].receipts['purchase-C'], 'successful retry grants once')
assert(process(r3, true) == 'Processed' and profiles[42].coins == 450, 'retry after acknowledgement must remain idempotent')

assert(process({PurchaseId='purchase-D', PlayerId=42, ProductId=101}, false) == 'Retry', 'absent player stays retryable')
assert(profiles[42].coins == 450 and not profiles[42].receipts['purchase-D'], 'absent player cannot be marked granted')
assert(process({PurchaseId='purchase-E', PlayerId=42, ProductId=999}, true) == 'Retry', 'unknown product must not grant')
assert(profiles[42].coins == 450 and not profiles[42].receipts['purchase-E'], 'unknown product cannot change profile')

local bad = {
    {PurchaseId='', PlayerId=42, ProductId=101},
    {PurchaseId='bad-user', PlayerId=0/0, ProductId=101},
    {PurchaseId='bad-product', PlayerId=42, ProductId=math.huge},
    false,
}
for _, value in bad do
    assert(process(value, true) == 'Retry', 'malformed receipt must be retried, not acknowledged')
end
assert(profiles[42].coins == 450, 'malformed receipts cannot grant currency')
local caught, message = pcall(function()
    updateProfile(42, function(old)
        externalEffects += 1
        local nextProfile = copyProfile(old)
        nextProfile.coins += 1
        return nextProfile
    end, false, true)
end)
assert(not caught and string.find(tostring(message), 'external side effect', 1, true),
    'callback retry test must detect repeated side effects')
externalEffects = 0
assert(profiles[42].coins == 450, 'side-effect test must not change stored profile')
return finish({duplicateIdempotent=true, reorderedDistinctReceipts=true, failedWriteRetry=true,
    callbackOutputRepeatable=true, repeatedSideEffectDetected=true, absentPlayerRetry=true, unknownProductRejected=true,
    malformedReceipts=#bad, finalCoins=450,
    limitation='In-memory same-process mock; no Roblox enum, DataStore, or cross-server guarantee'})
