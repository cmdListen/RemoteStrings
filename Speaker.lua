-- SPEAKER (Rayfield GUI + GitHub API)

local HttpService = game:GetService("HttpService")
local request     = http_request or request or (syn and syn.request)
assert(request, "No HTTP request function found")

-- pure-Lua Base64 encode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
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

-- Rayfield GUI
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window   = Rayfield:CreateWindow{
    Name            = "Speaker Remote Console",
    LoadingTitle    = "Initializing",
    LoadingSubtitle = "Ready to send",
    ConfigurationSaving = { Enabled=true, FolderName="SpeakerConfig", FileName="Commands" },
    Discord         = { Enabled=false },
    KeySystem       = false,
}
local Tab = Window:CreateTab("Remote Control", 4483362458)

-- fetch current SHA
local function getSHA()
    local res = request{
        Url     = API_URL .. "?ref=" .. CONFIG.branch,
        Method  = "GET",
        Headers = { Authorization = "token " .. CONFIG.token },
    }
    if res.StatusCode == 200 then
        return HttpService:JSONDecode(res.Body).sha
    end
end

-- send a command
local function sendCommand(cmdText)
    local payload = HttpService:JSONEncode{ cmd = cmdText, timestamp = tick() }
    local encoded = base64encode(payload)
    local sha     = getSHA()
    assert(sha, "Failed to fetch SHA")

    local body = HttpService:JSONEncode{
        message = "remote cmd: " .. cmdText,
        content = encoded,
        sha     = sha,
        branch  = CONFIG.branch,
    }

    local res = request{
        Url     = API_URL,
        Method  = "PUT",
        Headers = {
            Authorization   = "token " .. CONFIG.token,
            ["Content-Type"]= "application/json",
        },
        Body    = body,
    }

    if res.StatusCode >= 200 and res.StatusCode < 300 then
        Rayfield:Notify{ Title="Command Sent", Content=cmdText, Duration=3 }
    else
        Rayfield:Notify{ Title="Error", Content="GitHub PUT failed", Duration=5 }
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
        local hrp = game.Players.LocalPlayer.Character and
                    game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local p = hrp.Position
        sendCommand(("bring:%.2f,%.2f,%.2f"):format(p.X,p.Y,p.Z))
    end },
    { "Rejoin",  "rejoin" },
    { "Kick",    "kick:You have been kicked!" },
}

-- UI
Tab:CreateInput{
    Name                    = "Type command (`kick:reason`)",
    PlaceholderText         = table.concat((function()
        local t = {}
        for _,v in ipairs(QUICK) do
            if type(v[2])=="string" then table.insert(t, v[2]) end
        end
        return t
    end)(), ", "),
    RemoveTextAfterFocusLost = false,
    Callback                = sendCommand,
}

for _,btn in ipairs(QUICK) do
    Tab:CreateButton{
        Name     = "Send "..btn[1],
        Callback = function()
            if type(btn[2])=="string" then
                sendCommand(btn[2])
            else
                btn[2]()
            end
        end,
    }
end

Tab:CreateButton{
    Name     = "Share Server ID",
    Callback = function()
        sendCommand("join:" .. (game.JobId or ""))
    end,
}
