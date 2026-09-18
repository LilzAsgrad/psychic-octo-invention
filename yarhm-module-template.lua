local module = {}
module["gameId"] = 0
module["Name"] = "MM2 Silent Aim"

-- ================== SERVICES ==================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

-- ================== CONFIG (module-scoped so hook can read them) ==================
local shootOffset = 2.8
local offsetToPingMult = 1
local knifeHookEnabled = false
local playerESP = false
local hideMeEsp = false
local autoShoot = false

-- ================== HELPERS ==================
local function findMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Backpack:FindFirstChild("Knife") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
    if getgenv().YARHMPlayerData then
        for name, data in pairs(getgenv().YARHMPlayerData) do
            if data and (data.Role == "Murderer" or data.role == "Murderer") then
                local found = Players:FindFirstChild(name)
                if found then return found end
            end
        end
    end
    return nil
end

local function findSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Backpack:FindFirstChild("Gun") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    return nil
end

local function findSheriffThatsNotMe()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Backpack:FindFirstChild("Gun") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    return nil
end

local function findNearestPlayer()
    if not LP.Character then return nil end
    local myHrp = LP.Character:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end
    local nearest, shortest = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (myHrp.Position - hrp.Position).Magnitude
                if d < shortest then shortest = d; nearest = p end
            end
        end
    end
    return nearest
end

local function getPredictedPosition(player, offset)
    if not player or not player.Character then return nil end
    local char = player.Character
    local playerHRP = char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart")
    local playerHum = char:FindFirstChild("Humanoid")
    if not playerHRP or not playerHum then return nil end

    local velocity = playerHRP.AssemblyLinearVelocity
    local moveDir = playerHum.MoveDirection

    local predicted = playerHRP.Position
        + (velocity * Vector3.new(0.75, 0.5, 0.75)) * (offset / 15)
        + moveDir * offset

    predicted = predicted * (((LP:GetNetworkPing() * 1000) * ((offsetToPingMult - 1) * 0.01)) + 1)
    return predicted
end

local function getKnifeCrosshairTarget()
    local cam = Workspace.CurrentCamera
    local vp = cam.ViewportSize
    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local best, bestDist = nil, 400

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local sp, on = cam:WorldToViewportPoint(hrp.Position)
                if on and sp.Z > 0 then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bestDist then best, bestDist = p, d end
                end
            end
        end
    end
    return best or findMurderer() or findNearestPlayer()
end

-- These are called by the namecall hook. Kept as globals so the hook can find them.
function getKnifeCrosshairTarget_Global()
    return getKnifeCrosshairTarget()
end

function calculatePrediction(player, _)
    return getPredictedPosition(player, shootOffset)
end

-- ================== COMPONENTS ==================
module[1] = { Type = "Text", Args = {"ESPs"} }

module[2] = {
    Type = "ButtonGrid",
    Toggleable = true,
    Args = {2, {
        Players = function(Self)
            playerESP = not playerESP
            FUNCTIONS.notification("Player ESP " .. (playerESP and "ON" or "OFF"))
        end,
        Hide_Me = function(Self)
            hideMeEsp = not hideMeEsp
            FUNCTIONS.notification("Hide Me " .. (hideMeEsp and "ON" or "OFF"))
        end,
    }}
}

module[3] = { Type = "Text", Args = {"Gun (Sheriff)"} }

module[4] = {
    Type = "Button",
    Args = {"Shoot Murderer", function(Self)
        if findSheriff() ~= LP then
            FUNCTIONS.notification("You're not sheriff/hero.")
            return
        end
        local murderer = findMurderer() or findSheriffThatsNotMe()
        if not murderer or not murderer.Character then
            FUNCTIONS.notification("No murderer to shoot.")
            return
        end
        if not LP.Character:FindFirstChild("Gun") then
            local hum = LP.Character:FindFirstChild("Humanoid")
            if LP.Backpack:FindFirstChild("Gun") and hum then
                hum:EquipTool(LP.Backpack:FindFirstChild("Gun"))
                task.wait(0.1)
            else
                FUNCTIONS.notification("You don't have the gun.")
                return
            end
        end
        local predicted = getPredictedPosition(murderer, shootOffset)
        if not predicted then return end
        local gun = LP.Character:FindFirstChild("Gun")
        if gun and gun:FindFirstChild("Shoot") then
            pcall(function()
                gun.Shoot:FireServer(
                    CFrame.new(LP.Character.RightHand.Position),
                    CFrame.new(predicted)
                )
            end)
            FUNCTIONS.notification("Shot fired at " .. murderer.Name)
        end
    end,}
}

module[5] = {
    Type = "Toggle",
    Args = {"Auto Shoot Murderer", function(Self, state)
        autoShoot = state
        FUNCTIONS.notification("Auto-shoot " .. (state and "ON" or "OFF"))
    end,}
}

module[6] = { Type = "Text", Args = {"Knife (Murderer)"} }

module[7] = {
    Type = "Toggle",
    Args = {"Knife Throw Hook (silent aim)", function(Self, state)
        knifeHookEnabled = state
        FUNCTIONS.notification("Knife hook " .. (state and "ENABLED" or "disabled"))
    end,}
}

module[8] = {
    Type = "Button",
    Args = {"Knife Throw to Closest", function(Self)
        if findMurderer() ~= LP then
            FUNCTIONS.notification("You're not murderer.")
            return
        end
        if not LP.Character:FindFirstChild("Knife") then
            local hum = LP.Character:FindFirstChild("Humanoid")
            if LP.Backpack:FindFirstChild("Knife") and hum then
                hum:EquipTool(LP.Backpack:FindFirstChild("Knife"))
                task.wait(0.1)
            else
                FUNCTIONS.notification("You don't have the knife.")
                return
            end
        end
        local target = findNearestPlayer()
        if not target then
            FUNCTIONS.notification("No target nearby.")
            return
        end
        local predicted = getPredictedPosition(target, shootOffset + 1)
        if not predicted then return end
        local knife = LP.Character:FindFirstChild("Knife")
        if knife then
            local ev = knife:FindFirstChild("Events")
            if ev and ev:FindFirstChild("KnifeThrown") then
                pcall(function()
                    ev.KnifeThrown:FireServer(
                        CFrame.new(LP.Character.RightHand.Position),
                        CFrame.new(predicted)
                    )
                end)
                FUNCTIONS.notification("Knife thrown at " .. target.Name)
            end
        end
    end,}
}

module[9] = { Type = "Text", Args = {"Prediction"} }

module[10] = {
    Type = "Input",
    Args = {"Shoot offset (default 2.8)", "Set", function(Self, text)
        local n = tonumber(text)
        if not n then FUNCTIONS.notification("Not a valid number.") return end
        shootOffset = n
        FUNCTIONS.notification("Offset set to " .. n)
    end,}
}

module[11] = {
    Type = "Input",
    Args = {"Offset-to-ping multiplier (default 1)", "Set", function(Self, text)
        local n = tonumber(text)
        if not n then FUNCTIONS.notification("Not a valid number.") return end
        offsetToPingMult = n
        FUNCTIONS.notification("Ping mult set to " .. n)
    end,}
}

module[12] = {
    Type = "Text",
    Args = {"Shoot offset 2.8 = balanced. Higher = more lead, lower = less. Ping mult scales with your ping."}
}

-- ================== BG_TASK (runs in coroutine by YARHM) ==================
module["BG_TASK"] = function()
    -- Guard: install namecall hook only once
    if getgenv().YARHM_MM2_KnifeHookInstalled then
        -- Update the callback's state via upvalues is fine since we reinstalled
    end

    -- Install namecall hook once for the whole session
    if not getgenv().YARHM_MM2_KnifeHookInstalled and hookmetamethod then
        getgenv().YARHM_MM2_KnifeHookInstalled = true

        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            local args = {...}
            if not checkcaller() and (method == "FireServer" or method == "fireServer") then
                local rname = tostring(self)
                if knifeHookEnabled and (rname == "KnifeThrown" or rname == "Throw" or rname == "ThrowKnife") then
                    local char = LP.Character
                    local knife = char and (char:FindFirstChild("Knife") or char:FindFirstChild("ThrowingKnife"))
                    if knife then
                        local target = getKnifeCrosshairTarget()
                        if target and target.Character then
                            local predictedPos = getPredictedPosition(target, shootOffset)
                            if predictedPos then
                                local handle = knife:FindFirstChild("Handle") or knife:FindFirstChild("KnifeHandle")
                                local originPos = handle and handle.Position
                                    or (Workspace.CurrentCamera.CFrame.Position - Vector3.new(0, 0.5, 0))
                                for i = 1, #args do
                                    if typeof(args[i]) == "CFrame" then
                                        args[i] = i == 1
                                            and CFrame.lookAt(originPos, predictedPos)
                                            or CFrame.new(predictedPos)
                                    elseif typeof(args[i]) == "Vector3" then
                                        args[i] = predictedPos
                                    end
                                end
                                if setnamecallmethod then setnamecallmethod(method) end
                                return oldNamecall(self, unpack(args))
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        print("[MM2 Silent Aim] Knife namecall hook installed.")
    end

    -- Try to hook PlayerDataChanged for role detection
    task.spawn(function()
        pcall(function()
            local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
            if not Remotes then return end
            local Gameplay = Remotes:WaitForChild("Gameplay", 5)
            if not Gameplay then return end
            local pd = Gameplay:WaitForChild("PlayerDataChanged", 5)
            if pd and pd:IsA("RemoteEvent") then
                pd.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then
                        getgenv().YARHMPlayerData = data
                    end
                end)
            end
        end)
    end)

    -- ESP loop
    task.spawn(function()
        local HighlightCache = {}
        while task.wait(1) do
            if not playerESP then
                for _, hl in pairs(HighlightCache) do hl:Destroy() end
                HighlightCache = {}
            else
                local murderer = findMurderer()
                local sheriff = findSheriff()
                for _, p in ipairs(Players:GetPlayers()) do
                    if p == LP and hideMeEsp then continue end
                    if p.Character then
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then
                            local hl = HighlightCache[p.Name]
                            if not hl or hl.Parent ~= p.Character then
                                if hl then hl:Destroy() end
                                hl = Instance.new("Highlight")
                                hl.Name = "YARHM_MM2_ESP"
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                hl.FillTransparency = 0.6
                                hl.OutlineTransparency = 0.2
                                hl.Adornee = p.Character
                                hl.Parent = p.Character
                                HighlightCache[p.Name] = hl
                            end
                            if p == murderer then
                                hl.FillColor = Color3.fromRGB(255, 40, 40)
                                hl.OutlineColor = Color3.fromRGB(255, 40, 40)
                            elseif p == sheriff then
                                hl.FillColor = Color3.fromRGB(40, 130, 255)
                                hl.OutlineColor = Color3.fromRGB(40, 130, 255)
                            else
                                hl.FillColor = Color3.fromRGB(40, 220, 90)
                                hl.OutlineColor = Color3.fromRGB(40, 220, 90)
                            end
                        end
                    end
                end
            end
        end
    end)

    -- Auto shoot loop
    task.spawn(function()
        while task.wait(0.2) do
            if autoShoot and findSheriff() == LP then
                local murderer = findMurderer() or findSheriffThatsNotMe()
                if murderer and murderer.Character then
                    local gun = LP.Character and LP.Character:FindFirstChild("Gun")
                    if not gun then
                        local hum = LP.Character and LP.Character:FindFirstChild("Humanoid")
                        if LP.Backpack:FindFirstChild("Gun") and hum then
                            hum:EquipTool(LP.Backpack:FindFirstChild("Gun"))
                            task.wait(0.1)
                            gun = LP.Character and LP.Character:FindFirstChild("Gun")
                        end
                    end
                    if gun and gun:FindFirstChild("Shoot") then
                        local predicted = getPredictedPosition(murderer, shootOffset)
                        if predicted then
                            pcall(function()
                                gun.Shoot:FireServer(
                                    CFrame.new(LP.Character.RightHand.Position),
                                    CFrame.new(predicted)
                                )
                            end)
                        end
                    end
                end
            end
        end
    end)
end

getgenv().Modules[#getgenv().Modules + 1] = module
return module
