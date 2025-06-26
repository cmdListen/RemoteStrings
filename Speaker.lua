-- FINAL SPEAKER V7 (Corrected Case-Sensitive Repository Name)

getgenv().SecureMode = true

local Controller = {}

function Controller:Init()
    self.HttpService = game:GetService("HttpService")
    self.request = http_request or request or (syn and syn.request)
    assert(self.request, "Speaker FATAL: No request function found.")

    local success, rf = pcall(loadstring(game:HttpGet("https://raw.githubusercontent.com/UI-Interface/CustomFIeld/main/RayField.lua")))
    assert(success and rf, "Speaker FATAL: Could not download Rayfield.")
    
    local success, inst = pcall(rf)
    assert(success and inst, "Speaker FATAL: Could not initialize Rayfield.")
    self.Rayfield = inst

    pcall(function() if self.Rayfield.Windows["Speaker Remote Console V7"] then self.Rayfield.Windows["Speaker Remote Console V7"]:Destroy() end end)
    self:CreateUI()
end

function Controller:CreateUI()
    local Window = self.Rayfield:CreateWindow({Name = "Speaker Remote Console V7"})
    local Tab = Window:CreateTab("Remote Control")
    Tab:CreateInput({Name="Type Command", Callback=function(t) self:QueueCommand(t) end})
    Tab:CreateButton({Name="Clear Remote Queue", Callback=function() self:UpdateRemoteFile({commands={}}, "clear queue", true) end})
    local QUICK = {{"Kill","kill"},{"Reset","reset"},{"Jump","jump"},{"Fling","fling"},{"Trip","trip"},{"Bring",function() local p=game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character.PrimaryPart and game.Players.LocalPlayer.Character.PrimaryPart.Position; if p then self:QueueCommand(("bring:%.2f,%.2f,%.2f"):format(p.X,p.Y,p.Z)) end end},{"Rejoin","rejoin"}}
    for _,v in ipairs(QUICK) do Tab:CreateButton({Name="Queue "..v[1],Callback=function() if type(v[2])=="string" then self:QueueCommand(v[2]) else v[2]() end end}) end
end

function Controller:GetConfig()
    return {
        token  = "PASTE_YOUR_TOKEN_HERE",
        owner  = "cmdListen",
        repo   = "Remotecommands", -- <-- CORRECTED CASE
        path   = "latest_command.json",
        branch = "main"
    }
end

function Controller:Base64Encode(data) local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';return ((data:gsub('.', function(x) local r,bits='', x:byte(); for i=8,1,-1 do r=r..(bits%2^i-bits%2^(i-1)>0 and '1' or '0') end return r end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x) if #x<6 then return '' end; local c=0; for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end return b:sub(c+1,c+1) end)..({ '', '==', '=' })[#data%3+1]) end

function Controller:UpdateRemoteFile(payload, message, isClearing)
    local cfg = self:GetConfig()
    local url = ("https://api.github.com/repos/%s/%s/contents/%s"):format(cfg.owner, cfg.repo, cfg.path)
    local sha = nil
    local get_res = self.request({ Url = url .. "?ref=" .. cfg.branch, Method = "GET", Headers = { Authorization = "token " .. cfg.token } })
    if get_res.StatusCode == 200 then sha = self.HttpService:JSONDecode(get_res.Body).sha elseif get_res.StatusCode ~= 404 then self.Rayfield:Notify({Title="Error", Content="GitHub GET failed: "..get_res.StatusCode}) return false end
    local bodyTable = { message = message, content = self:Base64Encode(self.HttpService:JSONEncode(payload)), branch = cfg.branch }
    if sha then bodyTable.sha = sha end
    local put_res = self.request({ Url = url, Method = "PUT", Headers = { Authorization = "token " .. cfg.token, ["Content-Type"] = "application/json" }, Body = self.HttpService:JSONEncode(bodyTable) })
    if put_res.StatusCode == 200 or put_res.StatusCode == 201 then
        if isClearing then self.Rayfield:Notify({Title="Success", Content="Queue cleared."}) else self.Rayfield:Notify({Title="Command Queued", Content=message}) end
    else self.Rayfield:Notify({Title="Error", Content="GitHub PUT failed: "..put_res.StatusCode}) end
end

function Controller:QueueCommand(cmdText)
    local cfg = self:GetConfig()
    local url = ("https://api.github.com/repos/%s/%s/contents/%s"):format(cfg.owner, cfg.repo, cfg.path)
    local data = { commands = {} }
    local get_res = self.request({ Url = url .. "?ref=" .. cfg.branch, Method = "GET", Headers = { Authorization = "token " .. cfg.token } })
    if get_res.StatusCode == 200 then
        local success, decoded = pcall(function() return self.HttpService:JSONDecode(self.HttpService:Base64Decode(self.HttpService:JSONDecode(get_res.Body).content)) end)
        if success and type(decoded) == "table" and type(decoded.commands) == "table" then data = decoded end
    elseif get_res.StatusCode ~= 404 then self.Rayfield:Notify({Title="Error", Content="Could not get list: "..get_res.StatusCode}) return end
    table.insert(data.commands, { id = tick(), cmd = cmdText })
    self:UpdateRemoteFile(data, "remote cmd: " .. cmdText, false)
end

Controller:Init()
