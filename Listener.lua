-- REFINED LISTENER (Command Queue Polling)

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local Debris      = game:GetService("Debris")
local localPlayer = Players.LocalPlayer
local request     = http_request or request or (syn and syn.request)
assert(request, "No HTTP request function found")

-- pure-Lua Base64 decode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64decode(data)
    data = data:gsub('[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if x=='=' then return '' end
        local r,f='', (b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if #x~=8 then return '' end
        local c=0
        for i=1,8 do c=c + (x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

-- CONFIG
local CONFIG = {
    token  = "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",
    owner  = "cmdListen",
    repo   = "remotecommands",
    path   = "latest_command.json",
    branch = "main",
}
local API_URL = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s")
    :format(CONFIG.owner, CONFIG.repo, CONFIG.path, CONFIG.branch)

-- Command Handlers (no changes needed here)
local CommandFunctions = {}

CommandFunctions["kill"] = function()
    local c=localPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.Health=0 end
end

CommandFunctions["reset"] = function()
    local c=localPlayer.Character
    if c then c:BreakJoints() end
end

CommandFunctions["jump"] = function()
    local c=localPlayer.Character
    if c and c:FindFirstChild("Humanoid") then c.Humanoid.Jump=true end
end

CommandFunctions["fling"] = function()
    local c=localPlayer.Character
    if not c then return end
    local r=c:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local bv=Instance.new("BodyVelocity")
    bv.MaxForce=Vector3.new(1e6,1e6,1e6)
    bv.Velocity=Vector3.new(math.random(-150,150),math.random(250,350),math.random(-150,150))
    bv.Parent=r; Debris:AddItem(bv,0.5)
end

CommandFunctions["trip"] = function()
    local c=localPlayer.Character
    if not c or not c.PrimaryPart then return end
    for _,m in ipairs(c:GetDescendants()) do
        if m:IsA("Motor6D") then
            local a0,a1=Instance.new("Attachment",m.Part0),Instance.new("Attachment",m.Part1)
            local sock=Instance.new("BallSocketConstraint")
            sock.Attachment0, sock.Attachment1, sock.Parent=a0, a1, c.PrimaryPart
            m.Enabled=false
        end
    end
    c.PrimaryPart.Velocity=Vector3.new(0,-50,0)
    task.delay(2,function()
        if not c or not c.Parent then return end
        for _,d in ipairs(c:GetDescendants()) do
            if d:IsA("BallSocketConstraint") then d:Destroy()
            elseif d:IsA("Motor6D") then d.Enabled=true end
        end
    end)
end

CommandFunctions["bring"] = function(arg)
    if type(arg) ~= "string" then return end
    local nums={}
    for v in arg:gmatch("([^,]+)") do table.insert(nums, tonumber(v)) end
    if #nums==3 and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        localPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(nums[1],nums[2],nums[3])
    end
end

CommandFunctions["join"] = function(jobId)
    if jobId and jobId~="" then
        TeleportService:TeleportToPlaceInstance(game.PlaceId,jobId,localPlayer)
    end
end

CommandFunctions["rejoin"] = function()
    TeleportService:Teleport(game.PlaceId)
end

-- Main polling loop
local lastProcessedId = 0
task.spawn(function()
    while task.wait(2) do -- Increased wait time to reduce API calls
        local success, res = pcall(function()
            return request({
                Url = API_URL,
                Method = "GET",
                Headers = { Authorization = "token " .. CONFIG.token },
            })
        end)

        if success and res.StatusCode == 200 then
            local meta = HttpService:JSONDecode(res.Body)
            local raw = base64decode(meta.content)
            local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
            
            -- Expecting data in format: { commands = [ {id=..., cmd=...}, ... ] }
            if ok and type(data) == "table" and type(data.commands) == "table" then
                for _, commandInfo in ipairs(data.commands) do
                    if type(commandInfo) == "table" and commandInfo.id > lastProcessedId then
                        lastProcessedId = commandInfo.id -- Update ID *before* executing
                        
                        local cmd, arg = commandInfo.cmd:lower():match("^([^:]+):?(.*)$")
                        local fn = CommandFunctions[cmd]
                        if fn then
                            task.spawn(fn, arg) -- Spawn to prevent one command from blocking others
                        end
                    end
                end
            end
        end
    end
end)
