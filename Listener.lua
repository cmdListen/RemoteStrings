-- LISTENER (background polling + reset)

local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Debris          = game:GetService("Debris")
local localPlayer     = Players.LocalPlayer
local request         = http_request or request or (syn and syn.request)
assert(request, "No HTTP request function found")

-- pure-Lua Base64 decode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64decode(data)
    data = data:gsub('[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x=='=' then return '' end
        local r,f='', (b:find(x)-1)
        for i=6,1,-1 do
            r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x~=8 then return '' end
        local c=0
        for i=1,8 do
            c = c + (x:sub(i,i)=='1' and 2^(8-i) or 0)
        end
        return string.char(c)
    end))
end

-- pure-Lua Base64 encode (for resetRemote)
local function base64encode(data)
    return ((data:gsub('.', function(x)
        local r,bits='', x:byte()
        for i=8,1,-1 do
            r = r .. (bits % 2^i - bits % 2^(i-1) > 0 and '1' or '0')
        end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x < 6 then return '' end
        local c=0
        for i=1,6 do
            c = c + (x:sub(i,i)=='1' and 2^(6-i) or 0)
        end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

-- CONFIG
local CONFIG = {
    token  = "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",
    owner  = "cmdListen",
    repo   = "remotecommands",
    path   = "latest_command.json",
    branch = "main",
}
local API_URL = ("https://api.github.com/repos/%s/%s/contents/%s")
    :format(CONFIG.owner, CONFIG.repo, CONFIG.path)

-- reset remote JSON to none
local function resetRemote()
    local res = request{
        Url     = API_URL .. "?ref=" .. CONFIG.branch,
        Method  = "GET",
        Headers = { Authorization = "token " .. CONFIG.token },
    }
    if res.StatusCode ~= 200 then return end
    local sha = HttpService:JSONDecode(res.Body).sha

    local payload = HttpService:JSONEncode{ cmd="none", timestamp=tick() }
    local content = base64encode(payload)
    local body = HttpService:JSONEncode{
        message = "reset cmd",
        content = content,
        sha     = sha,
        branch  = CONFIG.branch,
    }

    request{
        Url     = API_URL,
        Method  = "PUT",
        Headers = {
            Authorization   = "token " .. CONFIG.token,
            ["Content-Type"]= "application/json",
        },
        Body = body,
    }
end

-- register commands
local CommandFunctions = {}

CommandFunctions["kill"] = function()
    local c = localPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid.Health = 0
    end
end

CommandFunctions["reset"] = function()
    local c = localPlayer.Character
    if c then c:BreakJoints() end
end

CommandFunctions["jump"] = function()
    local c = localPlayer.Character
    if c and c:FindFirstChild("Humanoid") then
        c.Humanoid.Jump = true
    end
end

CommandFunctions["fling"] = function()
    local c = localPlayer.Character
    if not c then return end
    local r = c:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = Vector3.new(
        math.random(-100,100),
        math.random(200,300),
        math.random(-100,100)
    )
    bv.Parent = r
    Debris:AddItem(bv, 0.5)
end

CommandFunctions["trip"] = function()
    local c = localPlayer.Character
    if not c or not c.PrimaryPart then return end
    for _,m in ipairs(c:GetDescendants()) do
        if m:IsA("Motor6D") then
            local a0 = Instance.new("Attachment", m.Part0)
            local a1 = Instance.new("Attachment", m.Part1)
            local sock = Instance.new("BallSocketConstraint")
            sock.Attachment0 = a0
            sock.Attachment1 = a1
            sock.Parent      = c.PrimaryPart
            m.Enabled       = false
        end
    end
    c.PrimaryPart.Velocity = Vector3.new(0, -50, 0)
    delay(2, function()
        if not c then return end
        for _,d in ipairs(c:GetDescendants()) do
            if d:IsA("BallSocketConstraint") then d:Destroy()
            elseif d:IsA("Motor6D") then d.Enabled = true end
        end
    end)
end

CommandFunctions["bring"] = function(arg)
    local nums = {}
    for v in arg:gmatch("[^,]+") do
        nums[#nums+1] = tonumber(v)
    end
    if #nums == 3 and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(nums[1], nums[2], nums[3])
    end
end

CommandFunctions["join"] = function(jobId)
    if jobId and jobId ~= "" then
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
    end
end

CommandFunctions["rejoin"] = function()
    TeleportService:Teleport(game.PlaceId)
end

-- fetch & execute
local lastTimestamp = 0
spawn(function()
    while true do
        local res = request{
            Url     = API_URL .. "?ref=" .. CONFIG.branch,
            Method  = "GET",
            Headers = { Authorization = "token " .. CONFIG.token },
        }
        if res.StatusCode == 200 then
            local meta = HttpService:JSONDecode(res.Body)
            local raw  = base64decode(meta.content)
            local ok, payload = pcall(HttpService.JSONDecode, HttpService, raw)
            if ok and payload.timestamp and payload.cmd then
                if payload.timestamp > lastTimestamp then
                    lastTimestamp = payload.timestamp
                    local cmd,arg = payload.cmd:lower():match("^([^:]+):?(.*)$")
                    local fn = CommandFunctions[cmd]
                    if fn then
                        if arg ~= "" then fn(arg) else fn() end
                    end
                    resetRemote()
                end
            end
        end
        wait(1)
    end
end)
