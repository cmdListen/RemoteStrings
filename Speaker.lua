-- FINAL SPEAKER (Engineered for Stability)

--[[
    DEEP STUDY NOTES:
    1.  Initialization is now sequential and wrapped in protected calls (pcall) to prevent crashes.
    2.  Secure Mode is ENABLED by default to ensure maximum compatibility and prevent detection/freezing issues.
    3.  The script now cleans up any previous versions of the GUI on start to prevent conflicts.
    4.  Code is encapsulated in a 'self' object to avoid polluting the global environment.
]]

-- Activate Secure Mode BEFORE loading the library. This is critical for stability.
getgenv().SecureMode = true

local Controller = {}
Controller.__index = Controller

function Controller:Init()
    -- Step 1: Safely load services and dependencies
    self.HttpService = game:GetService("HttpService")
    self.Players = game:GetService("Players")
    self.request = http_request or request or (syn and syn.request)
    
    if not self.request then
        warn("Speaker FATAL: Could not find a valid HTTP request function.")
        return
    end

    -- Step 2: Safely download and compile the Rayfield library
    local success, rayfieldLoader = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua"))
    end)

    if not success or typeof(rayfieldLoader) ~= "function" then
        warn("Speaker FATAL: Failed to download or compile the Rayfield library. The source may be down.")
        return
    end
    
    -- Step 3: Initialize the Rayfield object itself
    local success, rayfieldInstance = pcall(rayfieldLoader)
    if not success or typeof(rayfieldInstance) ~= "table" then
        warn("Speaker FATAL: The Rayfield library executed but failed to return a valid instance.")
        return
    end
    self.Rayfield = rayfieldInstance

    -- Step 4: Clean up old GUI instances to prevent conflicts
    pcall(function()
        if self.Rayfield.Windows["Speaker Remote Console V4"] then
            self.Rayfield.Windows["Speaker Remote Console V4"]:Destroy()
        end
    end)

    -- Step 5: NOW that everything is safely loaded, create the window
    self:CreateUI()
end

function Controller:CreateUI()
    local Window = self.Rayfield:CreateWindow({
        Name = "Speaker Remote Console V4",
        LoadingTitle = "System Initialized",
        LoadingSubtitle = "Ready to Send",
        ConfigurationSaving = {
            Enabled = true,
            FolderName = "SpeakerV4",
            FileName = "Config"
        }
    })

    local Tab = Window:CreateTab("Remote Control")

    -- UI elements are now defined here
    Tab:CreateInput({
        Name = "Type Command", PlaceholderText = "kill, reset, fling, etc.",
        RemoveTextAfterFocusLost = false,
        Callback = function(text) self:QueueCommand(text) end
    })
    
    Tab:CreateButton({
        Name = "Clear Remote Command Queue",
        Callback = function()
            if self:_updateRemoteFile({ commands = {} }, "clear queue") then
                self.Rayfield:Notify({Title="Success", Content="Remote queue has been cleared.", Duration=4})
            end
        end,
    })

    -- ... (The rest of the UI creation is the same as before)
    Tab:CreateLabel("Quick Commands")
    local QUICK_COMMANDS = {
        { "Kill", "kill" }, { "Reset", "reset" }, { "Jump", "jump" }, { "Fling", "fling" }, { "Trip", "trip" },
        { "Bring", function()
            local hrp = self.Players.LocalPlayer.Character and self.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return self.Rayfield:Notify({Title="Error", Content="Could not get your position.", Duration=3}) end
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
    Tab:CreateButton({ Name = "Share Server ID", Callback = function() self:QueueCommand("join:" .. (game.JobId or "")) end })

    -- Load saved configurations at the very end
    self.Rayfield:LoadConfiguration()
end

-- All GitHub communication functions remain the same, just attached to the Controller object
-- (The Base64Encode, _updateRemoteFile, and QueueCommand functions are included here)
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function Controller:Base64Encode(data) return ((data:gsub('.', function(x) local r,bits='', x:byte() for i=8,1,-1 do r = r .. (bits % 2^i - bits % 2^(i-1) > 0 and '1' or '0') end return r end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x) if #x<6 then return '' end local c=0 for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end return b:sub(c+1,c+1) end)..({ '', '==', '=' })[#data%3+1]) end
function Controller:_updateRemoteFile(payloadObject, message) local CONFIG = {token="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", owner="cmdListen", repo="remotecommands", path="latest_command.json", branch="main"} local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s"):format(CONFIG.owner, CONFIG.repo, CONFIG.path) local getRes = self.request({Url = apiUrl .. "?ref=" .. CONFIG.branch, Method = "GET", Headers = {Authorization = "token " .. CONFIG.token}}) if getRes.StatusCode ~= 200 then self.Rayfield:Notify({Title="Error", Content="Could not fetch SHA.", Duration=5}) return false end local sha = self.HttpService:JSONDecode(getRes.Body).sha local jsonPayload = self.HttpService:JSONEncode(payloadObject) local encodedContent = self:Base64Encode(jsonPayload) local body = self.HttpService:JSONEncode({message = message, content = encodedContent, sha = sha, branch = CONFIG.branch}) local putRes = self.request({Url = apiUrl, Method = "PUT", Headers = {Authorization = "token " .. CONFIG.token, ["Content-Type"]="application/json"}, Body = body}) if not (putRes.StatusCode >= 200 and putRes.StatusCode < 300) then self.Rayfield:Notify({Title="Error", Content="GitHub PUT failed.", Duration=5}) end return true end
function Controller:QueueCommand(cmdText) local CONFIG = {token="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", owner="cmdListen", repo="remotecommands", path="latest_command.json", branch="main"} local apiUrl = ("https://api.github.com/repos/%s/%s/contents/%s"):format(CONFIG.owner, CONFIG.repo, CONFIG.path) local getRes = self.request({Url = apiUrl .. "?ref=" .. CONFIG.branch, Method = "GET", Headers = {Authorization = "token " .. CONFIG.token}}) if getRes.StatusCode ~= 200 then self.Rayfield:Notify({Title="Error", Content="Failed to get list.", Duration=5}) return end local data; local s, r = pcall(function() return self.HttpService:JSONDecode(self.HttpService:Base64Decode(self.HttpService:JSONDecode(getRes.Body).content)) end) if s and type(r)=="table" and type(r.commands)=="table" then data=r else data={commands={}} end table.insert(data.commands, {id=tick(), cmd=cmdText}) if self:_updateRemoteFile(data, "remote cmd: " .. cmdText) then self.Rayfield:Notify({Title="Command Queued", Content=cmdText, Duration=3}) end end

-- Start the entire process
Controller:Init()
