local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ─── Variables ─────────────────────────────────────────────────────────────────
SilentAimEnabled   = false
SilentBodyEnabled  = false
RedLineLock        = false
FOVRadius          = 120
CurrentTarget      = nil
SelectedAimPart    = "Head"
excludedPlayerNames = {}

nameESPEnabled     = false
healthESPEnabled   = false
distanceESPEnabled = false
skeletonESPEnabled = false
boxESPEnabled      = false
highlightEnabled   = false
inventoryESPEnabled= false
espPlayers         = {}
playerHighlights   = {}
BoxDrawings        = {}
skeletonConnections= {}
InventoryDrawings  = {}
WeaponRegistry     = {}
BillboardCache     = {}

local HISTORY_SIZE   = 6
local PREDICT_FACTOR = 1.2
local SKY_Y_THRESHOLD= 150
local SMOOTH_ALPHA   = 0.75
local PositionHistory= {}
local TracerSmoothedPos = Vector3.new()
local TracerESP = nil

local walkSpeedEnabled = false
local speedValue = 0.05
local walkConn   = nil
local FlyEnabled = false
local isFlyingUp = false
local floatPower = 40
local flyJumpConnection = nil

local AutoSprintEnabled = false
local AutoSprintLoop    = nil
local OriginalSprintUpdate = nil

local autoHealEnabled  = false
local HEALTH_THRESHOLD = 50
local healBusy = false
local lastHealUse = 0

local hookEnabled   = false
local scanRadius    = 20
local scanInterval  = 0.4
local autoAttackRunning = false

local fastFinishEnabled = false
local holdTime = 1

local featureEnabled = false
local teleportActive = false
local lockedY = nil
local maxHeight = 10
local startY = nil
local snapConnection = nil
local clickCount = 0
local HumanoidRootPart_snap = nil

local sucking = false
local lastPickupTimes = {}

local enabled = false -- Anti Kill

local CounterTable = nil
pcall(function()
    for _, obj in ipairs(getgc(true)) do
        if typeof(obj) == "table" and rawget(obj, "event") and rawget(obj, "func") then
            CounterTable = obj; break
        end
    end
end)

RARITY_COLORS = {
    Common    = Color3.fromRGB(255,255,255),
    Uncommon  = Color3.fromRGB(99,255,52),
    Rare      = Color3.fromRGB(51,170,255),
    Epic      = Color3.fromRGB(237,44,255),
    Legendary = Color3.fromRGB(255,150,0),
    Omega     = Color3.fromRGB(255,20,51)
}

-- ─── Tracer Line ──────────────────────────────────────────────────────────────
local Tracer = Drawing.new("Line")
Tracer.Thickness = 1.3
Tracer.Color = Color3.fromRGB(255,50,50)
Tracer.Transparency = 1
Tracer.Visible = false

-- ─── FOV Lines RGB (8 เส้น Drawing ใช้ได้ทุก executor) ────────────────────────
local FOV_Lines = {}
for i = 1, 8 do
    FOV_Lines[i] = Drawing.new("Line")
    FOV_Lines[i].Visible   = false
    FOV_Lines[i].Thickness = 2
end
local RGB_Speed = 1.5

local function updateFOVLines(visible)
    local Center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local Time   = tick() * RGB_Speed
    for i = 1, 8 do
        local a1 = math.rad((i-1)*45)
        local a2 = math.rad(i*45)
        FOV_Lines[i].From  = Center + Vector2.new(math.cos(a1)*FOVRadius, math.sin(a1)*FOVRadius)
        FOV_Lines[i].To    = Center + Vector2.new(math.cos(a2)*FOVRadius, math.sin(a2)*FOVRadius)
        FOV_Lines[i].Color = Color3.fromHSV((Time + (i/8)) % 1, 1, 1)
        FOV_Lines[i].Visible = visible
    end
end

-- ─── Load WindUI ──────────────────────────────────────────────────────────────
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "HYPER X HUB | BLOCK SPIN",
    Icon  = "zap",
    Author = "https://discord.gg/AJyRzwqXFc",
    Folder = "ZeusClean",
    Size   = UDim2.fromOffset(580,460),
    MinSize = Vector2.new(560,350),
    MaxSize = Vector2.new(850,560),
    Transparent = true,
    Theme  = "Dark",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = true,
    ScrollBarEnabled = false,
    User = {
        Enabled   = true,
        Anonymous = false,
        Name  = LocalPlayer.Name,
        Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId,
        Callback = function() end,
    },
})
Window:EditOpenButton({ Enabled = false })

-- ─── Toggle Button ────────────────────────────────────────────────────────────
local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "HYPER_Toggle"; ToggleGui.ResetOnSpawn = false
pcall(function() ToggleGui.Parent = CoreGui end)
if not ToggleGui.Parent then ToggleGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ToggleBtn = Instance.new("ImageButton")
ToggleBtn.Size = UDim2.new(0,79,0,79)
ToggleBtn.Position = UDim2.new(0,20,0.5,-25)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Image = "rbxassetid://76656140868269"
ToggleBtn.Active = true; ToggleBtn.Draggable = true
ToggleBtn.Parent = ToggleGui

local UIVisible = true
local function ToggleUI()
    UIVisible = not UIVisible
    if Window.UI then Window.UI.Enabled = UIVisible else Window:Toggle() end
end
ToggleBtn.MouseButton1Click:Connect(function()
    ToggleBtn:TweenSize(UDim2.new(0,56,0,56),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.12,true,function()
        ToggleBtn:TweenSize(UDim2.new(0,79,0,79),Enum.EasingDirection.Out,Enum.EasingStyle.Quad,0.12,true)
    end)
    ToggleUI()
end)
UserInputService.InputBegan:Connect(function(input,processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.T then ToggleUI() end
end)

if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

-- ─── Helpers ──────────────────────────────────────────────────────────────────
local function getPing()
    local gui = LocalPlayer:FindFirstChild("PlayerGui"); if not gui then return 0.2 end
    local stats = gui:FindFirstChild("NetworkStats"); if not stats then return 0.2 end
    local lbl = stats:FindFirstChild("PingLabel"); if not lbl then return 0.2 end
    local n = tonumber(lbl.Text:match("%d+")); if not n then return 0.2 end
    local p = n/1000; return (p<0 or p>2) and 0.2 or p
end

local function isPlayerExcluded(name)
    for _,v in ipairs(excludedPlayerNames) do
        if v~="" and string.find(string.lower(name),string.lower(v)) then return true end
    end
    return false
end

local function getClosestTarget()
    local closest,shortest = nil, FOVRadius
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local head = player.Character:FindFirstChild("Head")
            local hum  = player.Character:FindFirstChild("Humanoid")
            local hrp  = player.Character:FindFirstChild("HumanoidRootPart")
            if head and hum and hum.Health > 0 and hrp then
                local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(sp.X,sp.Y) - center).Magnitude
                    if dist <= FOVRadius and not isPlayerExcluded(player.Name) and dist < shortest then
                        shortest = dist; closest = player
                    end
                end
            end
        end
    end
    return closest
end

local function isBehindWall(startPos, endPos)
    if not startPos or not endPos then return false end
    local dir = endPos - startPos
    if dir.Magnitude < 1 then return false end
    local ignore = {}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end
    if CurrentTarget and CurrentTarget.Character then table.insert(ignore, CurrentTarget.Character) end
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(startPos, dir, params)
    if not result then return false end
    -- ตรวจว่าโดนอะไร ถ้าโดน character ของ target ถือว่าไม่ได้ถูกบล็อก
    local hitInstance = result.Instance
    if hitInstance then
        local parent = hitInstance.Parent
        if CurrentTarget and CurrentTarget.Character then
            for _,desc in ipairs(CurrentTarget.Character:GetDescendants()) do
                if desc == hitInstance then return false end
            end
        end
    end
    return true
end

local function isShotgun()
    local char = LocalPlayer.Character; if not char then return false end
    for _,tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local a = tool:GetAttribute("AmmoType")
            if a == "shotgun" or a == "shootgun" then return true end
        end
    end
    return false
end

-- ─── Position History & Prediction ────────────────────────────────────────────
RunService.Heartbeat:Connect(function()
    for _,player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                PositionHistory[player] = PositionHistory[player] or {}
                table.insert(PositionHistory[player], {time=os.clock(), pos=hrp.Position})
                if #PositionHistory[player] > HISTORY_SIZE then table.remove(PositionHistory[player],1) end
            else PositionHistory[player] = nil end
        end
    end
end)
Players.PlayerRemoving:Connect(function(p) PositionHistory[p] = nil end)

local function calculateVelocity(player)
    local hist = PositionHistory[player]
    if not hist or #hist < 2 then return Vector3.new() end
    local totalVel,count = Vector3.new(),0
    for i=2,#hist do
        local dt = hist[i].time - hist[i-1].time
        if dt > 0 then totalVel = totalVel + (hist[i].pos - hist[i-1].pos)/dt; count=count+1 end
    end
    if count==0 then return Vector3.new() end
    local avg = totalVel/count
    if avg.Y > SKY_Y_THRESHOLD then
        return Vector3.new(avg.X*1.15, math.clamp(avg.Y*0.85,0,400), avg.Z*1.15)
    end
    return avg
end

local function predictPosition(targetPart)
    if not targetPart then return Vector3.zero end
    local char   = targetPart.Parent
    local player = char and Players:GetPlayerFromCharacter(char)
    if not player then return targetPart.Position end
    -- V2: ใช้ velocity history เฉลี่ยหลาย frame แม่นกว่า AssemblyLinearVelocity
    local vel  = calculateVelocity(player) or Vector3.zero
    local ping = getPing() or 0.1
    if ping < 0 then ping = 0.1 end
    -- clamp ping ไม่ให้ predict เกินไป
    ping = math.clamp(ping, 0.05, 0.5)
    local predicted = targetPart.Position + (vel * ping * PREDICT_FACTOR)
    -- smooth: lerp ระหว่าง current กับ predicted ตาม ping
    return predicted
end

-- ─── Remote ───────────────────────────────────────────────────────────────────
local Remote = nil
pcall(function()
    Remote = ReplicatedStorage:WaitForChild("Remotes",5):WaitForChild("Send",5)
end)

-- ─── Silent Aim + Silent Body + Wall Bang Hook ────────────────────────────────
local oldFire = nil
if Remote and Remote.FireServer then
    pcall(function()
        oldFire = hookfunction(Remote.FireServer, function(self, ...)
            if self ~= Remote then return oldFire(self, ...) end
            local args = {...}
            if (SilentAimEnabled or SilentBodyEnabled) and args[2] == "shoot_gun" and CurrentTarget then
                local targetPartName = SilentBodyEnabled and "HumanoidRootPart" or (SelectedAimPart or "Head")
                local char   = CurrentTarget.Character
                local aimPart = char and (char:FindFirstChild(targetPartName) or char:FindFirstChild("Head"))
                local hrp     = char and char:FindFirstChild("HumanoidRootPart")
                local hum     = char and char:FindFirstChild("Humanoid")
                if aimPart and hrp and hum and hum.Health > 0 then
                    local aimPos = predictPosition(aimPart)
                    local myHead = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                    local myPos  = myHead and myHead.Position or nil
                    if isShotgun() then
                        args[4] = CFrame.new(myPos, aimPos)
                        local pellets = {}
                        for i=1,6 do
                            local spread = Vector3.new(math.random(-2,2)*0.03, math.random(-2,2)*0.03, math.random(-2,2)*0.03)
                            table.insert(pellets, {[1]={Instance=aimPart, Normal=Vector3.new(0,1,0), Position=aimPos+spread}})
                        end
                        args[5] = pellets
                    else
                        local blocked = isBehindWall(myPos, aimPos)
                        if blocked then
                            -- Wall Bang: ยิงทะลุกำแพงได้ ไม่ block
                            args[4] = CFrame.new(myPos, aimPos)
                        else
                            args[4] = CFrame.new(myPos, aimPos)
                        end
                        args[5] = {[1]={[1]={Instance=aimPart, Normal=Vector3.new(0,1,0), Position=aimPos}}}
                    end
                    -- Hit effect
                    local ok, beam = pcall(function()
                        local p = Instance.new("Part")
                        p.Anchored=true; p.CanCollide=false
                        p.Size = Vector3.new(0.08,0.08,(aimPos - LocalPlayer.Character.Head.Position).Magnitude)
                        p.CFrame = CFrame.new(LocalPlayer.Character.Head.Position, aimPos)*CFrame.new(0,0,-p.Size.Z/2)
                        p.Material = Enum.Material.Neon; p.Transparency=0.35
                        p.Color = Color3.fromRGB(255,0,0); p.Parent=workspace
                        Debris:AddItem(p,4); return p
                    end)
                    if hum then
                        local prevHP = hum.Health
                        spawn(function()
                            wait(0.1)
                            if hum and hum.Health < prevHP then
                                if ok and beam then beam.Color = Color3.fromRGB(0,255,0) end
                                for _,p in ipairs(CurrentTarget.Character:GetDescendants()) do
                                    if p:IsA("BasePart") then
                                        local box = Instance.new("Part")
                                        box.Size = p.Size+Vector3.new(0.05,0.05,0.05)
                                        box.CFrame = p.CFrame; box.Anchored=true; box.CanCollide=false
                                        box.Material=Enum.Material.Neon; box.Color=Color3.fromRGB(255,0,0)
                                        box.Transparency=0.5; box.Parent=workspace
                                        TweenService:Create(box,TweenInfo.new(1.5,Enum.EasingStyle.Linear),{Transparency=1}):Play()
                                        Debris:AddItem(box,2)
                                    end
                                end
                                if aimPart then
                                    local blood = Instance.new("Part")
                                    blood.Size=Vector3.new(0.2,0.2,0.2); blood.Shape=Enum.PartType.Ball
                                    blood.Material=Enum.Material.Neon; blood.Color=Color3.fromRGB(255,0,0)
                                    blood.CFrame=CFrame.new(aimPart.Position)
                                    blood.Anchored=false; blood.CanCollide=false; blood.Parent=workspace
                                    local bv=Instance.new("BodyVelocity")
                                    bv.Velocity=Vector3.new(math.random(-5,5),math.random(5,10),math.random(-5,5))
                                    bv.P=5000; bv.MaxForce=Vector3.new(4000,4000,4000); bv.Parent=blood
                                    Debris:AddItem(blood,1)
                                end
                            end
                        end)
                    end
                end
            end
            return oldFire(self, unpack(args))
        end)
    end)
end

-- ─── Auto Heal ────────────────────────────────────────────────────────────────
local function stopAnimations()
    local char = LocalPlayer.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
    local anim = hum:FindFirstChildOfClass("Animator"); if not anim then return end
    for _,t in pairs(anim:GetPlayingAnimationTracks()) do t:Stop(0) end
end
local function getHealthTool()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then for _,t in pairs(bp:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("HealthRestoreAmount") then return t end end end
    if LocalPlayer.Character then for _,t in pairs(LocalPlayer.Character:GetChildren()) do if t:IsA("Tool") and t:GetAttribute("HealthRestoreAmount") then return t end end end
end
local function useHealthTool(tool)
    if healBusy then return end
    if tick()-lastHealUse < 0.5 then return end
    healBusy=true; lastHealUse=tick()
    local char = LocalPlayer.Character; if not char then healBusy=false; return end
    local old = char:FindFirstChildOfClass("Tool")
    tool.Parent=char; task.wait(0.05); pcall(function() tool:Activate() end)
    stopAnimations(); task.wait(0.25)
    if old and old.Parent==char then old.Parent=LocalPlayer.Backpack end
    healBusy=false
end
task.spawn(function()
    while true do
        task.wait(0.3)
        if autoHealEnabled then
            local char=LocalPlayer.Character
            if char and char:FindFirstChild("Humanoid") then
                local hum=char.Humanoid
                if hum.MaxHealth>0 and hum.Health>0 and (hum.Health/hum.MaxHealth*100)<=HEALTH_THRESHOLD then
                    local t=getHealthTool(); if t then useHealthTool(t) end
                end
            end
        end
    end
end)

-- ─── CallRemote Helper ────────────────────────────────────────────────────────
local function SafeCall(f,...) return pcall(f,...) end
local tu_unpack = table.unpack or unpack
local function CallRemote(remote,...)
    if not remote then return end
    local args={...}
    if remote.ClassName=="RemoteEvent" then
        if CounterTable and type(CounterTable.event)=="number" then
            CounterTable.event=CounterTable.event+1
            SafeCall(function(...) remote:FireServer(CounterTable.event,...) end, tu_unpack(args))
        end
    elseif remote.ClassName=="RemoteFunction" then
        if CounterTable and type(CounterTable.func)=="number" then
            CounterTable.func=CounterTable.func+1
            SafeCall(function(...) remote:InvokeServer(CounterTable.func,...) end, tu_unpack(args))
        end
    end
end

-- ─── NetGet ───────────────────────────────────────────────────────────────────
local function NetGet(...)
    if not CounterTable or not CounterTable.func then return end
    local args={...}
    CounterTable.func=(CounterTable.func or 0)+1
    local ok,result=pcall(function()
        local r=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Get")
        return r:InvokeServer(CounterTable.func, tu_unpack(args))
    end)
    return ok and result or nil
end

-- ─── Pickup Items ─────────────────────────────────────────────────────────────
local function CheckAndPickup()
    if not sucking then return end
    local dropped=workspace:FindFirstChild("DroppedItems"); if not dropped then return end
    local myHRP=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not myHRP then return end
    local now=tick(); local list={}
    for _,item in ipairs(dropped:GetChildren()) do
        if item:IsA("Model") then
            local part=item:FindFirstChildWhichIsA("BasePart")
            if part and (myHRP.Position-part.Position).Magnitude<=20 and (now-(lastPickupTimes[item] or 0))>=0 then
                table.insert(list,item); lastPickupTimes[item]=now
            end
        end
    end
    for _,item in ipairs(list) do spawn(function() NetGet("pickup_dropped_item",item) end) end
end
RunService.Heartbeat:Connect(function() pcall(CheckAndPickup) end)

-- ─── Melee Auto Attack ────────────────────────────────────────────────────────
local meleeNames={}
local MeleeFolder=ReplicatedStorage:WaitForChild("Items"):WaitForChild("melee")
for _,v in ipairs(MeleeFolder:GetChildren()) do table.insert(meleeNames,v.Name) end
local function isMeleeTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    if tool.Name=="Fists" then return true end
    for _,n in ipairs(meleeNames) do if tool.Name==n then return true end end
    return false
end
local function getActiveTool()
    local char=LocalPlayer.Character
    if char then for _,t in ipairs(char:GetChildren()) do if pcall(function() return t:IsA("Tool") end) and t:IsA("Tool") then return t end end end
    local bp=LocalPlayer:FindFirstChild("Backpack")
    if bp then for _,t in ipairs(bp:GetChildren()) do if pcall(function() return t:IsA("Tool") end) and t:IsA("Tool") then return t end end end
end
local function getPlayersInRange(radius)
    local list={}; local char=LocalPlayer.Character; if not char or not char.PrimaryPart then return list end
    local pos=char.PrimaryPart.Position
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer and p.Character and p.Character.PrimaryPart then
            local ok,mag=pcall(function() return (p.Character.PrimaryPart.Position-pos).Magnitude end)
            if ok and mag and mag<=radius then table.insert(list,p) end
        end
    end
    return list
end
local function AttackNearby()
    if not Remote then return end
    local char=LocalPlayer.Character; if not char or not char.PrimaryPart then return end
    local tool=getActiveTool(); if not tool or not isMeleeTool(tool) then return end
    local ok,parent=pcall(function() return tool.Parent end); if not ok or parent~=char then return end
    local targets=getPlayersInRange(scanRadius); if #targets==0 then return end
    local okPos,localPos=pcall(function() return char.PrimaryPart.Position end); if not okPos then return end
    local playerTargets,predictedPositions={},{}
    for _,player in pairs(targets) do
        if player and player.Character and player.Character.PrimaryPart then
            local head=player.Character:FindFirstChild("Head")
            local hrp=player.Character.PrimaryPart
            if head and hrp then
                table.insert(playerTargets,player)
                table.insert(predictedPositions, predictPosition(head))
            end
        end
    end
    if #playerTargets==0 then return end
    local lookCF=CFrame.lookAt(localPos, predictedPositions[1])
    pcall(function() CallRemote(Remote,tu_unpack({"melee_attack",tool,playerTargets,lookCF,0.75})) end)
end
local function StartAutoAttack()
    if autoAttackRunning then return end
    autoAttackRunning=true
    task.spawn(function()
        while autoAttackRunning do
            task.wait(scanInterval)
            if hookEnabled and LocalPlayer and LocalPlayer.Character and LocalPlayer.Character.PrimaryPart then
                pcall(AttackNearby)
            end
        end
    end)
end
StartAutoAttack()

-- ─── Weapon Mods ──────────────────────────────────────────────────────────────
local GunsFolder = ReplicatedStorage:WaitForChild("Items"):WaitForChild("gun")
local GunModsEnabled = false
local FireRateValue=1000; local AccuracyValue=1; local RecoilValue=0
local function isGunTool(tool)
    if not tool or not tool:IsA("Tool") then return false end
    return GunsFolder:FindFirstChild(tool.Name)~=nil or tool:FindFirstChild("Handle")~=nil
end
local function applyGodGun(tool)
    if not tool or not isGunTool(tool) then return end
    pcall(function()
        tool:SetAttribute("fire_rate", FireRateValue)
        tool:SetAttribute("accuracy", AccuracyValue)
        tool:SetAttribute("Recoil",   RecoilValue)
        tool:SetAttribute("Durability", 999999999)
        tool:SetAttribute("automatic", true)
    end)
    task.spawn(function()
        for i=1,20 do
            local attrs=tool:GetAttributes(); local keys={}
            for k in pairs(attrs) do table.insert(keys,k) end
            table.sort(keys)
            if #keys>=11 then
                local k=keys[11]
                for j=1,5 do pcall(function() tool:SetAttribute(k,true) end); task.wait(0.01) end
            end
            task.wait(0.1)
        end
    end)
end
RunService.Heartbeat:Connect(function()
    if not GunModsEnabled then return end
    local char=LocalPlayer.Character; if not char then return end
    for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") and isGunTool(t) then pcall(applyGodGun,t) end end
end)
local OriginalValues={}
local function modifyFists(tool, enable)
    if not tool then return end
    local attrs=tool:GetAttributes(); local keys={}
    for k in pairs(attrs) do table.insert(keys,k) end
    table.sort(keys)
    if #keys>=7 then
        local k6,k7=keys[6],keys[7]
        if enable then
            if OriginalValues[k6]==nil then OriginalValues[k6]=tool:GetAttribute(k6) end
            if OriginalValues[k7]==nil then OriginalValues[k7]=tool:GetAttribute(k7) end
            tool:SetAttribute(k6,360); tool:SetAttribute(k7,20)
        else
            if OriginalValues[k6] then tool:SetAttribute(k6,OriginalValues[k6]) end
            if OriginalValues[k7] then tool:SetAttribute(k7,OriginalValues[k7]) end
        end
    end
end
local FistsBuffEnabled=false
local function checkAndModifyFists()
    local char=LocalPlayer.Character; local bp=LocalPlayer:FindFirstChild("Backpack")
    if not char or not bp then return end
    for _,t in ipairs(char:GetChildren()) do if isMeleeTool(t) then modifyFists(t,FistsBuffEnabled) end end
    for _,t in ipairs(bp:GetChildren()) do  if isMeleeTool(t) then modifyFists(t,FistsBuffEnabled) end end
end
RunService.Heartbeat:Connect(function() if FistsBuffEnabled then checkAndModifyFists() end end)

-- ─── ESP Helpers ──────────────────────────────────────────────────────────────
local function getESPColor(player)
    if isPlayerExcluded(player.Name) then return Color3.fromRGB(0,255,100) end
    if CurrentTarget==player then return Color3.fromRGB(255,50,50) end
    return Color3.fromRGB(255,255,255)
end

-- ─── ESP รวม (Name + Health + Distance + Box) ─────────────────────────────────
local function createESP(player)
    if espPlayers[player] then return end

    local nameText=Drawing.new("Text")
    nameText.Size=16; nameText.Center=true; nameText.Outline=true
    nameText.OutlineColor=Color3.fromRGB(0,0,0); nameText.Font=4; nameText.Visible=false

    local distText=Drawing.new("Text")
    distText.Size=12; distText.Center=true; distText.Outline=true
    distText.OutlineColor=Color3.fromRGB(0,0,0); distText.Font=4; distText.Visible=false

    -- Health Bar แนวนอน (เหมือน raw__16__)
    local hpBg=Drawing.new("Square"); hpBg.Filled=false; hpBg.Thickness=1
    hpBg.Color=Color3.fromRGB(0,0,0); hpBg.Transparency=0.9; hpBg.Visible=false
    local hpFill=Drawing.new("Square"); hpFill.Filled=true; hpFill.Transparency=0.9; hpFill.Visible=false

    -- Full Box ESP (4 เส้น)
    local boxLines={}
    for bi=1,4 do
        local bl=Drawing.new("Line"); bl.Thickness=1.5; bl.Transparency=0; bl.Visible=false
        boxLines[bi]=bl
    end

    local drawings={nameText,distText,hpBg,hpFill,boxLines[1],boxLines[2],boxLines[3],boxLines[4]}

    local conn=RunService.RenderStepped:Connect(function()
        if not player or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            for _,d in pairs(drawings) do d.Visible=false end; return
        end
        local char=player.Character
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local head=char:FindFirstChild("Head")
        local hum=char:FindFirstChild("Humanoid")
        if not hrp then for _,d in pairs(drawings) do d.Visible=false end; return end

        local myHRP=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist=myHRP and (hrp.Position-myHRP.Position).Magnitude or 0

        local sp,onScreen=Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen or sp.Z<=0 then for _,d in pairs(drawings) do d.Visible=false end; return end

        local espColor=getESPColor(player)
        local cx=sp.X; local cy=sp.Y-15

        -- ── Health Bar ──
        if healthESPEnabled and hum and hum.Health>0 then
            local perc=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
            local bw,bh=60,4; local bx=cx-bw/2; local by=cy-bh-2
            hpBg.Position=Vector2.new(bx,by); hpBg.Size=Vector2.new(bw,bh); hpBg.Visible=true
            hpFill.Position=Vector2.new(bx,by); hpFill.Size=Vector2.new(bw*perc,bh)
            hpFill.Color=Color3.fromHSV(perc*0.333,0.8,0.9); hpFill.Visible=true
            cy=cy-bh-6
        else hpBg.Visible=false; hpFill.Visible=false end

        -- ── ชื่อ ──
        if nameESPEnabled then
            local sz=math.floor(math.clamp(42-(42-14)*math.clamp(dist/50,0,1),14,42))
            nameText.Text=player.Name; nameText.Size=sz; nameText.Color=espColor
            nameText.Position=Vector2.new(cx,cy-16); nameText.Visible=true
        else nameText.Visible=false end

        -- ── ระยะ ──
        if distanceESPEnabled then
            distText.Text=string.format("%.0f studs",dist)
            distText.Position=Vector2.new(cx,sp.Y+20); distText.Color=espColor; distText.Visible=true
        else distText.Visible=false end

        -- ── Box ESP (4 เส้นรอบตัว) ──
        if boxESPEnabled and head then
            local headPos=char.Head.Position+Vector3.new(0,0.5,0)
            local feetPos=hrp.Position-Vector3.new(0,3,0)
            local topSP,topVis=Camera:WorldToViewportPoint(headPos)
            local botSP,botVis=Camera:WorldToViewportPoint(feetPos)
            if topVis and botVis and topSP.Z>0 and botSP.Z>0 then
                local bh2=math.abs(botSP.Y-topSP.Y); local bw2=bh2*0.55
                local bcx=(topSP.X+botSP.X)/2
                local top2=topSP.Y; local bot2=botSP.Y
                local left=bcx-bw2/2; local right=bcx+bw2/2
                boxLines[1].From=Vector2.new(left,top2);  boxLines[1].To=Vector2.new(right,top2)
                boxLines[2].From=Vector2.new(left,bot2);  boxLines[2].To=Vector2.new(right,bot2)
                boxLines[3].From=Vector2.new(left,top2);  boxLines[3].To=Vector2.new(left,bot2)
                boxLines[4].From=Vector2.new(right,top2); boxLines[4].To=Vector2.new(right,bot2)
                for bi=1,4 do boxLines[bi].Color=espColor; boxLines[bi].Visible=true end
            else for bi=1,4 do boxLines[bi].Visible=false end end
        else for bi=1,4 do boxLines[bi].Visible=false end end
    end)

    espPlayers[player]={conn=conn, drawings=drawings}
end

local function removeESP(player)
    if espPlayers[player] then
        for _,d in pairs(espPlayers[player].drawings) do pcall(function() if d.Visible~=nil then d.Visible=false end end) end
        pcall(function() espPlayers[player].conn:Disconnect() end)
        espPlayers[player]=nil
    end
end

-- ─── Corner Box ยังคงไว้สำหรับ Toggle แยก ─────────────────────────────────────
local function createBoxESP(player) end  -- รวมใน createESP แล้ว
local function removeBoxESP(player) end

-- ─── Skeleton ESP ─────────────────────────────────────────────────────────────
local skeletonJoints={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
}
local function createSkeleton(player)
    if skeletonConnections[player] then return end
    local lines={}
    local conn=RunService.RenderStepped:Connect(function()
        if not skeletonESPEnabled or not player or not player.Character then
            for _,l in pairs(lines) do l.Visible=false end; return
        end
        local char=player.Character
        local hrp=char:FindFirstChild("HumanoidRootPart")
        local hum=char:FindFirstChild("Humanoid")
        if not hrp or not hum or hum.Health<=0 then for _,l in pairs(lines) do l.Visible=false end; return end
        local espColor=getESPColor(player)
        for i,pair in ipairs(skeletonJoints) do
            local p1=char:FindFirstChild(pair[1]); local p2=char:FindFirstChild(pair[2])
            if not lines[i] then
                lines[i]=Drawing.new("Line"); lines[i].Thickness=1.5; lines[i].Transparency=0.2
            end
            lines[i].Color=espColor
            if p1 and p2 then
                local sp1,on1=Camera:WorldToViewportPoint(p1.Position)
                local sp2,on2=Camera:WorldToViewportPoint(p2.Position)
                if on1 and on2 and sp1.Z>0 and sp2.Z>0 then
                    lines[i].From=Vector2.new(sp1.X,sp1.Y); lines[i].To=Vector2.new(sp2.X,sp2.Y); lines[i].Visible=true
                else lines[i].Visible=false end
            else lines[i].Visible=false end
        end
    end)
    skeletonConnections[player]={conn=conn, lines=lines}
end
local function removeSkeleton(player)
    if skeletonConnections[player] then
        for _,l in pairs(skeletonConnections[player].lines) do pcall(function() l:Remove() end) end
        pcall(function() skeletonConnections[player].conn:Disconnect() end)
        skeletonConnections[player]=nil
    end
end

-- ─── Highlight ESP ────────────────────────────────────────────────────────────
local function updateHighlight(player)
    if player==LocalPlayer then return end
    if playerHighlights[player] then pcall(function() playerHighlights[player]:Destroy() end); playerHighlights[player]=nil end
    if not highlightEnabled then return end
    local char=player.Character; if not char then return end
    local hl=Instance.new("Highlight")
    hl.Adornee=char; hl.FillColor=Color3.fromRGB(0,170,255)
    hl.OutlineColor=Color3.fromRGB(0,255,255); hl.FillTransparency=0.65
    hl.OutlineTransparency=0.1; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent=char; playerHighlights[player]=hl
end

-- ─── Inventory ESP (Billboard) ────────────────────────────────────────────────
local function registerItems(folder)
    for _,tool in ipairs(folder:GetChildren()) do
        if tool:IsA("Tool") then
            local handle=tool:FindFirstChild("Handle")
            local displayName=tool:GetAttribute("DisplayName") or tool.Name
            local itemId=tool:GetAttribute("ItemId") or tool:GetAttribute("Id") or tool.Name
            local rarity=tool:GetAttribute("RarityName") or "Common"
            local imageId=tool:GetAttribute("ImageId") or "rbxassetid://7072725737"
            local key
            if handle then
                local mesh=handle:FindFirstChildOfClass("SpecialMesh")
                if mesh and mesh.MeshId~="" then key=mesh.MeshId..(mesh.TextureId or "").."_RARITY_"..rarity
                elseif handle:IsA("MeshPart") and handle.MeshId~="" then key=handle.MeshId..(handle.TextureID or "").."_RARITY_"..rarity end
            end
            if not key and itemId and itemId~="" and itemId~=tool.Name then key="ITEMID_"..itemId.."_RARITY_"..rarity end
            if not key then key="NAME_"..displayName.."_"..tool.Name.."_RARITY_"..rarity end
            WeaponRegistry[key]={Name=displayName, Rarity=rarity, ImageId=imageId, ToolName=tool.Name}
        end
    end
end
local function getItemKey(tool)
    local handle=tool:FindFirstChild("Handle")
    local displayName=tool:GetAttribute("DisplayName") or tool.Name
    local itemId=tool:GetAttribute("ItemId") or tool:GetAttribute("Id") or tool.Name
    local rarity=tool:GetAttribute("RarityName") or "Common"
    if handle then
        local mesh=handle:FindFirstChildOfClass("SpecialMesh")
        if mesh and mesh.MeshId~="" then return mesh.MeshId..(mesh.TextureId or "").."_RARITY_"..rarity end
        if handle:IsA("MeshPart") and handle.MeshId~="" then return handle.MeshId..(handle.TextureID or "").."_RARITY_"..rarity end
    end
    if itemId and itemId~="" and itemId~=tool.Name then return "ITEMID_"..itemId.."_RARITY_"..rarity end
    return "NAME_"..displayName.."_"..tool.Name.."_RARITY_"..rarity
end
local function getWeaponInfo(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    return WeaponRegistry[getItemKey(tool)]
end

-- ─── Inventory ESP แบบรูปภาพ (BillboardGui) ──────────────────────────────────
local InvBillboards = {}  -- เก็บ BillboardGui ต่อผู้เล่น

local function getPlayerTools(player)
    local tools = {}; local char = player.Character
    for _, bag in ipairs({"Backpack","StarterGear","StarterPack"}) do
        local b = player:FindFirstChild(bag)
        if b then
            for _, t in ipairs(b:GetChildren()) do
                if t:IsA("Tool") and t.Name ~= "Fists" then table.insert(tools, t) end
            end
        end
    end
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= "Fists" then table.insert(tools, t) end
        end
    end
    return tools
end

local function removeInvBillboard(player)
    if InvBillboards[player] then
        pcall(function() InvBillboards[player]:Destroy() end)
        InvBillboards[player] = nil
    end
end

local function buildInvBillboard(player)
    removeInvBillboard(player)
    if not inventoryESPEnabled then return end
    local char = player.Character; if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end

    local tools = getPlayerTools(player)
    local infos = {}
    for _, t in ipairs(tools) do
        local info = getWeaponInfo(t)
        if info then table.insert(infos, info) end
    end
    if #infos == 0 then return end

    local ICON = 26   -- ขนาด icon แต่ละอัน
    local GAP  = 4
    local totalW = #infos * (ICON + GAP) - GAP

    local bb = Instance.new("BillboardGui")
    bb.Name          = "InvESP_" .. player.Name
    bb.Adornee       = hrp
    bb.Size          = UDim2.new(0, totalW + 16, 0, ICON + 20)
    bb.StudsOffset   = Vector3.new(0, 3.2, 0)
    bb.AlwaysOnTop   = true
    bb.ResetOnSpawn  = false
    bb.Parent        = char

    -- ชื่อผู้เล่นเล็กๆ ด้านบน
    local nameLabel = Instance.new("TextLabel", bb)
    nameLabel.Size  = UDim2.new(1, 0, 0, 14)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text  = player.Name
    nameLabel.Font  = Enum.Font.GothamBold
    nameLabel.TextSize = 11
    nameLabel.TextColor3  = Color3.fromRGB(255,255,255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center

    -- frame รวมไอคอน
    local row = Instance.new("Frame", bb)
    row.Size = UDim2.new(1, 0, 0, ICON)
    row.Position = UDim2.new(0, 0, 0, 16)
    row.BackgroundTransparency = 1

    local layout = Instance.new("UIListLayout", row)
    layout.FillDirection       = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment   = Enum.VerticalAlignment.Center
    layout.SortOrder           = Enum.SortOrder.LayoutOrder
    layout.Padding             = UDim.new(0, GAP)

    for i, info in ipairs(infos) do
        local rarityColor = RARITY_COLORS[info.Rarity] or Color3.fromRGB(255,255,255)

        -- กรอบ
        local slot = Instance.new("Frame", row)
        slot.Size = UDim2.new(0, ICON, 0, ICON)
        slot.BackgroundColor3 = Color3.fromRGB(10,10,10)
        slot.BackgroundTransparency = 0.2
        slot.LayoutOrder = i
        Instance.new("UICorner", slot).CornerRadius = UDim.new(0, 5)

        local stroke = Instance.new("UIStroke", slot)
        stroke.Color     = rarityColor
        stroke.Thickness = 1.8

        -- รูปไอเทม
        local img = Instance.new("ImageLabel", slot)
        img.Size = UDim2.new(1, -4, 1, -4)
        img.Position = UDim2.new(0, 2, 0, 2)
        img.BackgroundTransparency = 1
        img.Image = info.ImageId
        img.ScaleType = Enum.ScaleType.Fit
    end

    InvBillboards[player] = bb
end

-- อัปเดต billboard เมื่อ inventory เปลี่ยน
local invUpdateConnections = {}
local function setupInvWatch(player)
    if invUpdateConnections[player] then
        pcall(function() invUpdateConnections[player]:Disconnect() end)
        invUpdateConnections[player] = nil
    end
    local function refresh()
        if inventoryESPEnabled then buildInvBillboard(player) end
    end
    -- watch backpack
    local bp = player:FindFirstChild("Backpack")
    if bp then
        invUpdateConnections[player] = bp.ChildAdded:Connect(function() task.wait(0.1); refresh() end)
        bp.ChildRemoved:Connect(function() task.wait(0.1); refresh() end)
    end
end

local function clearInventoryDrawings(player)
    removeInvBillboard(player)
    if invUpdateConnections[player] then
        pcall(function() invUpdateConnections[player]:Disconnect() end)
        invUpdateConnections[player] = nil
    end
    -- compat: InventoryDrawings ไม่ใช้แล้ว
    InventoryDrawings[player] = nil
end

-- ─── Load All ESP ─────────────────────────────────────────────────────────────
local function loadAllESP()
    for _,p in pairs(Players:GetPlayers()) do
        if p~=LocalPlayer then createESP(p); createSkeleton(p) end
    end
    Players.PlayerAdded:Connect(function(p)
        if p~=LocalPlayer then
            p.CharacterAdded:Connect(function()
                task.wait(0.1)
                createESP(p); createSkeleton(p); updateHighlight(p)
            end)
        end
    end)
    Players.PlayerRemoving:Connect(function(p)
        removeESP(p); removeSkeleton(p)
        if playerHighlights[p] then pcall(function() playerHighlights[p]:Destroy() end); playerHighlights[p]=nil end
        clearInventoryDrawings(p)
    end)
end
loadAllESP()

for _,fname in ipairs({"gun","melee","throwable","consumable","farming","misc","rod","fish"}) do
    local f=ReplicatedStorage:WaitForChild("Items"):FindFirstChild(fname)
    if f then registerItems(f) end
end

-- ─── Walk Speed ───────────────────────────────────────────────────────────────
local function setupWalkSpeed(char)
    local hum=char:WaitForChild("Humanoid"); local hrp=char:WaitForChild("HumanoidRootPart")
    if walkConn then pcall(function() walkConn:Disconnect() end) end
    walkConn=RunService.RenderStepped:Connect(function()
        if walkSpeedEnabled and hum and hrp and hum.MoveDirection.Magnitude>0 then
            hrp.CFrame=hrp.CFrame+(hum.MoveDirection.Unit*speedValue)
        end
    end)
end
LocalPlayer.CharacterAdded:Connect(function(c) task.wait(0.5); setupWalkSpeed(c) end)
if LocalPlayer.Character then setupWalkSpeed(LocalPlayer.Character) end

-- ─── Fly Jump ─────────────────────────────────────────────────────────────────
local function setupFlyJump(char)
    local hum=char:WaitForChild("Humanoid"); local hrp=char:WaitForChild("HumanoidRootPart")
    hum.UseJumpPower=true; hum.JumpPower=60
    if flyJumpConnection then pcall(function() flyJumpConnection:Disconnect() end) end
    flyJumpConnection=UserInputService.JumpRequest:Connect(function()
        if not FlyEnabled then return end
        if hrp and hrp.Parent then isFlyingUp=true; task.delay(0.5,function() isFlyingUp=false end) end
    end)
end
LocalPlayer.CharacterAdded:Connect(function(c) wait(0.5); setupFlyJump(c) end)
if LocalPlayer.Character then setupFlyJump(LocalPlayer.Character) end
ContextActionService:BindAction("FlyUp",function(_,state,input)
    if not FlyEnabled then return Enum.ContextActionResult.Pass end
    local isSpace=input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode==Enum.KeyCode.Space
    if isSpace then
        if state==Enum.UserInputState.Begin then isFlyingUp=true; return Enum.ContextActionResult.Sink
        elseif state==Enum.UserInputState.End then isFlyingUp=false; return Enum.ContextActionResult.Sink end
    end
    return Enum.ContextActionResult.Pass
end,false,Enum.KeyCode.Space)
RunService.RenderStepped:Connect(function()
    if FlyEnabled and isFlyingUp then
        local hrp=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Velocity=Vector3.new(hrp.Velocity.X,floatPower,hrp.Velocity.Z) end
    end
end)

-- ─── Snap Under Map ───────────────────────────────────────────────────────────
local function updateHRP_snap()
    if LocalPlayer.Character then HumanoidRootPart_snap=LocalPlayer.Character:WaitForChild("HumanoidRootPart",5) end
end
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); updateHRP_snap(); lockedY=nil; teleportActive=false end)
if LocalPlayer.Character then updateHRP_snap() end
local function performTeleport()
    if not HumanoidRootPart_snap then return end
    local pos=HumanoidRootPart_snap.Position
    local bot=Vector3.new(pos.X,pos.Y-maxHeight,pos.Z)
    HumanoidRootPart_snap.CFrame=CFrame.new(bot); lockedY=bot.Y
end
local function lockYPosition()
    if snapConnection then snapConnection:Disconnect() end
    snapConnection=RunService.Heartbeat:Connect(function()
        if teleportActive and lockedY and HumanoidRootPart_snap then
            local p=HumanoidRootPart_snap.Position
            if math.abs(p.Y-lockedY)>0.1 then HumanoidRootPart_snap.CFrame=CFrame.new(p.X,lockedY,p.Z) end
        end
    end)
end
local function toggleSnap(state)
    featureEnabled=state
    if state then
        clickCount=clickCount+1; if clickCount<2 then return end
        startY=HumanoidRootPart_snap and HumanoidRootPart_snap.Position.Y or nil
        teleportActive=true; performTeleport()
    else teleportActive=false; lockedY=nil; startY=nil end
end
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.Z and featureEnabled then toggleSnap(not teleportActive) end
end)
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); lockedY=nil; teleportActive=false; lockYPosition() end)
lockYPosition()

-- ─── Auto Finish ──────────────────────────────────────────────────────────────
local function setFinishPrompt(prompt)
    if prompt and prompt:IsA("ProximityPrompt") then prompt.HoldDuration=holdTime; prompt.MaxActivationDistance=20 end
end
local function tryHoldPrompt(prompt,duration)
    if not prompt or prompt:GetAttribute("__Busy") then return end
    prompt:SetAttribute("__Busy",true)
    pcall(function() if prompt.InputHoldBegin then prompt:InputHoldBegin() end end)
    pcall(function() if prompt.Trigger then prompt:Trigger() end end)
    task.wait(duration)
    pcall(function() if prompt.InputHoldEnd then prompt:InputHoldEnd() end end)
    prompt:SetAttribute("__Busy",nil)
end
local function findFinishPrompts()
    local found={}
    for _,char in pairs(workspace:GetChildren()) do
        local player=Players:GetPlayerFromCharacter(char)
        if player and not isPlayerExcluded(player.Name) then
            local hrp=char:FindFirstChild("HumanoidRootPart")
            if hrp then local p=hrp:FindFirstChild("FinishPrompt"); if p then setFinishPrompt(p); table.insert(found,p) end end
        end
    end
    return found
end
task.spawn(function()
    while true do task.wait(0.4)
        if fastFinishEnabled then
            for _,prompt in ipairs(findFinishPrompts()) do task.spawn(function() tryHoldPrompt(prompt,holdTime) end) end
        end
    end
end)

-- ─── Dropped Items ESP ────────────────────────────────────────────────────────
local gethui=gethui or function() return CoreGui end
local GuiContainer=gethui():FindFirstChild("MysticHub_ESP_Container")
if not GuiContainer then GuiContainer=Instance.new("Folder"); GuiContainer.Name="MysticHub_ESP_Container"; GuiContainer.Parent=gethui() end
local droppedESP_UI={}; local itemESPEnabled=true
local droppedRarityColors={
    Common=Color3.fromRGB(220,220,220), Uncommon=Color3.fromRGB(99,255,52),
    Rare=Color3.fromRGB(51,170,255), Epic=Color3.fromRGB(237,44,255),
    Legendary=Color3.fromRGB(255,150,0), Omega=Color3.fromRGB(255,20,51)
}
local droppedDB={}
local function formatImageId(id)
    if not id then return nil end
    if type(id)=="number" or (type(id)=="string" and tonumber(id)) then return "rbxassetid://"..tostring(id) end
    if type(id)=="string" and (id:find("rbxassetid://") or id:find("http")) then return id end
end
pcall(function()
    local ItemsFolder=ReplicatedStorage:FindFirstChild("Items"); if not ItemsFolder then return end
    for _,folder in ipairs(ItemsFolder:GetChildren()) do
        for _,item in ipairs(folder:GetChildren()) do
            local dispName=item:GetAttribute("DisplayName") or item.Name
            local rarity=item:GetAttribute("RarityName") or "Common"
            local img=formatImageId(item:GetAttribute("ImageId"))
            if not img then local h=item:FindFirstChild("Handle"); if h then if h:IsA("MeshPart") and h.TextureID~="" then img=formatImageId(h.TextureID) else local m=h:FindFirstChildOfClass("SpecialMesh"); if m and m.TextureId~="" then img=formatImageId(m.TextureId) end end end end
            img=img or "rbxassetid://7072725737"
            droppedDB[item.Name:lower()]={Name=dispName, Rarity=rarity, ImageId=img}
        end
    end
end)
local function createDroppedBillboard(model)
    local target=model:FindFirstChild("PickUpZone") or model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart
    if not target then return nil end
    local info=droppedDB[model.Name:lower()]
    local rarityColor=info and droppedRarityColors[info.Rarity] or Color3.fromRGB(220,220,220)
    local imageId=info and info.ImageId or "rbxassetid://7072725737"
    local displayName=info and info.Name or model.Name
    local amount=model:GetAttribute("Amount") or 1
    local bb=Instance.new("BillboardGui")
    bb.Name="DroppedESP_"..model.Name; bb.Adornee=target
    bb.Size=UDim2.new(0,100,0,20); bb.StudsOffset=Vector3.new(0,1,0)
    bb.AlwaysOnTop=true; bb.Parent=GuiContainer
    local main=Instance.new("Frame",bb); main.Size=UDim2.new(1,0,1,0); main.BackgroundTransparency=1
    local layout=Instance.new("UIListLayout",main)
    layout.FillDirection=Enum.FillDirection.Horizontal; layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Padding=UDim.new(0,3)
    local iconF=Instance.new("Frame",main); iconF.Size=UDim2.new(0,18,0,18)
    iconF.BackgroundColor3=Color3.fromRGB(15,15,15); iconF.BackgroundTransparency=0.15; iconF.LayoutOrder=1
    Instance.new("UICorner",iconF).CornerRadius=UDim.new(1,0)
    local stroke=Instance.new("UIStroke",iconF); stroke.Color=rarityColor; stroke.Thickness=1.5
    local imgLbl=Instance.new("ImageLabel",iconF); imgLbl.Size=UDim2.new(1,-4,1,-4); imgLbl.Position=UDim2.new(0,2,0,2)
    imgLbl.BackgroundTransparency=1; imgLbl.Image=imageId
    local badge=Instance.new("Frame",main); badge.AutomaticSize=Enum.AutomaticSize.X
    badge.Size=UDim2.new(0,0,0,16); badge.BackgroundColor3=Color3.fromRGB(10,10,10)
    badge.BackgroundTransparency=0.25; badge.LayoutOrder=2
    Instance.new("UICorner",badge).CornerRadius=UDim.new(0.5,0)
    local pad=Instance.new("UIPadding",badge); pad.PaddingLeft=UDim.new(0,6); pad.PaddingRight=UDim.new(0,6)
    local lbl=Instance.new("TextLabel",badge); lbl.AutomaticSize=Enum.AutomaticSize.X
    lbl.Size=UDim2.new(0,0,1,0); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.SourceSansBold
    lbl.TextSize=10; lbl.TextColor3=Color3.fromRGB(255,255,255)
    lbl.Text=(amount>1) and (displayName.." x"..tostring(amount)) or displayName
    return bb
end
RunService.RenderStepped:Connect(function()
    for model,gui in pairs(droppedESP_UI) do if not model or not model.Parent then if gui and gui.Parent then gui:Destroy() end; droppedESP_UI[model]=nil end end
    if not itemESPEnabled then for _,gui in pairs(droppedESP_UI) do if gui then gui.Enabled=false end end; return end
    local dropped=workspace:FindFirstChild("DroppedItems"); if not dropped then return end
    local root=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if not root then return end
    for _,model in ipairs(dropped:GetChildren()) do
        if model:IsA("Model") and model.Name~="Money" and not model:GetAttribute("Locked") then
            local target=model:FindFirstChild("PickUpZone") or model:FindFirstChildWhichIsA("BasePart") or model.PrimaryPart
            if target then
                local dist=(target.Position-root.Position).Magnitude
                if dist<=800 then
                    if not droppedESP_UI[model] or not droppedESP_UI[model].Parent then droppedESP_UI[model]=createDroppedBillboard(model)
                    else droppedESP_UI[model].Enabled=true end
                else if droppedESP_UI[model] then droppedESP_UI[model].Enabled=false end end
            end
        end
    end
end)
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.X then
        itemESPEnabled=not itemESPEnabled
        if not itemESPEnabled then for _,gui in pairs(droppedESP_UI) do if gui then gui.Enabled=false end end end
        if WindUI then WindUI:Notify({Title=itemESPEnabled and "✅ Item ESP ON" or "❌ Item ESP OFF",Duration=2}) end
    end
end)

-- ─── RenderStepped: FOV + Tracer ─────────────────────────────────────────────
RunService.RenderStepped:Connect(function()
    pcall(function()
        CurrentTarget=(SilentAimEnabled or SilentBodyEnabled) and getClosestTarget() or nil
        local TracerTarget=getClosestTarget()

        -- FOV 8 เส้น RGB
        updateFOVLines(SilentAimEnabled or SilentBodyEnabled)

        -- Tracer
        if TracerTarget and TracerTarget.Character then
            local char=TracerTarget.Character
            local hum=char:FindFirstChild("Humanoid")
            local targetPart=(SelectedAimPart=="HumanoidRootPart") and char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
            if hum and hum.Health>0 and targetPart then
                TracerSmoothedPos=TracerSmoothedPos:Lerp(targetPart.Position,SMOOTH_ALPHA)
                local sp,onScreen=Camera:WorldToViewportPoint(TracerSmoothedPos)
                if onScreen then
                    Tracer.Visible=true
                    Tracer.From=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
                    Tracer.To=Vector2.new(sp.X,sp.Y)
                    Tracer.Color=Color3.fromHSV((tick()*0.3)%1,1,1)
                    Tracer.Thickness=1.3
                    -- Diamond indicator รอบเป้า
                    if not TracerESP then
                        TracerESP={}
                        for i=1,4 do TracerESP[i]=Drawing.new("Line"); TracerESP[i].Thickness=1.5; TracerESP[i].Visible=false end
                    end
                    local sz=12
                    local cx,cy=sp.X,sp.Y
                    local pts={Vector2.new(cx,cy-sz),Vector2.new(cx+sz,cy),Vector2.new(cx,cy+sz),Vector2.new(cx-sz,cy)}
                    for i=1,4 do
                        TracerESP[i].From=pts[i]; TracerESP[i].To=pts[(i%4)+1]
                        TracerESP[i].Color=Color3.fromHSV((tick()*0.3)%1,1,1); TracerESP[i].Visible=true
                    end
                else
                    Tracer.Visible=false
                    if TracerESP then for _,l in pairs(TracerESP) do l.Visible=false end end
                end
            else Tracer.Visible=false; if TracerESP then for _,l in pairs(TracerESP) do l.Visible=false end end end
        else
            Tracer.Visible=false; TracerSmoothedPos=Vector3.new()
            if TracerESP then for _,l in pairs(TracerESP) do l.Visible=false end end
        end

        -- Inventory ESP (BillboardGui รูปภาพ - อัปเดตทุก 0.5s ไม่ต้อง poll ทุก frame)
    end)
end)

-- ─── TABS ─────────────────────────────────────────────────────────────────────
local Tab_general = Window:Tab({Title="General",    Icon="earth"})
local Tab_combat  = Window:Tab({Title="COMBAT",     Icon="crosshair"})
local Tab_weapon  = Window:Tab({Title="WEAPON",     Icon="layers"})
local Tab_ESP     = Window:Tab({Title="ESP",        Icon="eye"})
local Tab_visual  = Window:Tab({Title="Visual",     Icon="car"})
local Tab_player  = Window:Tab({Title="PLAYER",     Icon="person-standing"})
local Tab_server  = Window:Tab({Title="Server",     Icon="server"})

-- ═══════════════ GENERAL TAB ════════════════════════════════════════════════
Tab_general:Section({Title="AMMO CRATE"})
local function getCrateOptions()
    local map=workspace:FindFirstChild("Map"); if not map then return nil end
    local tiles=map:FindFirstChild("Tiles"); if not tiles then return nil end
    local gs=tiles:FindFirstChild("GunShopTile"); if not gs then return nil end
    local pw=gs:FindFirstChild("PatriotWeapons"); if not pw then return nil end
    local interior=pw:FindFirstChild("Interior"); if not interior then return nil end
    local crates=interior:FindFirstChild("Crates"); if not crates then return nil end
    local ammoCrate=crates:FindFirstChild("Ammo Crate"); if not ammoCrate then return nil end
    return ammoCrate:FindFirstChild("CrateOptions")
end
local function openCrateWithType(t)
    local opts=getCrateOptions(); if not opts then WindUI:Notify({Title="❌ ไม่พบ Ammo Crate",Duration=2}); return end
    local item=opts:FindFirstChild(t); if not item then WindUI:Notify({Title="❌ ไม่มี "..t,Duration=2}); return end
    local r=NetGet("open_crate",item,"money")
    WindUI:Notify({Title=r and ("🔫 "..t.." สำเร็จ") or "❌ เปิดไม่สำเร็จ",Duration=2})
end
local selectedBullet="Pistol"
Tab_general:Dropdown({Title="ประเภทกระสุน",Values={"Pistol","Rifle","Shotgun","Random"},Value="Pistol",Multi=false,Callback=function(v) selectedBullet=v end})
Tab_general:Button({Title="เปิด Ammo Crate",Callback=function()
    local t=selectedBullet
    if t=="Random" then local opts={"Pistol","Rifle","Shotgun"}; t=opts[math.random(1,#opts)]; WindUI:Notify({Title="🎲 สุ่มได้ "..t,Duration=1}) end
    openCrateWithType(t)
end})
Tab_general:Divider()
Tab_general:Button({Title="Claim All Quest",Callback=function()
    task.spawn(function()
        local ct=CounterTable; if not ct then return end
        local GetRemote=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Get")
        local qf=LocalPlayer.PlayerGui.Quests.QuestsHolder.QuestsScrollingFrame
        for _,child in ipairs(qf:GetChildren()) do
            ct.func=(ct.func or 0)+1
            pcall(function() GetRemote:InvokeServer(ct.func,"claim_quest",child.Name) end)
            task.wait(0.2)
        end
    end)
end})
Tab_general:Button({Title="Boost FPS (ภาพกาก)",Callback=function()
    local Lighting=game:GetService("Lighting"); local Terrain=workspace:FindFirstChildOfClass("Terrain")
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("BloomEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("DepthOfFieldEffect") then v:Destroy() end
    end
    Lighting.GlobalShadows=false; Lighting.Brightness=0; Lighting.FogEnd=9e9
    Lighting.EnvironmentDiffuseScale=0; Lighting.EnvironmentSpecularScale=0
    if Terrain then Terrain.WaterWaveSize=0; Terrain.WaterWaveSpeed=0; Terrain.WaterReflectance=0; Terrain.WaterTransparency=1 end
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then v.Material=Enum.Material.Plastic; v.Reflectance=0; v.CastShadow=false; v.Color=Color3.fromRGB(120,120,120)
        elseif v:IsA("Decal") or v:IsA("Texture") then v.Transparency=1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then v.Enabled=false end
    end
    WindUI:Notify({Title="✅ Boost FPS ON",Duration=2})
end})

-- ═══════════════ COMBAT TAB ════════════════════════════════════════════════
Tab_combat:Section({Title="Silent Aim:"})
Tab_combat:Toggle({Title="Silent Aim",Default=false,Callback=function(s)
    SilentAimEnabled=s; CurrentTarget=nil
    if not s then updateFOVLines(false) end
end})
Tab_combat:Toggle({Title="Silent Body",Desc="เล็งลำตัวแทนหัว",Default=false,Callback=function(s)
    SilentBodyEnabled=s; CurrentTarget=nil
end})
Tab_combat:Toggle({Title="Wall Bang",Desc="ยิงทะลุกำแพงได้",Default=false,Callback=function(s)
    -- Wall Bang ถูกรวมอยู่ใน hook แล้ว (isBehindWall ไม่ block)
    WindUI:Notify({Title=s and "✅ Wall Bang ON" or "❌ Wall Bang OFF",Duration=2})
end})
Tab_combat:Toggle({Title="Red Line Lock",Desc="Tracer ติดเป้าตลอด",Default=false,Callback=function(s) RedLineLock=s end})
Tab_combat:Slider({Title="FOV Radius",Value={Min=20,Max=800,Default=120},Callback=function(v) FOVRadius=tonumber(v) or 120 end})
Tab_combat:Dropdown({Title="Aim Part",Values={"Head","HumanoidRootPart","UpperTorso"},Value="Head",Callback=function(v) SelectedAimPart=v end})
Tab_combat:Slider({Title="RGB Speed",Desc="ความเร็วหมุนสี FOV",Value={Min=1,Max=10,Default=3},Callback=function(v)
    RGB_Speed = v * 0.5
end})
Tab_combat:Divider()
Tab_combat:Section({Title="Safe List:"})
Tab_combat:Input({Title="Safe Friend",Placeholder="พิมพ์ชื่อเพื่อน (เว้นวรรค)",Callback=function(input)
    excludedPlayerNames={}
    for name in string.gmatch(input,"%S+") do table.insert(excludedPlayerNames,name) end
end})

-- ═══════════════ WEAPON TAB ════════════════════════════════════════════════
Tab_weapon:Section({Title="GUN MODS:"})
Tab_weapon:Slider({Title="Fire Rate",Step=10,Value={Min=100,Max=10000,Default=1000},Callback=function(v) FireRateValue=v end})
Tab_weapon:Slider({Title="Accuracy",Step=0.01,Value={Min=0,Max=1,Default=1},Callback=function(v) AccuracyValue=v end})
Tab_weapon:Slider({Title="Recoil",Step=0.1,Value={Min=0,Max=10,Default=0},Callback=function(v) RecoilValue=v end})
Tab_weapon:Toggle({Title="Auto Apply Mods",Default=false,Callback=function(s)
    GunModsEnabled=s
    if s then WindUI:Notify({Title="✅ Auto Gun Mods ON",Duration=2}) end
end})
Tab_weapon:Divider()
Tab_weapon:Section({Title="MELEE:"})
Tab_weapon:Toggle({Title="Melee Aura (WideFists)",Default=false,Callback=function(s) FistsBuffEnabled=s; checkAndModifyFists() end})
Tab_weapon:Toggle({Title="Auto Attack",Default=false,Callback=function(s) hookEnabled=s end})
Tab_weapon:Slider({Title="Scan Radius",Step=1,Value={Min=5,Max=50,Default=20},Callback=function(v) scanRadius=v end})

-- ═══════════════ ESP TAB ════════════════════════════════════════════════════
Tab_ESP:Section({Title="Player ESP:"})
Tab_ESP:Toggle({Title="Name ESP",Default=false,Callback=function(s) nameESPEnabled=s end})
Tab_ESP:Toggle({Title="Box ESP",Default=false,Callback=function(s)
    boxESPEnabled=s
end})
Tab_ESP:Toggle({Title="Health Bar",Default=false,Callback=function(s) healthESPEnabled=s end})
Tab_ESP:Toggle({Title="Distance",Default=false,Callback=function(s) distanceESPEnabled=s end})
Tab_ESP:Toggle({Title="Skeleton ESP",Default=false,Callback=function(s) skeletonESPEnabled=s end})
Tab_ESP:Toggle({Title="Highlight",Default=false,Callback=function(s)
    highlightEnabled=s
    for _,p in pairs(Players:GetPlayers()) do updateHighlight(p) end
end})
Tab_ESP:Toggle({Title="Inventory Viewer (รูปภาพ)",Desc="แสดงไอเทมในกระเป๋าผู้เล่นอื่น",Default=false,Callback=function(s)
    inventoryESPEnabled=s
    if s then
        -- สร้าง billboard ให้ทุกคน
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LocalPlayer and p.Character then
                buildInvBillboard(p)
                setupInvWatch(p)
            end
        end
        WindUI:Notify({Title="✅ Inventory ESP ON",Duration=2})
    else
        -- ลบ billboard ทั้งหมด
        for _,p in ipairs(Players:GetPlayers()) do clearInventoryDrawings(p) end
        WindUI:Notify({Title="❌ Inventory ESP OFF",Duration=2})
    end
end})
Tab_ESP:Divider()
Tab_ESP:Section({Title="Ground Item ESP:"})
Tab_ESP:Toggle({Title="Item ESP (พื้น)",Desc="กด X เพื่อ toggle",Default=true,Callback=function(s)
    itemESPEnabled=s
    if not s then for _,gui in pairs(droppedESP_UI) do if gui then gui.Enabled=false end end end
    WindUI:Notify({Title=s and "✅ Item ESP ON" or "❌ Item ESP OFF",Duration=2})
end})

-- ═══════════════ VISUAL TAB ════════════════════════════════════════════════
Tab_visual:Section({Title="MOVEMENT:"})
Tab_visual:Toggle({Title="Walk Speed",Default=false,Callback=function(s)
    walkSpeedEnabled=s; WindUI:Notify({Title=s and "✅ Walk Speed ON" or "❌ Walk Speed OFF",Duration=2})
end})
Tab_visual:Slider({Title="Speed Multiplier",Value={Min=1,Max=10,Default=2},Callback=function(v) speedValue=v*0.05 end})
Tab_visual:Toggle({Title="Fly Jump",Default=false,Callback=function(s)
    FlyEnabled=s; if not s then isFlyingUp=false end
    WindUI:Notify({Title=s and "✅ Fly ON" or "❌ Fly OFF",Duration=2})
end})
Tab_visual:Slider({Title="Float Power",Value={Min=10,Max=150,Default=40},Callback=function(v) floatPower=v end})
Tab_visual:Toggle({Title="Infinite Stamina",Default=false,Callback=function(s)
    AutoSprintEnabled=s
    if s then
        pcall(function()
            local SprintModule=require(ReplicatedStorage.Modules.Game.Sprint)
            local consume_stamina=SprintModule.consume_stamina
            local SprintBar=getupvalue(consume_stamina,2).sprint_bar
            if SprintBar then OriginalSprintUpdate=SprintBar.update; SprintBar.update=function(...) return OriginalSprintUpdate(function() return 1 end) end end
        end)
        AutoSprintLoop=task.spawn(function()
            local ct=CounterTable; if not ct then return end
            local Send=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Send")
            while AutoSprintEnabled do
                ct.event=(ct.event or 0)+1; pcall(function() Send:FireServer(ct.event,"set_sprinting_1",true) end); task.wait(0.5)
                ct.event=(ct.event or 0)+1; pcall(function() Send:FireServer(ct.event,"set_sprinting_1",false) end); task.wait(0.1)
            end
            ct.event=(ct.event or 0)+1; pcall(function() Send:FireServer(ct.event,"set_sprinting_1",false) end)
        end)
        WindUI:Notify({Title="✅ Infinite Stamina ON",Duration=2})
    else
        if AutoSprintLoop then task.cancel(AutoSprintLoop); AutoSprintLoop=nil end
        pcall(function()
            local SprintModule=require(ReplicatedStorage.Modules.Game.Sprint)
            local SprintBar=getupvalue(SprintModule.consume_stamina,2).sprint_bar
            if SprintBar and OriginalSprintUpdate then SprintBar.update=OriginalSprintUpdate; OriginalSprintUpdate=nil end
        end)
        WindUI:Notify({Title="❌ Infinite Stamina OFF",Duration=2})
    end
end})
Tab_visual:Divider()
Tab_visual:Section({Title="AUTO HEAL:"})
Tab_visual:Toggle({Title="Auto Use Health Item",Default=false,Callback=function(s)
    autoHealEnabled=s; WindUI:Notify({Title=s and "✅ Auto Heal ON" or "❌ Auto Heal OFF",Duration=2})
end})
Tab_visual:Slider({Title="HP Threshold (%)",Value={Min=10,Max=99,Default=50},Callback=function(v) HEALTH_THRESHOLD=v end})
Tab_visual:Divider()
Tab_visual:Section({Title="MISC:"})
Tab_visual:Toggle({Title="Pickup Items",Default=false,Callback=function(s) sucking=s end})
Tab_visual:Toggle({Title="Anti Kill",Default=false,Callback=function(s)
    enabled=s; WindUI:Notify({Title=s and "✅ Anti Kill ON" or "❌ Anti Kill OFF",Duration=2})
end})
Tab_visual:Toggle({Title="Anti Ragdoll",Default=false,Callback=function(s)
    if not s then return end
    pcall(function()
        local ct=CounterTable; if not ct then return end
        local Send=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Send")
        task.spawn(function()
            while s do
                ct.event=(ct.event or 0)+1; Send:FireServer(ct.event,"end_ragdoll_early"); task.wait(0.3)
                ct.event=(ct.event or 0)+1; Send:FireServer(ct.event,"clear_ragdoll"); task.wait(0.3)
            end
        end)
    end)
end})
Tab_visual:Toggle({Title="Auto Respawn",Default=false,Callback=function(s)
    if not s then return end
    task.spawn(function()
        local ct=CounterTable; if not ct then return end
        local Send=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Send")
        while s do
            local char=LocalPlayer.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health<=0 then task.wait(6); if s then ct.event=(ct.event or 0)+1; Send:FireServer(ct.event,"death_screen_request_respawn") end end
            task.wait(0.5)
        end
    end)
end})
Tab_visual:Divider()
Tab_visual:Section({Title="PC HOLD (Z):"})
Tab_visual:Toggle({Title="Snap Under Map",Default=false,Callback=function(s) toggleSnap(s) end})
Tab_visual:Slider({Title="Snap Depth",Step=1,Value={Min=1,Max=100,Default=10},Callback=function(v)
    maxHeight=v
    if teleportActive and HumanoidRootPart_snap and startY then
        local bot=Vector3.new(HumanoidRootPart_snap.Position.X,startY-maxHeight,HumanoidRootPart_snap.Position.Z)
        HumanoidRootPart_snap.CFrame=CFrame.new(bot); lockedY=bot.Y
    end
end})

-- ═══════════════ PLAYER TAB ════════════════════════════════════════════════
Tab_player:Section({Title="PLAYER:"})
Tab_player:Toggle({Title="Auto Finish",Default=false,Callback=function(s)
    fastFinishEnabled=s
    WindUI:Notify({Title=s and "✅ Auto Finish ON" or "❌ Auto Finish OFF",Duration=2})
end})
Tab_player:Toggle({Title="Hide Name",Default=false,Callback=function(s)
    pcall(function()
        local char=LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        local hrp=char:WaitForChild("HumanoidRootPart")
        local gui=hrp:FindFirstChild("CharacterBillboardGui")
        if gui then local lbl=gui:FindFirstChild("PlayerName"); if lbl and lbl:IsA("TextLabel") then lbl.Visible=not s end end
    end)
end})

-- ═══════════════ SERVER TAB ════════════════════════════════════════════════
Tab_server:Section({Title="Server Info:"})
Tab_server:Button({Title="📋 Copy Server ID",Desc=game.JobId,Callback=function()
    if setclipboard then setclipboard(game.JobId); WindUI:Notify({Title="✅ คัดลอก Job ID แล้ว",Duration=2}) end
end})
Tab_server:Divider()
Tab_server:Section({Title="Server Tools:"})
local ServerCode=""
Tab_server:Input({Title="Join by Server Code",Placeholder="Paste JobId here...",Callback=function(v) ServerCode=v end})
Tab_server:Button({Title="Join Code",Icon="log-in",Callback=function()
    if ServerCode=="" then return end
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,ServerCode,LocalPlayer)
end})
Tab_server:Button({Title="Rejoin",Icon="refresh-ccw",Callback=function()
    game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId,game.JobId,LocalPlayer)
end})
Tab_server:Button({Title="Hop Server (Low Player)",Icon="shuffle",Callback=function()
    local HS=game:GetService("HttpService"); local TS=game:GetService("TeleportService"); local servers={}
    local ok,data=pcall(function()
        return HS:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",game.PlaceId)))
    end)
    if ok and data and data.data then
        for _,v in pairs(data.data) do if v.playing<v.maxPlayers and v.id~=game.JobId then table.insert(servers,v.id) end end
    end
    if #servers>0 then TS:TeleportToPlaceInstance(game.PlaceId,servers[math.random(1,#servers)],LocalPlayer)
    else WindUI:Notify({Title="❌ ไม่พบเซิร์ฟว่าง",Duration=3}) end
end})

-- ─── CharacterAdded + Inventory ESP refresh ──────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(char)
    for _,p in pairs(Players:GetPlayers()) do updateHighlight(p) end
end)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.1)
        updateHighlight(p)
        if inventoryESPEnabled then
            buildInvBillboard(p)
            setupInvWatch(p)
        end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if playerHighlights[p] then pcall(function() playerHighlights[p]:Destroy() end); playerHighlights[p]=nil end
    clearInventoryDrawings(p)
end)

-- loop rebuild billboard ทุก 1.5s (ไอเทมเปลี่ยนบ่อย)
task.spawn(function()
    while true do
        task.wait(1.5)
        if inventoryESPEnabled then
            for _,p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character then
                    buildInvBillboard(p)
                end
            end
        end
    end
end)
