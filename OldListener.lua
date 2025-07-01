-- FINAL LISTENER (Corrected Case-Sensitive Repository Name)

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Debris = game:GetService("Debris")
local request = http_request or request or (syn and syn.request)
assert(request, "Listener Error: No HTTP request function found")

local CONFIG = {
    token  = "PASTE_YOUR_TOKEN_HERE",
    owner  = "cmdListen",
    repo   = "Remotecommands", -- <-- CORRECTED CASE
    path   = "latest_command.json",
    branch = "main",
}
local API_URL = ("https://api.github.com/repos/%s/%s/contents/%s?ref=%s"):format(CONFIG.owner,CONFIG.repo,CONFIG.path,CONFIG.branch)

local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64decode(data) data=data:gsub('[^'..b..'=]','');return(data:gsub('.',function(x)if(x=='=')then return''end;local r,f='',(b:find(x)-1);for i=6,1,-1 do r=r..((f%2^i-f%2^(i-1)>0)and'1'or'0')end;return r;end):gsub('%d%d%d?%d?%d?%d?%d?%d?',function(x)if(#x~=8)then return''end;local c=0;for i=1,8 do c=c+((x:sub(i,i)=='1')and 2^(8-i)or 0)end;return string.char(c)end))end

local CommandFunctions={}
CommandFunctions["kill"]=function()local c=game.Players.LocalPlayer.Character;if c and c:FindFirstChild("Humanoid")then c.Humanoid.Health=0 end end
CommandFunctions["reset"]=function()local c=game.Players.LocalPlayer.Character;if c then c:BreakJoints()end end
CommandFunctions["jump"]=function()local c=game.Players.LocalPlayer.Character;if c and c:FindFirstChild("Humanoid")then c.Humanoid.Jump=true end end
CommandFunctions["fling"]=function()local c=game.Players.LocalPlayer.Character;if not c then return end;local r=c:FindFirstChild("HumanoidRootPart")if not r then return end;local bv=Instance.new("BodyVelocity")bv.MaxForce=Vector3.new(1e6,1e6,1e6)bv.Velocity=Vector3.new(math.random(-150,150),math.random(250,350),math.random(-150,150))bv.Parent=r;Debris:AddItem(bv,0.5)end
CommandFunctions["trip"]=function()local c=game.Players.LocalPlayer.Character;if not c or not c.PrimaryPart then return end;for _,m in ipairs(c:GetDescendants())do if m:IsA("Motor6D")then local a0,a1=Instance.new("Attachment",m.Part0),Instance.new("Attachment",m.Part1)local s=Instance.new("BallSocketConstraint")s.Attachment0,s.Attachment1,s.Parent=a0,a1,c.PrimaryPart;m.Enabled=false end end;c.PrimaryPart.Velocity=Vector3.new(0,-50,0)task.delay(2,function()if not c or not c.Parent then return end;for _,d in ipairs(c:GetDescendants())do if d:IsA("BallSocketConstraint")then d:Destroy()elseif d:IsA("Motor6D")then d.Enabled=true end end end)end
CommandFunctions["bring"]=function(a)if type(a)~="string"then return end;local n={};for v in a:gmatch("([^,]+)")do table.insert(n,tonumber(v))end;if #n==3 and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")then game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame=CFrame.new(n[1],n[2],n[3])end end
CommandFunctions["join"]=function(j)if j and j~=""then TeleportService:TeleportToPlaceInstance(game.PlaceId,j,game.Players.LocalPlayer)end end
CommandFunctions["rejoin"]=function()TeleportService:Teleport(game.PlaceId)end

local lastProcessedId=0;task.spawn(function()while task.wait(3)do local s,r=pcall(request,{Url=API_URL,Method="GET",Headers={Authorization="token "..CONFIG.token}});if s and r.StatusCode==200 then local m,d,o,a=pcall(function()local meta=HttpService:JSONDecode(r.Body)local raw=base64decode(meta.content)return HttpService:JSONDecode(raw)end)if m and type(a)=="table"and type(a.commands)=="table"then for _,c in ipairs(a.commands)do if type(c)=="table"and c.id>lastProcessedId then lastProcessedId=c.id;local m,g=c.cmd:lower():match("^([^:]+):?(.*)$")local f=CommandFunctions[m]if f then task.spawn(f,g)end end end end elseif not s then warn("Listener network error: "..tostring(r)) end end end)
