-- REFINED SPEAKER (Command Queue GUI)

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local request     = http_request or request or (syn and syn.request)
assert(request, "No HTTP request function found")

-- pure-Lua Base64 encode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64encode(data)
    return ((data:gsub('.', function(x)
        local r,bits='', x:byte()
        for i=8,1,-1 do r = r .. (bits % 2^i - bits % 2^(i-1) > 0 and '1' or '0') end
        return r
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if #x<6 then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
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

-- Rayfield GUI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({ Name = "Speaker Remote Console V2", LoadingTitle = "Initializing" })
local Tab = Window:CreateTab("Remote Control", 4483362458)

-- Helper function to update the remote file
local function updateRemoteFile(payloadObject, message)
    -- 1. Get the current file SHA
    local getRes = request({ Url = API_URL .. "?ref=" .. CONFIG.branch, Method = "GET", Headers = { Authorization = "token " .. CONFIG.token } })
    if getRes.StatusCode ~= 200 then
        Rayfield:Notify({ Title="Error", Content="Could not fetch file SHA. Check token/repo.", Duration=5 })
        return false
    end
    local sha = HttpService:JSONDecode(getRes.Body).sha

    -- 2. Prepare the new content
    local jsonPayload = HttpService:JSONEncode(payloadObject)
    local encodedContent = base64encode(jsonPayload)
    
    local body = HttpService:JSONEncode({
        message = message,
        content = encodedContent,
        sha     = sha,
        branch  = CONFIG.branch,
    })

    -- 3. Send the PUT request to update the file
    local putRes = request({
        Url = API_URL, Method = "PUT",
        Headers = { Authorization = "token " .. CONFIG.token, ["Content-Type"] = "application/json" },
        Body = body,
    })

    if putRes.StatusCode >= 200 and putRes.StatusCode < 300 then
        return true
    else
        Rayfield:Notify({ Title="Error", Content="GitHub PUT failed: " .. putRes.StatusMessage, Duration=5 })
        return false
    end
end

-- Function to add a command to the remote queue
local function queueCommand(cmdText)
    -- 1. Fetch the current command list
    local getRes = request({ Url = API_URL .. "?ref=" .. CONFIG.branch, Method = "GET", Headers = { Authorization = "token " .. CONFIG.token } })
    if getRes.StatusCode ~= 200 then
        Rayfield:Notify({ Title="Error", Content="Failed to get current command list.", Duration=5 })
        return
    end
    
    local b64content = HttpService:JSONDecode(getRes.Body).content
    local rawJson = (loadstring(return (game:GetService("HttpService"):JSONDecode(game:GetService("HttpService"):Base64Decode(b64content)))))() -- A robust way to decode
    
    local data = (type(rawJson) == "table" and rawJson.commands) and rawJson or { commands = {} }

    -- 2. Add the new command
    table.insert(data.commands, {
        id = tick(), -- Unique ID for the command
        cmd = cmdText
    })

    -- 3. Update the remote file
    if updateRemoteFile(data, "remote cmd: " .. cmdText) then
        Rayfield:Notify({ Title="Command Queued", Content=cmdText, Duration=3 })
    end
end

-- Quick-button definitions
local QUICK = {
    { "Kill",    "kill" },
    { "Reset",   "reset" },
    { "Jump",    "jump" },
    { "Fling",   "fling" },
    { "Trip",    "trip" },
    { "Bring",   function()
        local pl = Players.LocalPlayer
        local hrp = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return Rayfield:Notify({Title="Error", Content="Cannot get your position.", Duration=3}) end
        local p = hrp.Position
        queueCommand(("bring:%.2f,%.2f,%.2f"):format(p.X,p.Y,p.Z))
    end },
    { "Rejoin",  "rejoin" },
    { "Kick",    "kick:You have been kicked!" },
}

-- UI
Tab:CreateInput({
    Name = "Type command (`kick:reason`)",
    PlaceholderText = "kill, reset, jump, fling, etc.",
    RemoveTextAfterFocusLost = false,
    Callback = queueCommand,
})

Tab:CreateButton({
    Name = "Clear Remote Queue",
    Callback = function()
        if updateRemoteFile({ commands = {} }, "clear queue") then
            Rayfield:Notify({ Title="Success", Content="Remote command queue has been cleared.", Duration=4 })
        end
    end,
})

Tab:CreateLabel("Quick Commands")

for _, btnInfo in ipairs(QUICK) do
    Tab:CreateButton({
        Name = "Queue " .. btnInfo[1],
        Callback = function()
            if type(btnInfo[2]) == "string" then
                queueCommand(btnInfo[2])
            else
                btnInfo[2]() -- Handle special cases like 'Bring'
            end
        end,
    })
end

Tab:CreateButton({
    Name = "Share Server ID",
    Callback = function()
        queueCommand("join:" .. (game.JobId or ""))
    end,
})
