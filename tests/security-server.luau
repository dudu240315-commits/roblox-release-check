-- Isolated Studio fixture, not production shop code. Install as a server Script.
local RunService = game:GetService('RunService')
if not RunService:IsStudio() or not RunService:IsRunning() or not RunService:IsServer() then return end
assert(not game.ReplicatedStorage:FindFirstChild('ReleaseSecurityProbe'), 'duplicate test remote')
local CAPACITY, REFILL_PER_SECOND = 32, 16
local function allow(bucket, now)
    bucket.tokens = math.min(CAPACITY, bucket.tokens + math.max(0, now-bucket.updated)*REFILL_PER_SECOND)
    bucket.updated = math.max(bucket.updated, now)
    if bucket.tokens < 1 then return false end
    bucket.tokens -= 1
    return true
end
-- Deterministic checks of the same limiter used by the remote; no network timing assumptions.
do
    local bucket = {tokens=CAPACITY, updated=0}
    for _=1,CAPACITY do assert(allow(bucket, 0), 'limiter capacity') end
    assert(not allow(bucket, 0), 'limiter must reject exhausted bucket')
    assert(not allow(bucket, 0.03125), 'fractional token must not allow action')
    assert(allow(bucket, 0.0625), 'one token must refill')
    assert(not allow(bucket, 0.0625), 'refill must not duplicate tokens')
    assert(not allow(bucket, -1), 'backward clock must not add tokens')
    assert(allow(bucket, 100) and bucket.tokens == CAPACITY-1, 'refill must be capped')
    local other = {tokens=CAPACITY, updated=0}
    assert(allow(other, 0), 'buckets must be independent')
end
local function newState(now)
    return {balance=500, grants=0, seen={}, tokens=CAPACITY, updated=now}
end
-- This same function handles real test remotes and controlled-clock integration checks.
local function handle(state, actorId, request, now)
    local function reply(ok, reason)
        return {ok=ok, reason=reason, balance=state.balance, grants=state.grants}
    end
    if not allow(state, now) then return reply(false, 'rate') end
    if typeof(request) ~= 'table' then return reply(false, 'schema') end
    local fields = 0
    for key in pairs(request) do
        fields += 1
        if fields > 4 or (key ~= 'target' and key ~= 'item' and key ~= 'quantity' and key ~= 'id') then
            return reply(false, 'schema')
        end
    end
    if request.target ~= actorId then return reply(false, 'owner') end
    if request.item ~= 'Sword' then return reply(false, 'item') end
    local n = request.quantity
    if typeof(n) ~= 'number' or n ~= n or n < 1 or n > 5 or n % 1 ~= 0 then
        return reply(false, 'quantity')
    end
    local id = request.id
    if typeof(id) ~= 'string' or #id == 0 or #id > 32 then return reply(false, 'id') end
    local previous = state.seen[id]
    if previous then
        if previous.item ~= request.item or previous.quantity ~= n then
            return reply(false, 'conflict')
        end
        return reply(false, 'replay')
    end
    local cost = 100*n
    if state.balance < cost then return reply(false, 'funds') end
    -- No yielding work occurs between authoritative check and mutation.
    state.balance -= cost
    state.grants += n
    state.seen[id] = {item=request.item, quantity=n}
    return reply(true, 'purchased')
end
-- Verify limiter enforcement in the handler, not only the helper's arithmetic.
do
    local state = newState(0)
    for _=1,CAPACITY do
        local result = handle(state, 1, false, 0)
        assert(result.reason == 'schema', 'handler rejected before capacity')
    end
    local blocked = handle(state, 1, false, 0)
    assert(blocked.reason == 'rate' and blocked.balance == 500 and blocked.grants == 0,
        'handler limiter enforcement missing')
    local recovered = handle(state, 1, {target=1,item='Sword',quantity=1,id='recovered'}, 0.0625)
    assert(recovered.ok and recovered.balance == 400 and recovered.grants == 1,
        'handler limiter did not recover')
    local independent = handle(newState(0), 2, {target=2,item='Sword',quantity=1,id='other'}, 0)
    assert(independent.ok and independent.balance == 400, 'handler state isolation failed')
end
local remote = Instance.new('RemoteFunction')
remote.Name = 'ReleaseSecurityProbe'
local states = {}
remote.OnServerInvoke = function(player, request)
    local now = os.clock()
    local state = states[player]
    if not state then state = newState(now); states[player] = state end
    return handle(state, player.UserId, request, now)
end
game.Players.PlayerRemoving:Connect(function(player) states[player] = nil end)
remote.Parent = game.ReplicatedStorage
