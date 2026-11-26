-- NEGATIVE TESTS: deliberately defective local functions below. Not reusable game code.
local RunService = game:GetService('RunService')
assert(RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(), 'Studio Play only')
-- Synthetic server-only failures. No real inventory, storage, or purchases.
local function weakCheck(n)
    return typeof(n)=='number' and not (n<1 or n>5)
end
assert(weakCheck(0/0), 'NaN should reproduce range-check bypass')
local function strictCheck(n)
    return typeof(n)=='number' and n==n and n>=1 and n<=5 and n%1==0
end
assert(not strictCheck(0/0) and not strictCheck(math.huge))
assert(strictCheck(1) and strictCheck(5))

local locked=false
local function broken()
    locked=true
    error('injected helper failure before mutation')
end
assert(not pcall(broken) and locked, 'expected stranded lock')
locked=false
local balance, grants=500,0
local function corrected(fail)
    if locked then return false end
    locked=true
    local ok=pcall(function()
        if fail then error('injected helper failure before mutation') end
        balance-=100
        grants+=1
    end)
    locked=false
    return ok
end
assert(not corrected(true) and not locked and balance==500 and grants==0)
assert(corrected(false) and not locked and balance==400 and grants==1)
local report = {NaN='range-only bypass reproduced; finite/integer guard passed',
    lock='stranded lock reproduced; release and subsequent valid action passed',
    limitation='Failure injected before mutation only; not a solution for ambiguous external side effects'}

print("[Roblox Release Check] "..game:GetService("HttpService"):JSONEncode(report))
return report
