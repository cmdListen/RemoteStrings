-- RE-ENGINEERED SPEAKER (Safe Initialization & Robust Structure)

--- A more robust, object-oriented structure to prevent conflicts and handle errors.
local RemoteController = {}
RemoteController.__index = RemoteController

--- CONFIGURATION
RemoteController.CONFIG = {
    token  = "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",
    owner  = "cmdListen",
    repo   = "remotecommands",
    path   = "latest_command.json",
    branch = "main",
}

-- pure-Lua Base64 encode
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function RemoteController:Base64Encode(data)
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

--- Internal function to update the remote file on GitHub
function RemoteController:_updateRemoteFile(payloadObject, message)
    local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s"):format(self.CONFIG.owner, self.CONFIG.repo, self.CONFIG.path)
    
    local getRes = self.request({ Url = apiUrl .. "?ref=" .. self.CONFIG.branch, Method = "GET", Headers = { Authorization = "token " .. self.CONFIG.token } })
    if getRes.StatusCode ~= 200 then
        self.Rayfield:Notify({ Title="Error", Content="Could not fetch file SHA.", Duration=5 })
        return false
    end
    local sha = self.HttpService:JSONDecode(getRes.Body).sha

    local jsonPayload = self.HttpService:JSONEncode(payloadObject)
    local encodedContent = self:Base64Encode(jsonPayload)
    
    local body = self.HttpService:JSONEncode({
        message = message, content = encodedContent, sha = sha, branch = self.CONFIG.branch,
    })

    local putRes = self.request({
        Url = apiUrl, Method = "PUT",
        Headers = { Authorization = "token " .. self.CONFIG.token, ["Content-Type"] = "application/json" },
        Body = body,
    })

    return putRes.StatusCode >= 200 and putRes.StatusCode < 300
end

--- Public function to add a command to the remote queue
function RemoteController:QueueCommand(cmdText)
    local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s"):format(self.CONFIG.owner, self.CONFIG.repo, self.CONFIG.path)
    local getRes = self.request({ Url = apiUrl .. "?ref=" .. self.CONFIG.branch, Method = "GET", Headers = { Authorization = "token " .. self.CONFIG.token } })
    if getRes.StatusCode ~= 200 then
        self.Rayfield:Notify({ Title="Error", Content="Failed to get command list.", Duration=5 })
        return
    end
    
    local data
    local success, result = pcall(function()
        local apiResponse = self.HttpService:JSONDecode(getRes.Body)
        local rawJson = self.HttpService:Base64Decode(apiResponse.content)
        return self.HttpService:JSONDecode(rawJson)
    end)
    
    if success and type(result) == "table" and type(result.commands) == "table" then
        data = result
    else
        data = { commands = {} }
    end

    table.insert(data.commands, { id = tick(), cmd = cmdText })

    if self:_updateRemoteFile(data, "remote cmd: " .. cmdText) then
        self.Rayfield:Notify({ Title="Command Queued", Content=cmdText, Duration=3 })
    else
        self.Rayfield:Notify({ Title="Error", Content="GitHub PUT request failed.", Duration=5 })
    end
end

--- Main initialization function
function RemoteController:Init()
    -- Get services
    self.HttpService = game:GetService("HttpService")
    self.Players = game:GetService("Players")
    
    -- Find the executor's HTTP request function
    self.request = http_request or request or (syn and syn.request)
    assert(self.request, "Speaker Error: No valid HTTP request function found.")

    -- Safely load the Rayfield library
    local success, rayfieldLib = pcall(loadstring(game:HttpGet("https://sirius.menu/rayfield")))
    if not success or not rayfieldLib then
        warn("Speaker Error: Failed to download or compile Rayfield library.")
        return
    end
    self.Rayfield = rayfieldLib() -- Execute the loaded library to get the object

    -- Now that the library is loaded, build the UI
    local Window = self.Rayfield:CreateWindow({ Name = "Speaker Remote Console V3", LoadingTitle = "Ready" })
    local Tab = Window:CreateTab("Remote Control", 4483362458)

    -- UI Elements
    Tab:CreateInput({
        Name = "Type command", PlaceholderText = "kill, reset, jump, fling, etc.",
        RemoveTextAfterFocusLost = false,
        Callback = function(text) self:QueueCommand(text) end,
    })

    Tab:CreateButton({
        Name = "Clear Remote Queue",
        Callback = function()
            if self:_updateRemoteFile({ commands = {} }, "clear queue") then
                self.Rayfield:Notify({ Title="Success", Content="Remote queue cleared.", Duration=4 })
            end
        end,
    })

    Tab:CreateLabel("Quick Commands")

    local QUICK_COMMANDS = {
        { "Kill", "kill" }, { "Reset", "reset" }, { "Jump", "jump" }, { "Fling", "fling" }, { "Trip", "trip" },
        { "Bring", function()
            local hrp = self.Players.LocalPlayer.Character and self.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return self.Rayfield:Notify({Title="Error", Content="Cannot get your position.", Duration=3}) end
            local p = hrp.Position
            self:QueueCommand(("bring:%.2f,%.2f,%.2f"):format(p.X,p.Y,p.Z))
        end },
        { "Rejoin", "rejoin" },
    }

    for _, btnInfo in ipairs(QUICK_COMMANDS) do
        Tab:CreateButton({
            Name = "Queue " .. btnInfo[1],
            Callback = function()
                if type(btnInfo[2]) == "string" then self:QueueCommand(btnInfo[2]) else btnInfo[2]() end
            end,
        })
    end

    Tab:CreateButton({
        Name = "Share Server ID",
        Callback = function() self:QueueCommand("join:" .. (game.JobId or "")) end,
    })
end

-- Start the controller
RemoteController:Init()
