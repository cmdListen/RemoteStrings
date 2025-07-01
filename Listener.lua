-- ==========================================================
-- UNIVERSAL WHITELISTED CHAT COMMAND SCRIPT (v2.2 - Final)
-- Pre-configured with your specific whitelist URL.
-- ==========================================================

-- // --- Configuration ---
-- The URL is now set to your provided GitHub link.
local WHITELIST_URL = "https://raw.githubusercontent.com/cmdListen/RemoteStrings/refs/heads/main/whitelist.json"

-- // --- Services ---
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local Debris = game:GetService("Debris")
local TeleportService = game:GetService("TeleportService")

-- // --- Local Setup ---
local LocalPlayer = Players.LocalPlayer or Players.LocalPlayerAdded:Wait()
local whitelist = {}

print("Whitelist Listener: Active for " .. LocalPlayer.Name)

-- // --- Whitelist Fetching ---
task.spawn(function()
    local success, response = pcall(function() return HttpService:GetAsync(WHITELIST_URL) end)
    if not success then warn("Whitelist Listener: CRITICAL - Failed to download whitelist. Error:", response) return end
    
    local decodeSuccess, decodedList = pcall(function() return HttpService:JSONDecode(response) end)
    if not decodeSuccess then warn("Whitelist Listener: CRITICAL - Failed to decode whitelist JSON.") return end
    
    -- Populate the whitelist table for fast lookups
    for _, item in ipairs(decodedList) do
        whitelist[item] = true 
    end
    
    print("Whitelist Listener: Successfully loaded " .. #decodedList .. " users from your URL.")
end)

-- // --- The Command Library ---
local CommandFunctions={};CommandFunctions["kill"]=function()if LocalPlayer.Character and LocalPlayer.Character.Humanoid then LocalPlayer.Character.Humanoid.Health=0 end end;CommandFunctions["fling"]=function()local h=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")if not h then return end;local b=Instance.new("BodyVelocity",h)b.MaxForce=Vector3.new(1e7,1e7,1e7)b.Velocity=Vector3.new(math.random(-150,150),math.random(200,300),math.random(-150,150))Debris:AddItem(b,0.5)end;CommandFunctions["jump"]=function()if LocalPlayer.Character and LocalPlayer.Character.Humanoid then LocalPlayer.Character.Humanoid.Jump=true end end;CommandFunctions["trip"]=function()if LocalPlayer.Character and LocalPlayer.Character.Humanoid then LocalPlayer.Character.Humanoid.PlatformStand=true task.wait(0.1)LocalPlayer.Character.Humanoid.PlatformStand=false end end;CommandFunctions["rejoin"]=function()TeleportService:Teleport(game.PlaceId,LocalPlayer)end;

-- // --- The Core Logic: The Chat Listener ---
TextChatService.OnIncomingMessage = function(message)
    -- Verify the sender exists and is a player.
    if not message.TextSource or not message.TextSource:IsA("Player") then return end
    local sender = message.TextSource
    
    -- THE WHITELIST CHECK: Is the sender authorized?
    if not whitelist[sender.UserId] and not whitelist[sender.Name] then return end
    
    -- Split the message into words.
    local messageText = message.Text:lower()
    local words = {}
    for word in messageText:gmatch("%S+") do table.insert(words, word) end
    if #words < 2 then return end

    local commandWord = words[1]
    local targetWord = words[2]
    
    -- THE "IS IT FOR ME?" CHECK: Is my name the target?
    if string.find(LocalPlayer.Name:lower(), targetWord) then
        local commandFunc = CommandFunctions[commandWord]
        if commandFunc then
            print("Authorized command received from "..sender.Name..": '" .. commandWord .. "'")
            task.spawn(commandFunc)
        end
    end
end
