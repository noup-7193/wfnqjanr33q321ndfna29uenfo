local plr = game.Players.LocalPlayer
local targetOre = "Abyssalite"
local targetTool = "Obsidian Pickaxe"
local basePos = Vector3.new(-7120, -680, -2530)

-- Зона фарма (Bounding Box) для дебага
local A, B = Vector3.new(-7184,-703,-2544), Vector3.new(-7057, -720, -2531)
local ZONE = {
    MIN = Vector3.new(math.min(A.X, B.X), math.min(A.Y, B.Y), math.min(A.Z, B.Z)),
    MAX = Vector3.new(math.max(A.X, B.X), math.max(A.Y, B.Y), math.max(A.Z, B.Z))
}

local active = false
local isMining = false
local floor = nil

-- События
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack
local InputRem = Events.Tools.ToolInputChanged

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0.05, 0)
bt.Text, bt.BackgroundColor3 = "DEBUG MODE: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 300, 0, 120), UDim2.new(0.5, -150, 0.05, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextXAlignment = Enum.TextXAlignment.Left
log.Text = "Initializing..."

-- ПРОВЕРКИ ДЛЯ ДЕБАГА
local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

local function getDebugStats()
    -- 1. Считаем руду в шахте
    local oresOnMap = 0
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == targetOre then oresOnMap = oresOnMap + 1 end
    end

    -- 2. Считаем свои блоки в Grab (в зоне)
    local myDropsInZone = 0
    for _, item in pairs(workspace.Grab:GetChildren()) do
        if item.Name == "MaterialPart" then
            local p = item:FindFirstChild("Part")
            local o = item:FindFirstChild("Owner")
            local config = item:FindFirstChild("Configuration")
            local mat = config and config.Data:FindFirstChild("MaterialString")
            
            if p and o and o.Value == plr and mat and mat.Value == targetOre and isInZone(p.Position) then
                myDropsInZone = myDropsInZone + 1
            end
        end
    end

    -- 3. Считаем сумку
    local bagCount = 0
    local bag = plr.Character:FindFirstChild("Item Bag") or plr.Backpack:FindFirstChild("Item Bag")
    if bag then
        local stored = bag.Configuration.Data.Stored.Value
        if stored ~= "[]" then
            local _, count = string.gsub(stored, "Key", "")
            bagCount = count
        end
    end

    return oresOnMap, myDropsInZone, bagCount
end

local function toggleFloor(on, pos)
    if not on and floor then floor:Destroy() floor = nil
    elseif on then
        if not floor then
            floor = Instance.new("Part", workspace)
            floor.Size, floor.Transparency, floor.Anchored = Vector3.new(10, 1, 10), 0.8, true
            floor.CanCollide, floor.CanQuery = true, false
            floor.Color = Color3.new(0, 1, 1)
        end
        floor.CFrame = pos * CFrame.new(0, -3.2, 0)
    end
end

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "DEBUG MODE: ON" or "DEBUG MODE: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
end)

local function autoGetTool()
    local char = plr.Character
    if not char then return nil end
    local t = char:FindFirstChild(targetTool) or plr.Backpack:FindFirstChild(targetTool)
    if t then
        local d = t:FindFirstChild("Configuration") and t.Configuration:FindFirstChild("Data")
        local ct = d and d:FindFirstChild("ChargeTime") and d.ChargeTime.Value or 0.4
        local cd = t.Configuration:FindFirstChild("Cooldown") and t.Configuration.Cooldown.Value or 0.5
        return t, ct, cd
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.2)
        
        -- Обновляем GUI всегда, даже если выключен фарм
        local ores, drops, bag = getDebugStats()
        log.Text = string.format(
            " STATUS: %s\n BAG: %d/5\n ORES ON MAP: %d\n MY DROPS IN ZONE: %d",
            active and (isMining and "MINING" or "SEARCHING") or "OFF",
            bag, ores, drops
        )

        if active then
            pcall(function()
                local root = plr.Character.HumanoidRootPart
                local tool, cTime, cd = autoGetTool()
                
                if not tool then return end
                if tool.Parent ~= plr.Character then tool.Parent = plr.Character end 

                local target = nil
                for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
                    if v.Name == targetOre and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
                        target = v; break
                    end
                end

                if target and not isMining then
                    isMining = true
                    local realPart = target.Hittable.Part
                    local targetPos = realPart.Position
                    
                    root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    InputRem:FireServer(tool, true)
                    ChargeRem:FireServer({["Target"] = realPart, ["HitPosition"] = targetPos})
                    task.wait(0.05)
                    
                    AttackRem:FireServer({["Alpha"] = 1, ["ResponseTime"] = cTime})
                    InputRem:FireServer(tool, false)
                    
                    task.wait(cd)
                    isMining = false
                elseif not target then
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)